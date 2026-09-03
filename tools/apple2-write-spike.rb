#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Build and run the Apple II write-path spike
#
#   ruby tools/apple2-write-spike.rb            # assemble + build the .dsk
#   ruby tools/apple2-write-spike.rb --mame     # ...boot it headlessly in MAME
#                                               #    and check the disk it wrote
#   ruby tools/apple2-write-spike.rb --applen   # ...the same under AppleWin
#   ruby tools/apple2-write-spike.rb --run      # ...boot it in sa2 (a window)
#
# This builds the REAL asm/apple2-rwts.asm and loads
# tools/apple2-write-prototype.asm in the place the interpreter normally
# occupies, so what runs is the resident RWTS itself. The payload writes every
# sector of three tracks, reads them all back and compares.
#
# The point of doing it this way is the second check, which is the one that
# matters: after the run, the emulator has written the .dsk back out - by
# decoding the nibbles our write path put on the track with ITS own decoder,
# which knows nothing about ours. So if the image now holds the patterns the
# payload built, our bitstream is a real 6-and-2 sector and not merely
# something we can read ourselves.
# ---------------------------------------------------------------------------

require 'fileutils'
require_relative 'apple2-disk'
require_relative 'apple2-emu'

ROOT    = Apple2Emu::ROOT
TEMP    = Apple2Emu::TEMP
RWTS    = File.join(ROOT, 'asm', 'apple2-rwts.asm')
PAYLOAD = File.join(ROOT, 'tools', 'apple2-write-prototype.asm')
IMAGE   = File.join(ROOT, 'apple2_write.dsk')
CONFIG  = File.join(TEMP, 'apple2_write.yaml')
STATE   = File.join(TEMP, 'apple2_write_state.yaml')

SYNC       = (ENV['SYNC'] || 5).to_i
SYNC_CYCLES = (ENV['SYNC_CYCLES'] || 40).to_i
EPI_SKIP   = (ENV['EPI_SKIP'] || 2).to_i
NIB_DUMP   = ARGV.include?('--nibbles') ? 1 : 0
TERP_TRACK = 2
TERP_LOAD  = 0x1000
SKEW       = (ENV['SKEW'] || 3).to_i
TEST_TRACKS = [20, 21, 34]

def assemble(source, defines, binary, labels)
  cmd = ['acme', '--cpu', '6502', '--format', 'plain'] +
        defines.map { |k, v| "-D#{k}=#{v}" } +
        ['--symbollist', labels, '-o', binary, source]
  abort "acme failed on #{source}" unless system(*cmd, out: File::NULL)
  [File.binread(binary), Apple2Emu.read_labels(labels)]
end

def build
  FileUtils.mkdir_p(TEMP)
  payload_bin = File.join(TEMP, 'apple2_write_payload.bin')
  payload, labels = assemble(PAYLOAD, { 'SKEW' => SKEW, 'NIB_DUMP' => NIB_DUMP,
                                        'WRITE_TWICE' => (ENV['WRITE_TWICE'] || 0).to_i,
                                        'TEST_TRACK_1' => TEST_TRACKS[0],
                                        'TEST_TRACK_2' => TEST_TRACKS[1],
                                        'TEST_TRACK_3' => TEST_TRACKS[2] },
                             payload_bin, File.join(TEMP, 'apple2_write_payload.txt'))
  sectors = (payload.bytesize + 255) / 256

  boot_bin = File.join(TEMP, 'apple2_write_boot.bin')
  boot, boot_labels = assemble(RWTS, { 'TERP_TRACK' => TERP_TRACK,
                                       'TERP_SECTORS' => sectors,
                                       'TERP_LOAD' => "$#{TERP_LOAD.to_s(16)}",
                                       'A2_INTERLEAVE' => SKEW,
                                       'WRITE_SYNC' => SYNC,
                                       'WRITE_SYNC_CYCLES' => SYNC_CYCLES,
                                       'WRITE_EPI_SKIP' => EPI_SKIP,
                                       'WRITE_DELAY' => (ENV['WRITE_DELAY'] || 0).to_i },
                               boot_bin, File.join(TEMP, 'apple2_write_boot.txt'))

  image = Apple2DiskImage.new
  (boot.bytesize / 256).times { |s| image.write_sector(0, s, boot[s * 256, 256]) }
  image.write_blob(TERP_TRACK, 0, payload, skew: SKEW)
  image.save(IMAGE)
  puts "wrote #{IMAGE}: boot chain #{boot.bytesize / 256} sectors, " \
       "payload #{sectors} sectors at track #{TERP_TRACK}"
  labels.merge(boot_labels)
