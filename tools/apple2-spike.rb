#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Build and run the Apple II spike (boot sector)
#
#   ruby tools/apple2-spike.rb                 # assemble + build the .dsk
#   ruby tools/apple2-spike.rb --run           # ...and boot it in sa2 (a window)
#   ruby tools/apple2-spike.rb --ncurses       # ...and boot it in applen, here
#   ruby tools/apple2-spike.rb --dump          # ...boot it headlessly and print
#                                              #    the text screen, with a verdict
#   ruby tools/apple2-spike.rb --dump --keys Z # ...typing Z first
#
# The spike is tools/apple2-prototype.asm, a single boot sector; this script is
# the throwaway make.rb around it (the real one grows a -t:apple2 target at
# step 2).  Nothing here is sourced by a normal build.
#
# --dump is the headless check, and it is the Apple analogue of xemu's
# -dumpscreen: it drives AppleWin's ncurses front end (applen) inside a pty,
# presses F11 to write a save state, and decodes the text page out of the
# save state's memory dump.  The save state is used rather than the terminal
# the emulator paints because that terminal is a stream of ncurses cursor
# moves, not a screen - the same reason the MEGA65 work reads $0800 over the
# uartmon instead of trusting a screenshot.  What it cannot see is the glyph
# the video hardware actually fetched (--run is for that, exactly as
# -dumpscreen cannot see a wrong charset on the MEGA65).
# ---------------------------------------------------------------------------

require 'pty'
require 'io/console'
require 'fileutils'
require_relative 'apple2-disk'

ROOT      = File.expand_path('..', __dir__)
SOURCE    = File.join(ROOT, 'tools', 'apple2-prototype.asm')
TEMP      = File.join(ROOT, 'temp')
BINARY    = File.join(TEMP, 'apple2_spike.bin')
LABELS    = File.join(TEMP, 'apple2_spike_labels.txt')  # not acme_labels.txt: that
                                                        # belongs to the last real build
CONFIG    = File.join(TEMP, 'apple2_spike.yaml')
STATE     = File.join(TEMP, 'apple2_spike_state.yaml')
IMAGE     = File.join(ROOT, 'apple2_spike.dsk')
APPLEWIN  = ENV['APPLEWIN_DIR'] || File.join(ROOT, 'AppleWin', 'build')

SCREEN_BASE = 0x0400
ROWS        = 24
COLS        = 40

# --- build ------------------------------------------------------------------

def build
  FileUtils.mkdir_p(TEMP)
  # --format plain: a raw binary, no CBM load address.  --cpu 6502: the NMOS
  # floor, no 65C02 instructions - a II+ has none.
  cmd = ['acme', '--cpu', '6502', '--format', 'plain',
         '--symbollist', LABELS, '-o', BINARY, SOURCE]
  puts cmd.join(' ')
  abort 'acme failed' unless system(*cmd)

  boot = File.binread(BINARY)
  unless boot.bytesize == Apple2DiskImage::SECTOR_SIZE
    abort "#{BINARY} is #{boot.bytesize} bytes; the boot sector must be exactly " \
          "#{Apple2DiskImage::SECTOR_SIZE}"
  end

  # The Disk II boot PROM at $C600 reads track 0, physical sector 0 into $0800
  # and jumps to $0801.  That is the whole of the boot chain the spike needs:
  # one sector, no filesystem, nothing else on the disk.
  image = Apple2DiskImage.new
  image.write_sector(0, 0, boot)
  image.save(IMAGE)
  puts "wrote #{IMAGE} (#{File.size(IMAGE)} bytes, 1 sector used)"
end

# A II+ with 48K and nothing but a Disk II in slot 6.
# Written fresh each time so the spike never depends on, or disturbs, whatever
# is in ~/.config/applewin/applewin.yaml.
def write_config
  File.write(CONFIG, <<~YAML)
    Configuration:
      Apple2 Type: 1
    Configuration\\Slot 0:
      Card type: 0
    Configuration\\Slot 6:
      Card type: 1
  YAML
end

def emulator(name)
  path = File.join(APPLEWIN, name)
  abort "#{path} not found - build AppleWin, or set APPLEWIN_DIR" unless File.executable?(path)
  path
end

# --- the text page ----------------------------------------------------------

# $400 + (row & 7) * $80 + (row >> 3) * $28 - the interleave the row table in
# the prototype exists for.
def row_base(row)
  SCREEN_BASE + (row & 7) * 0x80 + (row >> 3) * 0x28
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
      break                      # the next key ends the block
    end
  end
  memory
end

