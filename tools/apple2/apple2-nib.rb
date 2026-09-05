#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Write a .nib image of an Apple II 5.25" disk, ourselves, with proper interleave
#
#   ruby tools/apple2/apple2-nib.rb apple2_dejavu.dsk            # -> apple2_dejavu.nib
#   ruby tools/apple2/apple2-nib.rb game.dsk out.nib
#   ruby tools/apple2/apple2-nib.rb --verify game.dsk            # nibblize, read the
#                                                                # nibbles back, and
#                                                                # check every sector
#   ruby tools/apple2/apple2-nib.rb --analyse game.nib 4         # what is on a track
#   ruby tools/apple2/apple2-nib.rb --boot game.dsk              # boot the .dsk and the
#                                                                # .nib in AppleWin and
#                                                                # compare the screens
#
# A track is 6656 nibbles ($1A00, which is what a .nib file means by a track).
# Sixteen sectors of 14 address + 349 data nibbles leave 848 for the gaps, and
# they are spent as 48 sync bytes before sector 0 (AppleWin's gap 1), then 8
# between a sector's address and data fields and 42 after it - 413 nibbles a
# sector, 6656 exactly.  There is no per-track rotational skew: after a seek
# the head lands wherever it lands and our RWTS waits for the address field it
# wants, so aligning the tracks with each other would buy nothing.
# ---------------------------------------------------------------------------