end

# What the payload built for a given sector, so the image can be checked
# against it here rather than only inside the machine.
def expected(track, sector, salt = 0)
  seed = ((track << 4) + sector) & 0xff
  seed ^= salt
  bytes = (0...256).map { |n| (seed + n) & 0xff }
  bytes[0] = track
  bytes[1] = sector
  bytes[2] = salt
  bytes.pack('C*')
end

def check_image(path)
  data = File.binread(path)
  abort "#{path} is #{data.bytesize} bytes" unless data.bytesize == Apple2DiskImage::IMAGE_SIZE
  image = Apple2DiskImage.new
  image.instance_variable_set(:@data, data)
  problems = []
  TEST_TRACKS.each do |track|
    16.times do |sector|
      # sector 7 of the first track was written twice, the second time with a
      # salt: the image must hold the second one.
      salt = (track == TEST_TRACKS[0] && sector == 7) ? 0x5a : 0
      got = image.read_sector(track, sector)
      want = expected(track, sector, salt)
      next if got == want
      first = (0...256).find { |i| got[i] != want[i] }
      problems << format('track %d sector %d differs at byte %d (wrote $%02X, image has $%02X)',
                         track, sector, first, want[first].ord, got[first].ord)
    end
  end
  problems
end

# --- reading a raw track the way a drive does --------------------------------

DISK_BYTES = [
  0x96,0x97,0x9a,0x9b,0x9d,0x9e,0x9f,0xa6, 0xa7,0xab,0xac,0xad,0xae,0xaf,0xb2,0xb3,
  0xb4,0xb5,0xb6,0xb7,0xb9,0xba,0xbb,0xbc, 0xbd,0xbe,0xbf,0xcb,0xcd,0xce,0xcf,0xd3,
  0xd6,0xd7,0xd9,0xda,0xdb,0xdc,0xdd,0xde, 0xdf,0xe5,0xe6,0xe7,0xe9,0xea,0xeb,0xec,
  0xed,0xee,0xef,0xf2,0xf3,0xf4,0xf5,0xf6, 0xf7,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
].freeze
DECODE = Array.new(256, nil).tap { |t| DISK_BYTES.each_with_index { |b, i| t[b] = i } }.freeze

# Everything the host can say about one track of nibbles: where each field is,
# what its address field claims, and whether its data field still decodes.
def analyse_nibbles(nib)
  b = nib.bytes
  fields = []
  i = 0
  while i < b.length - 3
    if b[i] == 0xd5 && b[i + 1] == 0xaa && (b[i + 2] == 0x96 || b[i + 2] == 0xad)
      fields << [i, b[i + 2] == 0x96 ? :addr : :data]
      i += 3
    else
      i += 1
    end
  end
  puts "#{fields.count { |_, k| k == :addr }} address fields, " \
       "#{fields.count { |_, k| k == :data }} data fields in #{b.length} nibbles"

  fields.each_with_index do |(at, kind), n|
    if kind == :addr
      d = ->(j) { ((b[at + j] << 1) | 1) & b[at + j + 1] }
      vol, trk, sec, sum = d.call(3), d.call(5), d.call(7), d.call(9)
      ok = (vol ^ trk ^ sec) == sum
      gap = fields[n + 1] ? fields[n + 1][0] - at : nil
      puts format('  %5d: address field track %2d sector %2d %s, next field %s nibbles on',
                  at, trk, sec, ok ? 'ok' : 'CHECKSUM BAD', gap || '?')
    else
      vals = []
      prev = 0
      bad = nil
      343.times do |k|
        raw = b[at + 3 + k]
        six = raw && DECODE[raw]
        if six.nil?
          bad ||= k
          break
        end
        prev ^= six
        vals << prev
      end
      if bad
        puts format('  %5d: data field: nibble %d ($%02X) is not a disk byte', at, bad, b[at + 3 + bad])
      elsif vals[342] != 0
        puts format('  %5d: data field: checksum is $%02X, not 0', at, vals[342])
      else
        # unpack, exactly as the reader does, to see what the sector holds
        aux = vals[0, 86].reverse
        pri = vals[86, 256]
        data = (0...256).map do |j|
          a = aux[85 - (j % 86)]
          two = ((a >> (2 * (j / 86))) & 3)
          (pri[j] << 2) | ((two & 1) << 1) | ((two >> 1) & 1)
        end
        puts format('  %5d: data field decodes, first bytes %02X %02X %02X %02X',
                    at, data[0], data[1], data[2], data[3])
      end
    end
  end
