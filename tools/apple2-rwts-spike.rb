#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Build and run the Apple II RWTS spike (boot sector)
#
#   ruby tools/apple2-rwts-spike.rb            # assemble + build the .dsk
#   ruby tools/apple2-rwts-spike.rb --mame     # ...boot it headlessly in MAME,
#                                              #    time the read, print the
#                                              #    screen and a verdict
#   ruby tools/apple2-rwts-spike.rb --run      # ...boot it in sa2 (a window)
#   ruby tools/apple2-rwts-spike.rb --applen   # ...boot it headlessly in
#                                              #    AppleWin's ncurses front end
#   ruby tools/apple2-rwts-spike.rb --sweep    # ...and measure every interleave
#   ruby tools/apple2-rwts-spike.rb --skew 7 --tracks 4 --mame
#
# The program is tools/apple2-rwts-prototype.asm; this is the throwaway make.rb
# around it, as tools/apple2-spike.rb is for the step 0 spike.  Nothing here is
# sourced by a normal build: the real thing grows a -t:apple2 target, and this
# class becomes AppleDiskImage/MODE_A2 there.
#
# What the payload looks like on the disk, and why: each sector holds its own
# track in byte 0, its index within the track in byte 1, and a ramp from its
# destination page from byte 2 on.  So the spike is not checking that the bytes
# survived - a checksum would do that - but that the *right sector* arrived in
# the *right place*, which is what a sector-order or interleave mistake gets
# wrong while every checksum still passes.
# ---------------------------------------------------------------------------

require 'fileutils'
require_relative 'apple2-disk'
require_relative 'apple2-emu'

ROOT   = Apple2Emu::ROOT
TEMP   = Apple2Emu::TEMP
SOURCE = File.join(ROOT, 'tools', 'apple2-rwts-prototype.asm')
BINARY = File.join(TEMP, 'apple2_rwts.bin')
LABELS = File.join(TEMP, 'apple2_rwts_labels.txt')   # not acme_labels.txt: that
                                                     # belongs to the last real build
CONFIG = File.join(TEMP, 'apple2_rwts.yaml')
STATE  = File.join(TEMP, 'apple2_rwts_state.yaml')
IMAGE  = File.join(ROOT, 'apple2_rwts.dsk')

FAR_TRACK = 34          # must match the prototype
FAR_PAGE  = 0xB0

# The 256 bytes of sector `index` of `track`, which will be read into `page`.
def payload_sector(track, index, page)
  bytes = (0...256).map { |n| (page + n) & 0xFF }
  bytes[0] = track
  bytes[1] = index
  bytes.pack('C*')
end

def build(skew:, tracks:)
  FileUtils.mkdir_p(TEMP)
  cmd = ['acme', '--cpu', '6502', '--format', 'plain',
         "-DSKEW=#{skew}", "-DPAYLOAD_TRACKS=#{tracks}",
         '--symbollist', LABELS, '-o', BINARY, SOURCE]
  abort 'acme failed' unless system(*cmd, out: File::NULL)

  boot = File.binread(BINARY)
  sectors = boot.bytesize / Apple2DiskImage::SECTOR_SIZE
  if boot.bytesize % Apple2DiskImage::SECTOR_SIZE != 0 || boot.getbyte(0) != sectors
    abort "#{BINARY} is #{boot.bytesize} bytes but its sector count byte says #{boot.getbyte(0)}"
  end

  image = Apple2DiskImage.new
  # Track 0 is the boot chain.  The Disk II PROM reads sector 0 to $0800, then
  # keeps reading ascending sectors into the pages above while its counter is
  # below byte 0 of that sector, and jumps to $0801 - so the whole stage 2 is
  # laid down in plain physical order and no loader of ours is involved.
  (0...sectors).each do |s|
    image.write_sector(0, s, boot[s * Apple2DiskImage::SECTOR_SIZE, Apple2DiskImage::SECTOR_SIZE])
  end

  # The payload, at the interleave under test: logical block i of a track goes
  # to physical sector (i * skew) mod 16, which visits all sixteen exactly when
  # skew is odd.
  (1..tracks).each do |t|
    (0...16).each do |i|
      page = (t * 16 + i) & 0xFF
      image.write_sector(t, (i * skew) % 16, payload_sector(t, i, page))
    end
  end
  image.write_sector(FAR_TRACK, 0, payload_sector(FAR_TRACK, 0, FAR_PAGE))

  image.save(IMAGE)
  [sectors, tracks * 16 + 1]
end

# --- the verdict ------------------------------------------------------------

def check(result, skew:, tracks:)
  expected_sectors = tracks * 16 + 2      # + the far track, + track 1 re-read
  problems = []
  syms = result[:symbols]
  problems << "read failed at track $#{'%02X' % syms['err_track']} " \
              "sector $#{'%02X' % syms['err_sector']}" if syms['err_flag'] != 0
  problems << "data wrong at track $#{'%02X' % syms['ver_track']} " \
              "index $#{'%02X' % syms['ver_index']}" if syms['ver_flag'] != 0
  problems << "read #{syms['sec_count']} sectors, expected #{expected_sectors}" \
    if syms['sec_count'] != expected_sectors
  problems << "the program did not finish (phase #{result[:phases].last&.first})" \
    unless result[:phases].any? { |v, _| v == 4 }
  problems
