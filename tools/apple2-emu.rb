# ---------------------------------------------------------------------------
# Apple II emulator plumbing, shared by the spikes in tools/
#
# Three emulators, each good at something different, and this is the one place
# that knows how to drive them:
#
#   sa2     - AppleWin's SDL front end, the interactive one, with AppleWin's
#             debugger.  It needs a real display: under Xvfb it initialises SDL
#             and then exits without mapping a window.  It is the only thing
#             that can see the glyphs the video hardware actually fetched.
#   applen  - AppleWin's ncurses front end, driven inside a pty.  Headless, but
#             it can only be looked at through a save state (the terminal it
#             paints is a stream of cursor moves, not a screen).
#   mame    - the apple2p driver, the analogue of the xemu/VICE workflows: a
#             Lua script peeks memory while the machine runs, so it can time
#             what the program is doing and read variables out by name.  This
#             is the one to reach for.
#
# The MAME gotcha worth knowing: /etc/mame/mame.ini has `autosave 1`, so a run
# that ends by itself writes ~/.local/state/mame/sta/apple2p/auto.sta, and the
# NEXT run restores it - at which point a -seconds_to_run limit is already
# spent and the emulator exits at frame 0, silently, with no "Average speed"
# line and no output from the Lua script.  It looks exactly like a broken
# script.  Always pass -noautosave, which mame_run does.
# ---------------------------------------------------------------------------

require 'pty'
require 'io/console'
require 'fileutils'