end

# --- main -------------------------------------------------------------------

mode = :build
args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--mame'   then mode = :mame
  when '--nibbles' then mode = :nibbles
  when '--applen' then mode = :applen
  when '--run'    then mode = :run
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..8].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end

labels = build

def report(counters, problems, image)
  puts
  puts format('sectors written: %d, mismatches in the machine: %d, ' \
              'write failures: %d, read failures: %d, writes that needed a retry: %s',
              counters['w_sectors'].to_i, counters['w_bad'].to_i,
              counters['w_write_fail'].to_i, counters['w_read_fail'].to_i,
              counters['wr_retries'] || '?')
  if counters['w_bad'].to_i > 0
    puts format('first mismatch: track %d sector %d at byte %d',
                counters['w_first_bad'].to_i, counters['w_first_bad_1'].to_i,
                counters['w_first_bad_2'].to_i)
  end
  if problems.empty?
    puts "the image #{File.basename(image)} holds every pattern the payload wrote, " \
         "decoded by the emulator's own reader"
  else
    puts "#{problems.length} sector(s) wrong in the image written back:"
    problems.first(8).each { |p| puts "  #{p}" }
  end
  ok = counters['w_bad'].to_i.zero? && counters['w_write_fail'].to_i.zero? &&
       counters['w_read_fail'].to_i.zero? && problems.empty? &&
       counters['w_sectors'].to_i == 48
  puts ok ? 'PASS: 48 sectors written, read back byte for byte, and on the disk' :
            'FAIL'
  ok
end

case mode
when :nibbles
  # A track's worth of raw nibbles, and what they say about the sectors on it.
  result = Apple2Emu.mame_run(IMAGE, labels: labels, watch: 'w_done', until_value: 1,
                              dump_range: ['NIB_BUF', 7168], seconds: 120)
  File.binwrite(File.join(TEMP, 'apple2_write_nibbles.bin'), result[:dump])
  puts "#{result[:dump].bytesize} nibbles written to temp/apple2_write_nibbles.bin"
  analyse_nibbles(result[:dump])
when :run
  exec(Apple2Emu.applewin('sa2'), '--conf', Apple2Emu.write_config(CONFIG), '--d1', IMAGE)
when :mame
  result = Apple2Emu.mame_run(IMAGE, labels: labels, watch: 'w_done', until_value: 1,
                              symbols: { 'w_sectors' => 1, 'w_bad' => 1,
                                         'w_write_fail' => 1, 'w_read_fail' => 1,
                                         'w_first_bad' => 3, 'wr_retries' => 1 },
                              seconds: 400)
  puts result[:screen][0]
  counters = result[:symbols]
  counters['w_first_bad_1'] = (counters['w_first_bad'].to_i >> 8) & 0xff
  counters['w_first_bad_2'] = (counters['w_first_bad'].to_i >> 16) & 0xff
  counters['w_first_bad'] = counters['w_first_bad'].to_i & 0xff
  exit(report(counters, check_image(IMAGE), IMAGE) ? 0 : 1)
when :applen
  memory = Apple2Emu.applen_run(IMAGE, seconds: 60,
                                config: Apple2Emu.write_config(CONFIG), state: STATE)
  counters = {}
  %w[w_sectors w_bad w_write_fail w_read_fail wr_retries].each do |name|
    counters[name] = memory[labels[name]].ord
  end
  counters['w_first_bad'] = memory[labels['w_first_bad']].ord
  counters['w_first_bad_1'] = memory[labels['w_first_bad'] + 1].ord
  counters['w_first_bad_2'] = memory[labels['w_first_bad'] + 2].ord
  puts Apple2Emu.screen_text(memory)[0]
  exit(report(counters, check_image(IMAGE), IMAGE) ? 0 : 1)
end
