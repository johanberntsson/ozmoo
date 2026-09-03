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
  #
  # The character generator holds 64 glyphs, in ASCII order from $40, and
  # the low SIX bits of the cell choose one: codes $00-$1F are @ A-Z [ \ ] ^ _
  # and codes $20-$3F are space ! " ... ?. Bit 6 is part of the mode, not part
  # of the glyph, so $EF and $AF draw the same '/' - which is why this masks to
  # six bits rather than seven A letter can therefore reach a cell two ways round
  # $C1 is 'A' as ASCII|$80, and so is $81, the same letter as a six bit code with
  # bit 7 on.
  def decode_cell(byte)
    code = byte & 0x3f
    char = code < 0x20 ? code + 0x40 : code
    case byte
    when 0x80..0xff then [char, :normal]
    when 0x40..0x7f then [char, :flash]
    else                 [char, :inverse]
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
  #   symbols: name -> byte length, read once at the end.
  #   samples: name -> byte length, read every frame and timestamped, which is
  #            how a variable's *rate* is measured (the software clock's, say)
  #            rather than just its final value.
  #   tap:     a symbol to watch the machine *call*: MAME's read tap fires on
  #            the opcode fetch at that address, so the accumulator is the
  #            argument the routine was called with.  A tap on
  #            streams_print_output is the whole transcript of what a game
  #            printed, which is what the conformance games are read with.
  #   auto_more: answer [More] prompts by posting Return whenever the bottom
  #            right cell holds the prompt's '*'.  A headless run stops at the
  #            first one otherwise, exactly as it does under xemu and VICE.
  #   ready_flag: a symbol whose byte must be non-zero before a character is
  #            typed - s_cursorswitch, which Ozmoo sets while it is waiting for
  #            input. Without it, a line typed while the game is saving or
  #            paging is simply lost (this machine latches one key).
  #   echo_flag: a symbol that changes when the game has taken a character -
  #            zp_screencolumn, which moves as the input is echoed. The next
  #            character waits for it rather than for a fixed delay, which is
  #            what makes typing reliable: without it a character posted while
  #            the game happened not to be looking is simply gone, and the line
  #            arrives with a hole in it.
  #   commands: lines to type at the game's prompts.  Each is posted when the
  #            tap has been quiet for command_idle seconds - i.e. when the game
  #            has stopped printing and is waiting for something - which is far
  #            more robust than guessing when a prompt will appear.  A [More]
  #            prompt is answered inside a quarter of a second by auto_more, so
  #            it never looks like a prompt to this.  Not before idle_after
  #            either: the splash screen prints a few characters of its own and
  #            then the disk loads in silence, which otherwise looks exactly
  #            like a game waiting at a prompt - and a line typed then is
  #            simply lost, since this machine latches one key and no more.
  #   dump_range: [address, length] of memory to write out when the run ends,
  #            returned as a binary string in result[:dump] - the analogue of
  #            xemu's -dumpmem, for the times a few named bytes are not enough
  #            (a track's worth of raw nibbles, say).
  #   idle_exit: end the run when the tap has been quiet this many emulated
  #            seconds - i.e. when the game has stopped printing, which is
  #            where a transcript ends.  Not considered before idle_after,
  #            because the splash screen prints a little of its own and the
  #            silence behind it is only the disk loading.
  #   labels:  an ACME symbol table, so watch/symbols can be given by name.
  #
  # Returns { phases: [[value, seconds], ...], symbols: {name => value},
  #           samples: [[seconds, {name => value}], ...],
  #           screen: [24 strings], seconds: <emulated seconds run> }.
  # keys: a list of [seconds, "text"] pairs typed into the machine as it runs.
  # MAME's emu.keypost() puts the text through the emulated keyboard, so the
  # program sees it exactly as a player's typing; "\n" is Return.
  def mame_run(image, labels: {}, watch: nil, until_value: nil, symbols: {},
               samples: {}, tap: nil, auto_more: false, idle_exit: nil,
               idle_after: 25, commands: [], command_idle: 1.5, ready_flag: nil,
               echo_flag: nil, dump_range: nil,
               seconds: 120, keys: [], lua_path: nil, result_path: nil)
    lua_path    ||= File.join(TEMP, 'apple2_mame.lua')
    result_path ||= File.join(TEMP, 'apple2_mame.txt')
    File.delete(result_path) if File.exist?(result_path)

    watch_addr = watch ? (labels[watch] or abort("no label #{watch}")) : nil
    tap_addr = tap ? (labels[tap] or abort("no label #{tap}")) : nil
    ready_addr = ready_flag ? (labels[ready_flag] or abort("no label #{ready_flag}")) : nil
    echo_addr = echo_flag ? (labels[echo_flag] or abort("no label #{echo_flag}")) : nil
    if dump_range
      dump_addr = dump_range[0].is_a?(String) ? (labels[dump_range[0]] or abort("no label #{dump_range[0]}")) : dump_range[0]
      dump_len = dump_range[1]
    end
    reads = symbols.map do |name, width|
      addr = labels[name] or abort("no label #{name}")
      "  {\"#{name}\", 0x#{addr.to_s(16)}, #{width}},"
    end.join("\n")
    sampled = samples.map do |name, width|
      addr = labels[name] or abort("no label #{name}")
      "  {\"#{name}\", 0x#{addr.to_s(16)}, #{width}},"
    end.join("\n")

    File.write(lua_path, <<~LUA)
      -- Generated by tools/apple2-emu.rb.  The locals of an autoboot script die
      -- with the chunk, and a notifier whose subscription is collected stops
      -- firing, so everything here is a global on purpose.
      mach = manager.machine
      cpu = mach.devices[":maincpu"]
      mem = cpu.spaces["program"]
      out = io.open("#{result_path}", "w")
      watch_addr = #{watch_addr ? "0x#{watch_addr.to_s(16)}" : 'nil'}
      until_value = #{until_value.nil? ? 'nil' : until_value}
      reads = {
      #{reads}
      }
      sampled = {
      #{sampled}
      }
      last = -1
      armed = false
      finished = false
      tap_addr = #{tap_addr ? "0x#{tap_addr.to_s(16)}" : 'nil'}
      idle_exit = #{idle_exit.nil? ? 'nil' : idle_exit}
      idle_after = #{idle_after}
      command_idle = #{command_idle}
      commands = {
      #{commands.map { |c| "  #{c.inspect}," }.join("
")}
      }
      next_command = 1
      pending = nil
      pending_i = 1
      last_char = -1
      ready_addr = #{ready_addr ? "0x#{ready_addr.to_s(16)}" : 'nil'}
      echo_addr = #{echo_addr ? "0x#{echo_addr.to_s(16)}" : 'nil'}
      echo_was = nil
      auto_more = #{auto_more ? 'true' : 'false'}
      tap_last = nil
      tap_bytes = {}
      more_last = -1
      dump_addr = #{dump_range ? "0x#{dump_addr.to_s(16)}" : 'nil'}
      dump_len = #{dump_range ? dump_len : 'nil'}
      keys = {
      #{keys.map { |at, text| "  {#{'%.3f' % at}, #{text.inspect}}," }.join("
")}
      }
      next_key = 1

      function read_var(r)
        local v = 0
        for i = r[3] - 1, 0, -1 do v = v * 256 + mem:read_u8(r[2] + i) end
        return v
      end

      -- The read tap fires on the opcode fetch at the routine's first byte, so
      -- the accumulator still holds the argument it was called with.  It also
      -- fires on any *data* read of that byte, though - the RWTS reads back the
      -- memory it loaded, for one - so the program counter has to agree that
      -- this is an instruction being executed and not a byte being looked at.
      if tap_addr then
        tapper = mem:install_read_tap(tap_addr, tap_addr, "ozmoo_tap", function(offset, data, mask)
          if cpu.state["PC"].value == tap_addr then
            tap_bytes[#tap_bytes + 1] = string.format("%02X", cpu.state["A"].value)
            tap_last = mach.time:as_double()
          end
          return data
        end)
      end

      function report()
        if #tap_bytes > 0 then
          -- in chunks: one enormous line is slower to write and to read back
          for i = 1, #tap_bytes, 512 do
            out:write("tap ", table.concat(tap_bytes, "", i, math.min(i + 511, #tap_bytes)), "\\n")
          end
        end
        for _, r in ipairs(reads) do
          out:write(string.format("sym %s %d\\n", r[1], read_var(r)))
        end
        if dump_addr then
          local chunk = {}
          for i = 0, dump_len - 1 do
            chunk[#chunk + 1] = string.format("%02X", mem:read_u8(dump_addr + i))
            if #chunk == 512 then
              out:write("dump ", table.concat(chunk), "\\n")
              chunk = {}
            end
          end
          if #chunk > 0 then out:write("dump ", table.concat(chunk), "\\n") end
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
        local now = mach.time:as_double()
        while next_key <= #keys and keys[next_key][1] <= now do
          emu.keypost(keys[next_key][2])
          next_key = next_key + 1
        end
        -- The [More] prompt is a '*' in the bottom right cell of the screen -
        -- $7f7, the last cell of the interleaved row 23.  It blinks, so this
        -- sees it every other pass; posting a Return once every few frames is
        -- enough and cannot run away.
        if auto_more and mem:read_u8(0x7f7) == 0xaa and now - more_last > 0.25 then
          emu.keypost("\\r")
          more_last = now
        end
        -- The game has stopped printing: it is waiting for us, so type the
        -- next line - one character at a time, a fifth of a second apart.
        -- This machine latches ONE key: anything typed while the game is
        -- printing or paging from disk is lost but for the last of it, so a
        -- line posted in one go arrives with its head bitten off.  tap_last is
        -- pushed forward as we type, so the next command waits for the game to
        -- fall silent again rather than following straight on.
        if not pending and next_command <= #commands and tap_last
           and (not ready_addr or mem:read_u8(ready_addr) ~= 0)
           and now > idle_after and now - tap_last > command_idle then
          pending = commands[next_command]
          pending_i = 1
          next_command = next_command + 1
          out:write(string.format("typed %.3f %s", now, pending))
        end
        -- One character at a time, and the next one only when the game has
        -- taken the last (the echo moves the cursor column) or a second has
        -- gone by without it.
        if pending and (not ready_addr or mem:read_u8(ready_addr) ~= 0) then
          local taken = true
          if echo_addr and echo_was and now - last_char < 1.0 then
            taken = mem:read_u8(echo_addr) ~= echo_was
          end
          if taken and now - last_char > 0.1 then
            emu.keypost(pending:sub(pending_i, pending_i))
            pending_i = pending_i + 1
            last_char = now
            tap_last = now
            if echo_addr then echo_was = mem:read_u8(echo_addr) end
            if pending_i > #pending then pending = nil end
          end
        end
        if idle_exit and tap_last and now > idle_after and next_command > #commands
           and now - tap_last > idle_exit then
          finished = true
          report()
          mach:exit()
          return
        end
        for _, r in ipairs(sampled) do
          out:write(string.format("sample %.6f %s %d\\n", now, r[1], read_var(r)))
        end
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
    result = { phases: [], symbols: {}, samples: [], tap: +''.b, dump: +''.b, typed: [],
               screen: Array.new(ROWS, ' ' * COLS), seconds: nil }
    File.foreach(path) do |line|
      case line
      when /^phase (\d+) ([\d.]+)/  then result[:phases] << [$1.to_i, $2.to_f]
      when /^sym (\S+) (\d+)/       then result[:symbols][$1] = $2.to_i
      when /^typed ([\d.]+) (.*)/ then result[:typed] << [$1.to_f, $2]
      when /^tap ([0-9A-F]+)/     then result[:tap] << [$1].pack('H*')
      when /^dump ([0-9A-F]+)/    then result[:dump] << [$1].pack('H*')
      when /^sample ([\d.]+) (\S+) (\d+)/
        t = $1.to_f
        result[:samples] << [t, {}] if result[:samples].empty? || result[:samples].last[0] != t
        result[:samples].last[1][$2] = $3.to_i
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