module Apple2Emu
  ROOT     = File.expand_path('..', __dir__)
  TEMP     = File.join(ROOT, 'temp')
  APPLEWIN = ENV['APPLEWIN_DIR'] || File.join(ROOT, 'AppleWin', 'build')
  MAME     = ENV['MAME'] || 'mame'

  SCREEN_BASE = 0x0400
  ROWS        = 24
  COLS        = 40

  module_function

  # $400 + (row & 7) * $80 + (row >> 3) * $28 - the interleave a row table
  # exists for.
  def row_base(row)
    SCREEN_BASE + (row & 7) * 0x80 + (row >> 3) * 0x28
  end

  # One screen cell -> [character, video mode].  Bits 7-6 pick the mode:
  # $00-$3F inverse, $40-$7F flashing, $80-$FF normal, and inverse covers only
  # $20-$5F, which is why the II+ cannot show lower case.
  def decode_cell(byte)
    case byte
    when 0x80..0xff then [byte & 0x7f, :normal]
    when 0x40..0x7f then [(byte & 0x3f) | 0x40, :flash]
    else
      code = byte & 0x3f
      [code < 0x20 ? code + 0x40 : code, :inverse]
    end
  end

  # The screen as 24 strings.  An inverse cell is printed as its lower case
  # letter: the II+ has no lower case glyphs, so lower case in a dump can only
  # ever mean inverse video.
  def screen_text(memory)
    (0...ROWS).map do |row|
      (0...COLS).map do |col|
        char, mode = decode_cell(memory[row_base(row) + col].ord)
        c = char.chr
        case mode
        when :inverse then c.downcase
        when :flash   then c == ' ' ? '~' : c.downcase
        else c
        end
      end.join
    end
  end

  # An ACME --symbollist file: "\tname\t= $addr\t; comment".
  def read_labels(path)
    labels = {}
    File.foreach(path) do |line|
      labels[$1] = $2.to_i(16) if line =~ /^\s*(\S+)\s*=\s*\$([0-9a-fA-F]+)/
    end
    labels
  end

  # --- AppleWin ------------------------------------------------------------

  def applewin(name)
    path = File.join(APPLEWIN, name)
    abort "#{path} not found - build AppleWin, or set APPLEWIN_DIR" unless File.executable?(path)
    path
  end

  # A II+ with 48K and nothing but a Disk II in slot 6.  Written fresh for each
  # run so a spike never depends on, or disturbs, ~/.config/applewin.
  def write_config(path)
    File.write(path, <<~YAML)
      Configuration:
        Apple2 Type: 1
      Configuration\\Slot 0:
        Card type: 0
      Configuration\\Slot 6:
        Card type: 1
    YAML
    path
  end

  # Read "Main Memory:" out of an AppleWin save state.  Its lines are
  # "      AAAA: <64 bytes as hex>", written by YamlSaveHelper::SaveMemory.
  def read_main_memory(path)
    memory = "\x00".b * 0x10000
    inside = false
    File.foreach(path) do |line|
      if line =~ /^\s*Main Memory:/
        inside = true
        next
      end
      next unless inside
      if line =~ /^\s*([0-9A-F]{4}):\s*([0-9A-F]+)\s*$/
        addr = $1.to_i(16)
        bytes = [$2].pack('H*')
        memory[addr, bytes.bytesize] = bytes
      else
        break
      end
    end
    memory
  end

  # Boot `image` in applen inside a pty: let it run, type any keys, F11 to save
  # a state, F4 to quit, and hand back the 64K it was holding.  The save state
  # filename has to come from --state-filename; putting it in the config file
  # the way AppleWin writes it does not take, and F11 then writes nothing.
  def applen_run(image, keys: '', seconds: 4, config: nil, state: nil)
    config ||= write_config(File.join(TEMP, 'apple2_run.yaml'))
    state  ||= File.join(TEMP, 'apple2_run_state.yaml')
    File.delete(state) if File.exist?(state)
    cmd = [applewin('applen'), '--conf', config, '--state-filename', state,
           '--no-audio', '--d1', image]
    PTY.spawn({ 'TERM' => 'xterm' }, *cmd) do |reader, writer, pid|
      begin
        reader.winsize = [40, 100]              # applen wants room for 24 rows
      rescue StandardError
        nil
      end
      drain = Thread.new { loop { reader.readpartial(4096) } rescue nil }
      sleep seconds
      unless keys.empty?
        writer.write(keys)
        sleep 1
      end
      writer.write("\e[23~")                    # F11: save state
      sleep 2
      writer.write("\eOS")                      # F4: quit
      sleep 2
      begin
        Process.kill('TERM', pid)
      rescue StandardError
        nil
      end
      drain.kill
    end
    abort "no save state at #{state}: applen did not get F11" unless File.exist?(state)
    read_main_memory(state)
  end

  # --- MAME ----------------------------------------------------------------

  # Boot `image` in the apple2p driver with a Lua script watching it.
  #
  #   watch:   a symbol name whose byte is polled every frame; each new value
  #            is timestamped, which is how a program times its own phases.
  #   until:   the watch value that means "finished" (the run then ends).
  #   symbols: name -> [address, byte length], read once at the end.
  #   labels:  an ACME symbol table, so watch/symbols can be given by name.
  #
  # Returns { phases: [[value, seconds], ...], symbols: {name => value},
  #           screen: [24 strings], seconds: <emulated seconds run> }.
  def mame_run(image, labels: {}, watch: nil, until_value: nil, symbols: {},
               seconds: 120, lua_path: nil, result_path: nil)
    lua_path    ||= File.join(TEMP, 'apple2_mame.lua')
    result_path ||= File.join(TEMP, 'apple2_mame.txt')
    File.delete(result_path) if File.exist?(result_path)

    watch_addr = watch ? (labels[watch] or abort("no label #{watch}")) : nil
    reads = symbols.map do |name, width|
      addr = labels[name] or abort("no label #{name}")
      "  {\"#{name}\", 0x#{addr.to_s(16)}, #{width}},"
    end.join("\n")

    File.write(lua_path, <<~LUA)
      -- Generated by tools/apple2-emu.rb.  The locals of an autoboot script die
      -- with the chunk, and a notifier whose subscription is collected stops
      -- firing, so everything here is a global on purpose.
      mach = manager.machine
      mem = mach.devices[":maincpu"].spaces["program"]
      out = io.open("#{result_path}", "w")
      watch_addr = #{watch_addr ? "0x#{watch_addr.to_s(16)}" : 'nil'}
      until_value = #{until_value.nil? ? 'nil' : until_value}
      reads = {
      #{reads}
      }
      last = -1
      armed = false
      finished = false

      function report()
        for _, r in ipairs(reads) do
          local v = 0
          for i = r[3] - 1, 0, -1 do v = v * 256 + mem:read_u8(r[2] + i) end
          out:write(string.format("sym %s %d\\n", r[1], v))
        end
        for row = 0, 23 do
          local base = 0x400 + (row % 8) * 0x80 + math.floor(row / 8) * 0x28
          local bytes = {}
          for col = 0, 39 do bytes[#bytes + 1] = string.format("%02X", mem:read_u8(base + col)) end
          out:write(string.format("screen %d %s\\n", row, table.concat(bytes)))
        end
        out:write(string.format("ran %.6f\\n", mach.time:as_double()))
        out:close()
      end

      sub = emu.add_machine_frame_notifier(function()
        if finished then return end
        if watch_addr then
          local v = mem:read_u8(watch_addr)
          if v ~= last then
            out:write(string.format("phase %d %.6f\\n", v, mach.time:as_double()))
            last = v
            -- The byte is only ours once the program has been loaded over it,
            -- and it is a zero in the disk image, so nothing before the first
            -- zero counts: uninitialised RAM could otherwise read as "done"
            -- and end the run at frame one.
            if v == 0 then armed = true end
            if armed and until_value and v == until_value then
              finished = true
              report()
              mach:exit()
            end
          end
        end
      end)

      stop = emu.add_machine_stop_notifier(function()
        if not finished then finished = true; report() end
      end)
    LUA

    cmd = [MAME, 'apple2p', '-sl6', 'diskiing', '-flop1', image,
           '-video', 'none', '-sound', 'none', '-nothrottle', '-noautosave',
           '-seconds_to_run', seconds.to_s, '-autoboot_script', lua_path]
    log = File.join(TEMP, 'apple2_mame.log')
    system(*cmd, out: log, err: log)
    abort "mame wrote no result file; see #{log}" unless File.exist?(result_path)
    parse_mame_result(result_path)
  end

  def parse_mame_result(path)
    result = { phases: [], symbols: {}, screen: Array.new(ROWS, ' ' * COLS), seconds: nil }
    File.foreach(path) do |line|
      case line
      when /^phase (\d+) ([\d.]+)/  then result[:phases] << [$1.to_i, $2.to_f]
      when /^sym (\S+) (\d+)/       then result[:symbols][$1] = $2.to_i
      when /^ran ([\d.]+)/          then result[:seconds] = $1.to_f
      when /^screen (\d+) ([0-9A-F]+)/
        row = $1.to_i
        bytes = [$2].pack('H*')
        result[:screen][row] = (0...COLS).map do |col|
          char, mode = decode_cell(bytes[col].ord)
          c = char.chr
          mode == :normal ? c : c.downcase
        end.join
      end
    end
    result
  end

  # How long the program spent between two of its own phase markers.
  def phase_duration(result, from, to)
    a = result[:phases].find { |v, _| v == from }
    b = result[:phases].find { |v, _| v == to }
    return nil unless a && b
    b[1] - a[1]
  end
end