end

def report(result, skew:, tracks:)
  syms = result[:symbols]
  read = Apple2Emu.phase_duration(result, 1, 2)
  sectors = syms['sec_count'].to_i
  puts
  puts '     ' + (0...Apple2Emu::COLS).map { |c| (c % 10).to_s }.join
  result[:screen].each_with_index { |line, row| puts format('%2d | %s |', row, line) }
  puts
  if read && read > 0 && sectors > 0
    puts format('skew %2d: %3d sectors in %6.2f s (%5.1f sectors/s, %4.1f KB/s), ' \
                '%d address fields (%.1f per sector), %d retries',
                skew, sectors, read, sectors / read, sectors * 256 / 1024.0 / read,
                syms['af_count'], syms['af_count'].to_f / sectors, syms['retry_count'])
    puts format('         retry causes: %d mis-seek, %d no disk, %d no data field, ' \
                '%d bad checksum',
                syms['err_seek'], syms['err_timeout'], syms['err_prologue'],
                syms['err_checksum'])
  end
  problems = check(result, skew: skew, tracks: tracks)
  if problems.empty?
    puts "PASS: every sector read and every byte of it correct, tracks 1-#{tracks} " \
         "plus the long seek to #{FAR_TRACK} and back"
  else
    puts "FAIL: #{problems.length} problem(s)"
    problems.each { |p| puts "  #{p}" }
  end
  problems.empty?
end

SYMBOLS = { 'sec_count' => 2, 'af_count' => 2, 'retry_count' => 2,
            'err_flag' => 1, 'err_track' => 1, 'err_sector' => 1,
            'err_seek' => 1, 'err_timeout' => 1, 'err_prologue' => 1,
            'err_checksum' => 1,
            'ver_flag' => 1, 'ver_track' => 1, 'ver_index' => 1 }.freeze

def run_mame(skew:, tracks:, seconds:)
  labels = Apple2Emu.read_labels(LABELS)
  Apple2Emu.mame_run(IMAGE, labels: labels, watch: 'spike_phase', until_value: 4,
                     symbols: SYMBOLS, seconds: seconds)
end

# --- main -------------------------------------------------------------------

mode    = :build
skew    = 3             # what --sweep measured as the fastest; see CLAUDE.md
tracks  = 10
seconds = 180
args    = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--mame'    then mode = :mame
  when '--run'     then mode = :run
  when '--applen'  then mode = :applen
  when '--sweep'   then mode = :sweep
  when '--skew'    then skew = args.shift.to_i
  when '--tracks'  then tracks = args.shift.to_i
  when '--seconds' then seconds = args.shift.to_i
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..15].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end
abort 'skew must be odd, or the walk does not visit all sixteen sectors' if skew.even?

case mode
when :sweep
  # One build and one boot per interleave.  The address-field count is the
  # emulator-independent half of this: it says how many sectors went past the
  # head, so 1.0 per sector is a drive that never waits and 16.0 is one that
  # waits a whole revolution for every sector it reads.
  rows = []
  [1, 3, 5, 7, 9, 11, 13, 15].each do |s|
    build(skew: s, tracks: tracks)
    result = run_mame(skew: s, tracks: tracks, seconds: seconds)
    problems = check(result, skew: s, tracks: tracks)
    read = Apple2Emu.phase_duration(result, 1, 2)
    syms = result[:symbols]
    rows << [s, read, syms['sec_count'], syms['af_count'], syms['retry_count'], problems]
    puts format('skew %2d: %6.2f s  %5.1f sectors/s  %5.1f KB/s  ' \
                '%5d address fields (%5.2f/sector)  %d retries  %s',
                s, read || 0, read ? syms['sec_count'] / read : 0,
                read ? syms['sec_count'] * 256 / 1024.0 / read : 0,
                syms['af_count'], syms['af_count'].to_f / [syms['sec_count'], 1].max,
                syms['retry_count'], problems.empty? ? 'ok' : problems.join('; '))
  end
  best = rows.select { |r| r[5].empty? && r[1] }.min_by { |r| r[1] }
  puts
  puts "fastest interleave: skew #{best[0]} at #{format('%.2f', best[1])} s" if best
  exit(rows.all? { |r| r[5].empty? } ? 0 : 1)
else
  sectors, payload = build(skew: skew, tracks: tracks)
  puts "wrote #{IMAGE}: #{sectors} boot sectors, #{payload} payload sectors, skew #{skew}"
  case mode
  when :mame
    exit(report(run_mame(skew: skew, tracks: tracks, seconds: seconds), skew: skew, tracks: tracks) ? 0 : 1)
  when :run
    exec(Apple2Emu.applewin('sa2'), '--conf', Apple2Emu.write_config(CONFIG), '--d1', IMAGE)
  when :applen
    memory = Apple2Emu.applen_run(IMAGE, seconds: 30, config: Apple2Emu.write_config(CONFIG), state: STATE)
    Apple2Emu.screen_text(memory).each_with_index { |line, row| puts format('%2d | %s |', row, line) }
  end
end
