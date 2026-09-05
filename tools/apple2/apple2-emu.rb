# ---------------------------------------------------------------------------
# Apple II emulator plumbing, shared by everything in tools/apple2/
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
#   mame    - the apple2p driver (or apple2e / apple2ee for a -t:apple2e
#             build), the analogue of the xemu/VICE workflows: a Lua script
#             peeks memory while the machine runs, so it can time what the
#             program is doing and read variables out by name.  This is the one
#             to reach for.
#
# The MAME gotcha worth knowing: /etc/mame/mame.ini has `autosave 1`, so a run
# that ends by itself writes ~/.local/state/mame/sta/<driver>/auto.sta, and the
# NEXT run restores it - at which point a -seconds_to_run limit is already
# spent and the emulator exits at frame 0, silently, with no "Average speed"
# line and no output from the Lua script.  It looks exactly like a broken
# script.  Always pass -noautosave, which mame_run does.
# ---------------------------------------------------------------------------

require 'pty'
require 'io/console'
require 'fileutils'

module Apple2Emu
  # This file lives in tools/apple2/, so the repository root is two up.
  ROOT     = File.expand_path('../..', __dir__)
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

  # The same, for a IIe with ALTCHARSET on (-t:apple2e).  There the cell is the
  # character's own ASCII with bit 7 set for normal video and clear for
  # inverse, over the whole of $20-$7f - so seven bits pick the glyph, not six,
  # and the only fold left is inverse upper case, which is written at $00-$1f
  # because $40-$5f is MouseText.  There is no flashing range to confuse it
  # with, and lower case is a real glyph rather than a sign of inverse video.
  def decode_cell_alt(byte)
    code = byte & 0x7f
    char = code < 0x20 ? code + 0x40 : code
    [char, byte >= 0x80 ? :normal : :inverse]
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

  # A Lua string literal. Ruby's own inspect is not one: it writes a byte like
  # DEL as \u007F, which Lua cannot parse, and the whole generated script then
  # fails to load - silently, as far as the caller can see, because MAME simply
  # writes no result file. Lua's \ddd decimal escape covers every byte.
  def lua_string(text)
    '"' + text.to_s.each_byte.map do |b|
      if b == 0x22 || b == 0x5c || b < 0x20 || b >= 0x7f
        format('\\%03d', b)
      else
        b.chr
      end
    end.join + '"'
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

  # AppleWin's own eApple2Type (source/Common.h): 1 is a II+, 16 an unenhanced
  # //e, 17 an enhanced one.
  APPLEWIN_MACHINE = { ii_plus: 1, iie: 16, iie_enhanced: 17 }.freeze

  # Make a configuration file for AppleWin, assuming an Apple 2+ with 48K and nothing but a Disk II
  # in slot 6, or for -t:apple2e an enhanced 2e. Slot 0 empty is "no language
  # card", which is what makes the II+ 48K; a //e has its own.
  def write_config(path, machine: :ii_plus)
    type = APPLEWIN_MACHINE[machine] or raise "unknown machine #{machine}"
    slot0 = machine == :ii_plus ? "Configuration\\Slot 0:\n  Card type: 0\n" : ''
    File.write(path, "Configuration:\n  Apple2 Type: #{type}\n" + slot0 +
                     "Configuration\\Slot 6:\n  Card type: 1\n")
    path
  end

  # Read a 64K memory bank out of an AppleWin save state.  Its lines are
  # "      AAAA: <64 bytes as hex>", written by YamlSaveHelper::SaveMemory.
  # "Main Memory" is the one every machine has; a //e also writes "Auxiliary
  # Memory Bank00", which is where the 80 column screen's even columns live.
  def read_memory_bank(path, section = 'Main Memory')
    memory = "\x00".b * 0x10000
    inside = false
    File.foreach(path) do |line|
      if line =~ /^\s*#{Regexp.escape(section)}:/
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

  def read_main_memory(path)
    read_memory_bank(path)
  end

  # The IIe's 80 column screen as 24 strings, out of the two banks an AppleWin
  # save state holds: a cell is at row_base + column / 2, aux for an even
  # column and main for an odd one.  Lower case is a real glyph under
  # ALTCHARSET, so unlike the II+ dump above it cannot also stand for inverse
  # video - what a cell shows is what is printed.
  def screen_text_80(main, aux)
    (0...ROWS).map do |row|
      (0...80).map do |col|
        bank = col.even? ? aux : main
        decode_cell_alt(bank.getbyte(row_base(row) + (col >> 1)))[0].chr
      end.join
    end
  end

  # Boot `image` in applen inside a pty: let it run, type any keys, F11 to save
  # a state, F4 to quit, and hand back the 64K it was holding.  The save state
  # filename has to come from --state-filename; putting it in the config file
  # the way AppleWin writes it does not take, and F11 then writes nothing.
  # aux: also hand back the auxiliary bank, which is where the IIe's 80 column
  # screen keeps its even columns (the return is then [main, aux]).
  def applen_run(image, keys: '', seconds: 4, config: nil, state: nil, machine: :ii_plus, aux: false)
    config ||= write_config(File.join(TEMP, "apple2_run_#{machine}.yaml"), machine: machine)
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
    return read_memory_bank(state) unless aux
    [read_memory_bank(state), read_memory_bank(state, 'Auxiliary Memory Bank00')]
  end

  # --- MAME ----------------------------------------------------------------

  # Boot `image` in a MAME Apple II driver with a Lua script watching it.
  #
  #   disk_swaps: {disk number => image} for a multi-disk game played on ONE
  #            drive.  When the interpreter asks for a disk ("Please insert
  #            Story disk 2 in drive 1"), the number is read off the screen and
  #            that image is loaded into drive 1, which is the player putting it
  #            in.  Use it with no flop2 to test the single-drive path; with
  #            flop2 the game never asks at all.
  #   swap_drive: which drive disk_swaps puts a disk into.  The default is the
  #            one the prompt names, which is a machine with two drives; pass 1
  #            for a machine with one, where the player has nowhere else to put
  #            it and the interpreter has to notice.
  #   flop2:   a second disk, in the controller's drive 2 - which is where a
  #            multi-disk build wants its story disk.  Leave it out and the
  #            machine has one drive's worth of disk, which is the other case
  #            such a build has to work in.
  #   driver:  the MAME machine.  apple2p is the 48K II+ a -t:apple2 build
  #            wants; a -t:apple2e build wants apple2e (unenhanced) or
  #            apple2ee (enhanced), and is worth running on both, since that
  #            is the split that decides the charset and the font 3 path.
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
  #   cols:    40 for a -t:apple2 build, 80 for a -t:apple2e one.  At 80 a cell
  #            is at row_base + column / 2, in AUX RAM for an even column and
  #            main for an odd one, so the Lua below has to read both banks -
  #            which it does by flipping PAGE2 itself and putting it back the
  #            way it found it (\$C01C says which half is selected).  That is
  #            safe because the notifier runs between instructions and the
  #            interpreter's own screen writes leave main selected.
  #   altchar: the IIe's alternate character set is on, so a cell is plain
  #            ASCII with bit 7 for normal video - see decode_cell_alt.
  #   snapshot: a path to write a PNG of the screen to when the run ends.  This
  #            is the one thing a memory dump cannot do: it is the glyphs the
  #            video hardware actually fetched, so it is the only way to see a
  #            wrong character set or a wrong video mode.  MAME renders it even
  #            under -video none.
  def mame_run(image, driver: 'apple2p', flop2: nil, disk_swaps: {}, swap_drive: nil, labels: {}, watch: nil, until_value: nil, symbols: {},
               samples: {}, tap: nil, auto_more: false, idle_exit: nil,
               idle_after: 25, commands: [], command_idle: 1.5, ready_flag: nil,
               echo_flag: nil, dump_range: nil, cols: COLS, altchar: false,
               force_latch: false, snapshot: nil,
               seconds: 120, keys: [], lua_path: nil, result_path: nil)
    lua_path    ||= File.join(TEMP, 'apple2_mame.lua')
    result_path ||= File.join(TEMP, 'apple2_mame.txt')
    File.delete(result_path) if File.exist?(result_path)

    # A character no keypost can send has to go in at the keyboard latch; the
    # Lua below only installs that tap when there is one.
    # force_latch presents every typed character at the keyboard latch instead
    # of through MAME's natural keyboard.  That is what a real keyboard does,
    # and it is the only way to send a byte MAME will not send by itself - a
    # lower case letter on a IIe, say, where the natural keyboard's CAPS LOCK
    # is a toggle input that Lua cannot set.
    needs_latch = force_latch ||
                  (commands + keys.map { |_, text| text }).any? { |c| c.to_s.each_byte.any? { |b| b >= 0x7f } }

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
      -- Generated by tools/apple2/apple2-emu.rb.  The locals of an autoboot script die
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
      #{commands.map { |c| "  #{lua_string(c)}," }.join("
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
      -- The player, for a game on more than one disk and a machine with one
      -- drive: the image to put in when the interpreter asks for disk N.
      disk_swaps = {
      #{disk_swaps.map { |n, path| "  [#{n}] = #{lua_string(File.expand_path(path))}," }.join("
")}
      }
      swap_drive = #{swap_drive ? swap_drive : 'nil'}
      force_latch = #{force_latch ? 'true' : 'false'}
      drives = { mach.images[":sl6:diskiing:0:525"],
                 mach.images[":sl6:diskiing:1:525"] }
      tap_last = nil
      tap_bytes = {}
      more_last = -1
      swap_last = -1
      last_prompt = nil
      latch_key = nil
      dump_addr = #{dump_range ? "0x#{dump_addr.to_s(16)}" : 'nil'}
      dump_len = #{dump_range ? dump_len : 'nil'}
      cols = #{cols}
      altchar = #{altchar ? 'true' : 'false'}
      want_snapshot = #{snapshot ? 'true' : 'false'}
      keys = {
      #{keys.map { |at, text| "  {#{'%.3f' % at}, #{lua_string(text)}}," }.join("
")}
      }
      next_key = 1

      function read_var(r)
        local v = 0
        for i = r[3] - 1, 0, -1 do v = v * 256 + mem:read_u8(r[2] + i) end
        return v
      end

      -- A key the natural keyboard cannot post, handed to the program through
      -- the keyboard latch itself. Only installed when a command actually
      -- carries one: the tap fires on every read of $C000, which the input
      -- loop does thousands of times a second.
      if #{needs_latch ? 'true' : 'false'} then
        latch_tap = mem:install_read_tap(0xC000, 0xC000, "ozmoo_latch", function(offset, data, mask)
          if latch_key then
            local v = latch_key
            latch_key = nil
            return v | 0x80
          end
          return data
        end)
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

      -- One row of the text page, as the bytes of its cells in column order.
      -- At 80 columns a row is 40 bytes in each of two banks - aux for the even
      -- columns, main for the odd - so both halves are read and interleaved
      -- here.  PAGE2 is put back the way it was found: this runs between
      -- instructions, and the interpreter switches to aux for a single store.
      function screen_row_bytes(row)
        local base = 0x400 + (row % 8) * 0x80 + math.floor(row / 8) * 0x28
        local out = {}
        if cols == 80 then
          local was = mem:read_u8(0xC01C) & 0x80
          mem:write_u8(0xC055, 0)
          local aux = {}
          for i = 0, 39 do aux[i] = mem:read_u8(base + i) end
          mem:write_u8(0xC054, 0)
          for i = 0, 39 do
            out[#out + 1] = aux[i]
            out[#out + 1] = mem:read_u8(base + i)
          end
          if was ~= 0 then mem:write_u8(0xC055, 0) end
        else
          for i = 0, cols - 1 do out[#out + 1] = mem:read_u8(base + i) end
        end
        return out
      end

      -- The glyph a cell shows.  Without ALTCHARSET six bits pick it out of a
      -- 64 glyph set and bit 6 is part of the video mode; with it, seven do,
      -- and only inverse upper case is folded (it lives at $00-$1f, because
      -- $40-$5f is MouseText).
      function glyph(code)
        local a = code & (altchar and 0x7f or 0x3f)
        if a < 0x20 then a = a + 0x40 end
        return a
      end

      -- One row as an upper case string, for the prompts this script looks for.
      function screen_row(row)
        local out = {}
        for _, code in ipairs(screen_row_bytes(row)) do
          out[#out + 1] = string.char(glyph(code))
        end
        return string.upper(table.concat(out))
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
          local bytes = {}
          for _, code in ipairs(screen_row_bytes(row)) do
            bytes[#bytes + 1] = string.format("%02X", code)
          end
          out:write(string.format("screen %d %s\\n", row, table.concat(bytes)))
        end
        out:write(string.format("ran %.6f\\n", mach.time:as_double()))
        out:close()
        -- The glyphs the video hardware fetched, which no memory dump can show.
        if want_snapshot then mach.video:snapshot() end
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
        -- The [More] prompt is the last cell of row 23, $7f7 - and at 80
        -- columns that is column 79, an odd one, so it is still that byte in
        -- main RAM.
        if auto_more and mem:read_u8(0x7f7) == 0xaa and now - more_last > 0.25 then
          emu.keypost("\\r")
          more_last = now
        end
        -- "Please insert Story disk 2 in drive 1": put it in, and press a key.
        -- The prompt is not erased when it is answered, so what decides whether
        -- to act is the disk it names against the one already in the drive.
        if next(disk_swaps) ~= nil and now - swap_last > 0.25 then
          swap_last = now
          -- Bottom upwards: the prompt is not erased when it is answered, so
          -- the screen can hold several and only the last one is live. (One of
          -- them may be sitting in a game's status window, where it will stay
          -- for the rest of the session.)
          local seen = nil
          for row = 23, 1, -1 do
            local line = screen_row(row - 1) .. screen_row(row)
            if line:find("PLEASE INSERT") and line:find("ENTER") then
              seen = line
              break
            end
          end
          -- Answer a prompt ONCE. The text stays on the screen after the game
          -- has moved on, so answering whenever it is visible would post
          -- Returns into whatever the game asks next - which is how a save
          -- came to be cancelled and read as a failure. It is forgotten again
          -- when it scrolls away, so a later prompt for the same disk is
          -- answered afresh.
          if seen == nil then
            last_prompt = nil
          elseif seen ~= last_prompt then
            last_prompt = seen
            local n = tonumber(seen:match("DISK (%d)")) or 1
            local d = swap_drive or tonumber(seen:match("IN DRIVE (%d)")) or 1
            local want = disk_swaps[n]
            if want and drives[d] and drives[d].filename ~= want then
              drives[d]:unload()
              drives[d]:load(want)
              out:write(string.format("swapped %.3f %d %d %s\\n", now, n, d, want))
            end
            emu.keypost("\\r")
          end
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
            local ch = pending:byte(pending_i)
            if ch >= 0x7f or force_latch then
              -- MAME's natural keyboard has no mapping for $7F, so keypost
              -- sends nothing at all and the run looks as though the key did
              -- not work. Present it at the keyboard latch instead, which is
              -- exactly what the hardware does: the read tap below hands it
              -- over once, with bit 7 set to say a key is waiting.
              -- keypost presses Return for a newline; the latch is the raw
              -- key code, and the Return key sends $0D, so say so.
              if ch == 10 then ch = 13 end
              latch_key = ch
            else
              emu.keypost(string.char(ch))
            end
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

    # A II+ or a IIe needs a Disk II card put in slot 6; a IIc has its drive
    # built in and rejects the option outright.
    slot = driver.start_with?('apple2c') ? [] : ['-sl6', 'diskiing']
    cmd = [MAME, driver, *slot, '-flop1', image]
    cmd += ['-flop2', flop2] if flop2
    snap_dir = File.join(TEMP, 'apple2_snap')
    if snapshot
      FileUtils.rm_rf(snap_dir)
      cmd += ['-snapshot_directory', snap_dir]
    end
    cmd += [
           '-video', 'none', '-sound', 'none', '-nothrottle', '-noautosave',
           '-seconds_to_run', seconds.to_s, '-autoboot_script', lua_path]
    log = File.join(TEMP, 'apple2_mame.log')
    system(*cmd, out: log, err: log)
    abort "mame wrote no result file; see #{log}" unless File.exist?(result_path)
    if snapshot
      # MAME names it <snapshot_directory>/<driver>/0000.png.
      png = Dir[File.join(snap_dir, '**', '*.png')].max_by { |f| File.mtime(f) }
      abort "mame wrote no snapshot; see #{log}" unless png
      FileUtils.mkdir_p(File.dirname(snapshot))
      FileUtils.cp(png, snapshot)
    end
    parse_mame_result(result_path, cols: cols, altchar: altchar)
  end

  def parse_mame_result(path, cols: COLS, altchar: false)
    result = { phases: [], symbols: {}, samples: [], tap: +''.b, dump: +''.b, typed: [], swapped: [],
               screen: Array.new(ROWS, ' ' * cols),
               # The cells as the machine holds them, video mode and all: the
               # decoded screen above cannot show a wrong mode, which is the
               # one class of screen bug a dump is blind to.
               raw_screen: Array.new(ROWS, "\xa0".b * cols), seconds: nil }
    File.foreach(path) do |line|
      case line
      when /^phase (\d+) ([\d.]+)/  then result[:phases] << [$1.to_i, $2.to_f]
      when /^sym (\S+) (\d+)/       then result[:symbols][$1] = $2.to_i
      when /^typed ([\d.]+) (.*)/ then result[:typed] << [$1.to_f, $2]
      when /^swapped ([\d.]+) (\d+) (\d+) (.*)/
        result[:swapped] << [$1.to_f, $2.to_i, $3.to_i, $4]
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
        result[:raw_screen][row] = bytes
        result[:screen][row] = (0...cols).map do |col|
          if altchar
            # Lower case is a real glyph here, so it cannot double as the sign
            # of an inverse cell the way it does on a II+: what a cell shows is
            # what is printed, and reverse video does not survive into the dump.
            decode_cell_alt(bytes[col].ord)[0].chr
          else
            char, mode = decode_cell(bytes[col].ord)
            c = char.chr
            mode == :normal ? c : c.downcase
          end
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