# One screen cell -> [character, video mode].  On this machine bits 7-6 pick
# the mode: $00-$3F inverse, $40-$7F flashing, $80-$FF normal, and inverse
# covers only $20-$5F, which is why the II+ cannot show lowercase.
def decode_cell(byte)
  case byte
  when 0x80..0xff then [byte & 0x7f, :normal]
  when 0x40..0x7f then [(byte & 0x3f) | 0x40, :flash]
  else
    code = byte & 0x3f
    [code < 0x20 ? code + 0x40 : code, :inverse]
  end
end

# The screen as 24 strings.  An inverse cell is printed as its lowercase
# letter: the II+ has no lowercase glyphs, so lowercase in a dump can only
# ever mean inverse video, and the spike's alternating rows read at a glance.
def screen_text(memory)
  (0...ROWS).map do |row|
    (0...COLS).map do |col|
      char, mode = decode_cell(memory[row_base(row) + col].ord)
      c = char.chr
      case mode
      when :inverse then c.downcase
      when :flash   then c == ' ' ? '~' : c.downcase   # nothing should flash
      else c
      end
    end.join
  end
end

# --- headless run -----------------------------------------------------------

# Drive applen in a pty: let it boot, type any keys, F11 to snapshot, F4 to
# quit.  ncurses reads the F-keys through terminfo, so TERM has to be one we
# know the sequences for.
def headless_run(keys: '', seconds: 4)
  write_config
  File.delete(STATE) if File.exist?(STATE)
  cmd = [emulator('applen'), '--conf', CONFIG, '--state-filename', STATE,
         '--no-audio', '--d1', IMAGE]
  PTY.spawn({ 'TERM' => 'xterm' }, *cmd) do |reader, writer, pid|
    begin
      reader.winsize = [40, 100]                 # applen wants room for 24 rows
    rescue StandardError
      nil
    end
    drain = Thread.new { loop { reader.readpartial(4096) } rescue nil }
    sleep seconds
    unless keys.empty?
      writer.write(keys)
      sleep 1
    end
    writer.write("\e[23~")                       # F11: save state
    sleep 2
    writer.write("\eOS")                         # F4: quit
    sleep 2
    begin
      Process.kill('TERM', pid)
    rescue StandardError
      nil
    end
    drain.kill
  end
  abort "no save state at #{STATE}: applen did not get F11" unless File.exist?(STATE)
  read_main_memory(STATE)
end

# --- what the spike is supposed to draw -------------------------------------

BANNER1 = 'OZMOO APPLE ][ SPIKE, PHASE 1'
BANNER2 = 'ROWS A-X, KEYS ECHO'

def check(lines, keys)
  problems = []
  lines.each_with_index do |line, row|
    letter = ('A'.ord + row).chr
    letter = letter.downcase if row.odd?          # odd rows are inverse
    expected = letter * COLS
    expected[0, BANNER1.length] = BANNER1 if row == 0
    expected[0, BANNER2.length] = BANNER2.downcase if row == 12
    expected[COLS - 1] = keys[-1].upcase if row == 23 && !keys.empty?
    problems << "row #{row}: #{line.inspect}\n   expected #{expected.inspect}" if line != expected
  end
  problems
end

# --- main -------------------------------------------------------------------

mode    = :build
keys    = ''
seconds = 4
args    = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--run'     then mode = :run
  when '--ncurses' then mode = :ncurses
  when '--dump'    then mode = :dump
  when '--keys'    then keys = args.shift.to_s
  when '--seconds' then seconds = args.shift.to_i
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..20].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end

build

case mode
when :run
  write_config
  exec(emulator('sa2'), '--conf', CONFIG, '--d1', IMAGE)
when :ncurses
  write_config
  exec(emulator('applen'), '--conf', CONFIG, '--d1', IMAGE)
when :dump
  memory = headless_run(keys: keys, seconds: seconds)
  lines = screen_text(memory)
  puts
  puts '     ' + (0...COLS).map { |c| (c % 10).to_s }.join
  lines.each_with_index { |line, row| puts format('%2d | %s |', row, line) }
  puts '     (lowercase = inverse video, which is all the II+ can do to a glyph)'
  puts
  problems = check(lines, keys)
  if problems.empty?
    puts 'PASS: 24 interleaved rows, 40 columns each, both video modes, ' \
         'both banners folded to upper case' + (keys.empty? ? '' : ', key echoed')
  else
    puts "FAIL: #{problems.length} row(s) wrong"
    problems.each { |p| puts "  #{p}" }
    exit 1
  end
end