module Apple2Nib
  TRACKS            = 35
  SECTORS_PER_TRACK = 16
  SECTOR_SIZE       = 256
  DSK_SIZE          = TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE   # 143_360
  NIB_TRACK_SIZE    = 0x1a00                                     # 6656
  NIB_SIZE          = TRACKS * NIB_TRACK_SIZE                    # 232_960

  # Physical sector -> index within the track in a .dsk file. AppleWin's
  # ms_SectorNumber[eDOSOrder] (source/DiskImageHelper.cpp); MAME agrees.
  DOS33  = [0, 7, 14, 6, 13, 5, 12, 4, 11, 3, 10, 2, 9, 1, 8, 15].freeze
  PRODOS = [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15].freeze

  GAP1 = 48   # before sector 0, and so across the track's wrap point
  GAP2 = 8    # between a sector's address field and its data field
  GAP3 = 42   # after the data field

  VOLUME = 254   # what a DOS 3.3 disk is formatted with; our RWTS folds the
                 # volume into the address checksum and does not care which

  # The 64 legal "disk bytes": at least one pair of adjacent 1 bits, never two
  # 0 bits in a row, high bit always set. Six bits of data each.
  DISK_BYTES = [
    0x96,0x97,0x9a,0x9b,0x9d,0x9e,0x9f,0xa6, 0xa7,0xab,0xac,0xad,0xae,0xaf,0xb2,0xb3,
    0xb4,0xb5,0xb6,0xb7,0xb9,0xba,0xbb,0xbc, 0xbd,0xbe,0xbf,0xcb,0xcd,0xce,0xcf,0xd3,
    0xd6,0xd7,0xd9,0xda,0xdb,0xdc,0xdd,0xde, 0xdf,0xe5,0xe6,0xe7,0xe9,0xea,0xeb,0xec,
    0xed,0xee,0xef,0xf2,0xf3,0xf4,0xf5,0xf6, 0xf7,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
  ].freeze
  DECODE = Array.new(256).tap { |t| DISK_BYTES.each_with_index { |b, i| t[b] = i } }.freeze

  module_function

  # "4 and 4": a byte as two nibbles, the odd bits then the even ones.
  def code44(value)
    [((value >> 1) | 0xaa) & 0xff, (value | 0xaa) & 0xff]
  end

  def decode44(hi, lo)
    ((hi << 1) | 1) & lo
  end

  # The address field: prologue, volume, track, sector, checksum, epilogue.
  def address_field(track, sector, volume = VOLUME)
    [0xd5, 0xaa, 0x96] +
      code44(volume) + code44(track) + code44(sector) +
      code44(volume ^ track ^ sector) +
      [0xde, 0xaa, 0xeb]
  end

  # 6-and-2: 343 nibbles from 256 bytes, the exact inverse of what
  # encode_sector in asm/apple2-rwts.asm builds and what read_sector there
  # takes apart. Six bits of each byte go in the 256 primary nibbles; the
  # bottom two go, bit-swapped, three to an auxiliary nibble. The stream is
  # written as each value's difference from the one before, so a running EOR
  # rebuilds it, and the extra nibble at the end is the last value itself -
  # which is why a reader's chain ends at zero on a sector that is intact.
  def code62(bytes)
    aux = Array.new(86, 0)
    pri = Array.new(256, 0)
    256.times do |j|
      byte = bytes.getbyte(j) || 0
      pri[j] = byte >> 2
      swapped = ((byte & 1) << 1) | ((byte >> 1) & 1)
      aux[85 - (j % 86)] |= swapped << (2 * (j / 86))
    end
    values = (0...86).map { |k| aux[85 - k] } + pri
    prev = 0
    nibbles = values.map do |v|
      n = DISK_BYTES[v ^ prev]
      prev = v
      n
    end
    nibbles << DISK_BYTES[prev]
  end

  # The inverse, for --verify: 343 nibbles back to 256 bytes, or nil if the
  # chain does not close. This is the reader's arithmetic, not the writer's.
  def decode62(nibbles)
    values = []
    prev = 0
    nibbles.each do |raw|
      six = DECODE[raw]
      return nil if six.nil?
      prev ^= six
      values << prev
    end
    return nil unless values.length == 343 && values[342].zero?
    pri = values[86, 256]
    (0...256).map do |j|
      two = (values[j % 86] >> (2 * (j / 86))) & 3
      (pri[j] << 2) | ((two & 1) << 1) | ((two >> 1) & 1)
    end.pack('C*')
  end

  def data_field(bytes)
    [0xd5, 0xaa, 0xad] + code62(bytes) + [0xde, 0xaa, 0xeb]
  end

  # One track, as the drive would see it going past the head: sector s at
  # position s, which is the whole point of writing this ourselves.
  # `sectors` is 16 strings of 256 bytes, indexed by PHYSICAL sector number.
  def track_nibbles(track, sectors, volume = VOLUME)
    nib = [0xff] * GAP1
    SECTORS_PER_TRACK.times do |sector|
      nib.concat(address_field(track, sector, volume))
      nib.concat([0xff] * GAP2)
      nib.concat(data_field(sectors[sector]))
      nib.concat([0xff] * GAP3)
    end
    raise "track #{track} came to #{nib.length} nibbles, not #{NIB_TRACK_SIZE}" \
      unless nib.length == NIB_TRACK_SIZE
    nib.pack('C*')
  end

  # A whole .dsk (or .po) as a .nib.
  def from_dsk(data, order: :dos, volume: VOLUME)
    unless data.bytesize == DSK_SIZE
      raise "#{data.bytesize} bytes is not a 35-track image (#{DSK_SIZE})"
    end
    map = order == :prodos ? PRODOS : DOS33
    out = +''.b
    TRACKS.times do |track|
      sectors = (0...SECTORS_PER_TRACK).map do |physical|
        data[(track * SECTORS_PER_TRACK + map[physical]) * SECTOR_SIZE, SECTOR_SIZE]
      end
      out << track_nibbles(track, sectors, volume)
    end
    out
  end

  # --- reading a track back, the way a drive does ---------------------------
  #
  # Used by --verify and --analyse. It walks the nibbles looking for the two
  # prologues, exactly as find_address_field and read_sector do, and knows
  # nothing about where this file chose to put the gaps.
  def scan_track(nib)
    b = nib.bytes
    found = []
    i = 0
    pending = nil
    while i < b.length - 3
      if b[i] == 0xd5 && b[i + 1] == 0xaa && (b[i + 2] == 0x96 || b[i + 2] == 0xad)
        if b[i + 2] == 0x96
          vol = decode44(b[i + 3], b[i + 4])
          trk = decode44(b[i + 5], b[i + 6])
          sec = decode44(b[i + 7], b[i + 8])
          sum = decode44(b[i + 9], b[i + 10])
          pending = { at: i, volume: vol, track: trk, sector: sec,
                      checksum_ok: (vol ^ trk ^ sec) == sum }
        else
          data = decode62(b[i + 3, 343])
          found << (pending || {}).merge(data_at: i, data: data)
          pending = nil
        end
        i += 3
      else
        i += 1
      end
    end
    found
  end

  # Every sector of a .nib, keyed [track, physical sector].
  def read_nib(nib)
    raise "#{nib.bytesize} bytes is not a 35-track .nib (#{NIB_SIZE})" unless nib.bytesize == NIB_SIZE
    out = {}
    TRACKS.times do |track|
      scan_track(nib[track * NIB_TRACK_SIZE, NIB_TRACK_SIZE]).each do |f|
        out[[track, f[:sector]]] = f
      end
    end
    out
  end
end

# --- CLI --------------------------------------------------------------------

