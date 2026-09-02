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
#   ruby tools/apple2-spike.rb --mame          # ...the same check under MAME
#
# The spike is tools/apple2-prototype.asm, a single boot sector; this script is
# the throwaway make.rb around it. Nothing here is sourced by a normal build.
# The RWTS read - is tools/apple2-rwts-prototype.asm and its own driver beside this
# one; the emulator plumbing both use is tools/apple2-emu.rb.
#
# --dump and --mame are the two headless checks, and they see different things.
# --dump drives AppleWin's ncurses front end in a pty and decodes the text page
# out of a save state (the terminal it paints is a stream of ncurses cursor
# moves, not a screen).  --mame reads the text page straight out of the running
# machine, and can also time it and read variables by name, which is what the
# RWTS spike needs; it is the closer analogue of xemu's -dumpscreen.  Neither
# can see the glyph the video hardware actually fetched - --run is for that,
# exactly as -dumpscreen cannot see a wrong charset on the MEGA65.
# ---------------------------------------------------------------------------

require 'fileutils'
require_relative 'apple2-disk'
require_relative 'apple2-emu'

ROOT   = Apple2Emu::ROOT
TEMP   = Apple2Emu::TEMP
SOURCE = File.join(ROOT, 'tools', 'apple2-prototype.asm')
BINARY = File.join(TEMP, 'apple2_spike.bin')
LABELS = File.join(TEMP, 'apple2_spike_labels.txt')  # not acme_labels.txt: that
                                                     # belongs to the last real build
CONFIG = File.join(TEMP, 'apple2_spike.yaml')
STATE  = File.join(TEMP, 'apple2_spike_state.yaml')
IMAGE  = File.join(ROOT, 'apple2_spike.dsk')

COLS = Apple2Emu::COLS
ROWS = Apple2Emu::ROWS

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
  # one sector, no filesystem, nothing else on the disk.  (Byte 0 of that
  # sector is the number of sectors the PROM loads before jumping, which is why
  # this one says 1 and the RWTS spike's says 6.)
  image = Apple2DiskImage.new
  image.write_sector(0, 0, boot)
  image.save(IMAGE)
  puts "wrote #{IMAGE} (#{File.size(IMAGE)} bytes, 1 sector used)"
end

# --- what the spike is supposed to draw -------------------------------------

BANNER1 = 'OZMOO APPLE ][ SPIKE'
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

def verdict(lines, keys)
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
  end
  problems.empty?
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
  when '--mame'    then mode = :mame
  when '--keys'    then keys = args.shift.to_s
  when '--seconds' then seconds = args.shift.to_i
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..15].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end

build

case mode
when :run
  exec(Apple2Emu.applewin('sa2'), '--conf', Apple2Emu.write_config(CONFIG), '--d1', IMAGE)
when :ncurses
  exec(Apple2Emu.applewin('applen'), '--conf', Apple2Emu.write_config(CONFIG), '--d1', IMAGE)
when :dump
  memory = Apple2Emu.applen_run(IMAGE, keys: keys, seconds: seconds,
                                config: Apple2Emu.write_config(CONFIG), state: STATE)
  exit(verdict(Apple2Emu.screen_text(memory), keys) ? 0 : 1)
when :mame
  # The spike ends in a keyboard loop, so there is no phase to wait for: give
  # MAME a few emulated seconds and read the screen it left.
  result = Apple2Emu.mame_run(IMAGE, seconds: 5)
  exit(verdict(result[:screen], '') ? 0 : 1)
end