if $PROGRAM_NAME == __FILE__
  mode = :write
  args = []
  ARGV.each do |arg|
    case arg
    when '--verify'  then mode = :verify
    when '--analyse', '--analyze' then mode = :analyse
    when '--boot'    then mode = :boot
    when '-h', '--help'
      puts File.read(__FILE__).lines[2..13].map { |l| l.sub(/^# ?/, '') }
      exit 0
    else args << arg
    end
  end
  abort 'usage: apple2-nib.rb [--verify|--analyse|--boot] <image.dsk> [out.nib|track|seconds]' if args.empty?

  source = args[0]
  abort "no such file: #{source}" unless File.exist?(source)

  if mode == :analyse
    nib = File.binread(source)
    nib = Apple2Nib.from_dsk(nib) if nib.bytesize == Apple2Nib::DSK_SIZE
    track = (args[1] || 0).to_i
    fields = Apple2Nib.scan_track(nib[track * Apple2Nib::NIB_TRACK_SIZE, Apple2Nib::NIB_TRACK_SIZE])
    puts "track #{track}: #{fields.length} sectors, in the order they go past the head"
    fields.each do |f|
      puts format('  at %5d  address track %2d sector %2d %s   data at %5d  %s',
                  f[:at], f[:track], f[:sector],
                  f[:checksum_ok] ? 'ok' : 'CHECKSUM BAD', f[:data_at],
                  f[:data] ? "decodes, first bytes #{f[:data][0, 4].unpack1('H*')}" : 'DOES NOT DECODE')
    end
    exit 0
  end

  dsk = File.binread(source)
  nib = Apple2Nib.from_dsk(dsk)

  if mode == :boot
    # The check MAME cannot do: boot the .dsk and the .nib in AppleWin's
    # headless front end and require them to reach the same screen. AppleWin
    # hands the reader whole nibbles, which is the model the MEGA65's Apple II
    # core uses, so this is the closest thing here to running it on the core.
    require_relative 'apple2-emu'
    seconds = (args[1] || 30).to_i
    # A -t:apple2e disk refuses to run on a II+, and says so, which would
    # otherwise be a screen the two images agree on perfectly.
    iie = File.basename(source).start_with?('apple2e_')
    machine = iie ? :iie_enhanced : :ii_plus
    out = File.join(Apple2Emu::TEMP, File.basename(source).sub(/\.dsk$/i, '') + '_check.nib')
    File.binwrite(out, nib)
    screens = {}
    { 'dsk' => File.expand_path(source), 'nib' => out }.each do |what, image|
      # A IIe build draws on 80 columns, whose even columns are in the aux
      # bank - so both banks have to come out of the save state, or half the
      # screen is missing and the two images agree on the wrong thing.
      memory = Apple2Emu.applen_run(image, seconds: seconds, machine: machine, aux: iie)
      screens[what] = if iie
        Apple2Emu.screen_text_80(*memory)
      else
        Apple2Emu.screen_text(memory)
      end
    end
    screens['nib'].each_with_index { |line, i| puts format('%2d|%s|', i, line) }
    problems = []
    problems << 'the .nib reports DISK ERROR' if screens['nib'].any? { |l| l.include?('DISK ERROR') }
    problems << 'the .nib screen is blank - it did not boot' if screens['nib'].all? { |l| l.strip.empty? }
    if screens['nib'] != screens['dsk']
      problems << 'the .nib and the .dsk do not reach the same screen'
      screens['dsk'].each_with_index do |line, i|
        puts "  row #{i}\n   dsk |#{line}|\n   nib |#{screens['nib'][i]}|" if line != screens['nib'][i]
      end
    end
    if problems.empty?
      puts "PASS: #{source} and its .nib boot to the same screen in AppleWin (#{machine})"
      exit 0
    end
    problems.each { |pr| puts "  FAIL: #{pr}" }
    exit 1
  end

  if mode == :verify
    # Read every sector back out of the nibbles and compare it with the .dsk
    # it came from. The reader is the one in this file, but its arithmetic is
    # the RWTS's; tools/apple2/apple2-write-spike.rb has an independent decoder
    # of its own, and --applen-nib there runs it over a nib we wrote.
    problems = []
    Apple2Nib::TRACKS.times do |track|
      sectors = Apple2Nib.scan_track(nib[track * Apple2Nib::NIB_TRACK_SIZE, Apple2Nib::NIB_TRACK_SIZE])
      order = sectors.map { |f| f[:sector] }
      problems << "track #{track}: sectors go past the head as #{order.inspect}, not 0..15" \
        unless order == (0...16).to_a
      sectors.each do |f|
        want = dsk[(track * 16 + Apple2Nib::DOS33[f[:sector]]) * 256, 256]
        problems << "track #{track} sector #{f[:sector]}: address checksum bad" unless f[:checksum_ok]
        problems << "track #{track} sector #{f[:sector]}: track field says #{f[:track]}" unless f[:track] == track
        if f[:data].nil?
          problems << "track #{track} sector #{f[:sector]}: data field does not decode"
        elsif f[:data] != want
          problems << "track #{track} sector #{f[:sector]}: data differs from the .dsk"
        end
      end
    end
    puts "#{source}: #{nib.bytesize} nibble bytes, #{Apple2Nib::TRACKS} tracks of #{Apple2Nib::NIB_TRACK_SIZE}"
    if problems.empty?
      puts 'PASS: every sector reads back byte for byte, in ascending physical order'
      exit 0
    end
    problems.first(20).each { |p| puts "  FAIL: #{p}" }
    puts "  ...and #{problems.length - 20} more" if problems.length > 20
    exit 1
  end

  out = args[1] || source.sub(/\.(dsk|do|po)$/i, '') + '.nib'
  File.binwrite(out, nib)
  puts "#{source} -> #{out} (#{nib.bytesize} bytes, #{Apple2Nib::TRACKS} tracks of #{Apple2Nib::NIB_TRACK_SIZE} nibbles)"
end
