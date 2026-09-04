#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Ozmoo Apple II: look inside a .dsk
#
# An Apple II Ozmoo disk carries no filesystem at all - no DOS 3.3 VTOC, no
# catalog, no file names - so CATALOG on a real Apple, and every host side tool
# that knows about Apple filesystems (AppleCommander, CiderPress), correctly
# report that there is nothing there.  The layout is make.rb's own, and this is
# the tool that reads it back: the analogue of LOAD"$",8 + LIST for a disk
# whose directory is the config track.
#
# Usage:
#   ruby tools/apple2-cat.rb [options] <image.dsk>
#
#     --map              per track picture of where every sector went
#     --block N          where story data block N lives, and its first bytes
#     --sector T/S       hex dump one physical sector
#     --extract FILE     reassemble the story file and write it
#     --verify FILE      compare the reassembled story against a story file
#     --order dos|prodos how to read the image (default dos, i.e. .dsk/.do)
#     --config-track N   where the config track is (default 1)
#     --brief            the summary only, no story identification
#
# ---------------------------------------------------------------------------

SECTOR_SIZE       = 256
SECTORS_PER_TRACK = 16
TRACKS            = 35
IMAGE_SIZE        = TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE

# Physical sector -> index within the track in the file. AppleWin's
# NibblizeTrack() walks physical sectors 0..15 in order and takes each one's
# data from file index ms_SectorNumber[order][physical]; MAME does the same.
ORDER = {
  dos:    [0, 7, 14, 6, 13, 5, 12, 4, 11, 3, 10, 2, 9, 1, 8, 15],
  prodos: [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15],
}

# The four DISKNAME_* codes make.rb puts in a disk's name, expanded the way
# disk.asm's .special_string_128.. does when it asks for a disk.
DISK_NAME_WORDS = { 128 => "Boot ", 129 => "Story ", 130 => "Save ", 131 => "disk " }

class Image
  attr_reader :path, :order, :bytes

  def initialize(path, order)
    @path  = path
    @order = order
    @map   = ORDER[order] or abort "unknown sector order #{order}"
    @bytes = File.binread(path).unpack("C*")
    unless @bytes.length == IMAGE_SIZE
      abort "#{path} is #{@bytes.length} bytes; a 5.25\" sector image is #{IMAGE_SIZE}.\n" +
            "(A .nib or .woz image is not a sector image and this tool cannot read it.)"
    end
  end

  # Addressed the way the drive addresses it, and the way our RWTS asks for it:
  # by physical sector number within the track.
  def sector(track, sector)
    unless (0...TRACKS).cover?(track) and (0...SECTORS_PER_TRACK).cover?(sector)
      abort "sector #{track}/#{sector} is outside the disk"
    end
    off = (track * SECTORS_PER_TRACK + @map[sector]) * SECTOR_SIZE
    @bytes[off, SECTOR_SIZE]
  end
end

# ---------------------------------------------------------------------------
# Track 0: the boot chain, which the PROM lays down before it jumps to $0801.
# ---------------------------------------------------------------------------
class BootChain
  attr_reader :sectors, :image, :entry, :read_entry
  attr_reader :terp_track, :terp_sectors, :terp_load, :skew
  attr_reader :deexo_entry, :terp_entry

  def initialize(disk)
    @sectors = disk.sector(0, 0)[0]
    @image   = []
    if @sectors >= 1 and @sectors <= SECTORS_PER_TRACK
      @sectors.times { |s| @image += disk.sector(0, s) }
    end
    @entry      = jump_at(1)
    @read_entry = jump_at(4)
    find_interpreter
    find_skew
  end

  def ok?
    !@entry.nil? and !@read_entry.nil?
  end

  # A crunched disk's sectors are an exomizer stream, and the boot chain calls
  # a decruncher before it enters the interpreter.
  def crunched? = !@deexo_entry.nil?

  private

  # $0801 and $0804 are jmp instructions and must stay where they are: they are
  # the interpreter's whole interface to the driver.
  def jump_at(offset)
    return nil unless @image[offset] == 0x4c
    @image[offset + 1] | (@image[offset + 2] << 8)
  end

  # boot loads the interpreter with
  #     lda #TERP_TRACK / sta a2_track    ($0807)
  #     lda #>LOAD_ADDR / sta a2_dest     ($0809)
  #     lda #<LOAD_ADDR / sta a2_dest_lo  ($080A)
  #     lda #0          / sta .index
  #     lda #TERP_SECTORS
  # so the three stores to the fixed parameter bytes anchor the whole run. If
  # the boot code is ever rearranged this simply reports nothing rather than
  # guessing.
  def find_interpreter
    (0..(@image.length - 24)).each do |i|
      next unless @image[i] == 0xa9 and @image[i + 2] == 0x8d and
                  @image[i + 3] == 0x07 and @image[i + 4] == 0x08
      next unless @image[i + 5] == 0xa9 and @image[i + 7] == 0x8d and
                  @image[i + 8] == 0x09 and @image[i + 9] == 0x08
      next unless @image[i + 10] == 0xa9 and @image[i + 12] == 0x8d and
                  @image[i + 13] == 0x0a and @image[i + 14] == 0x08
      next unless @image[i + 15] == 0xa9 and @image[i + 16] == 0x00 and @image[i + 17] == 0x8d
      next unless @image[i + 20] == 0xa9
      @terp_track   = @image[i + 1]
      @terp_load    = (@image[i + 6] << 8) | @image[i + 11]
      @terp_sectors = @image[i + 21]
      find_entry(i + 22)
      return
    end
  end

  # The loop ends either at a plain "jmp TERP_LOAD" or, on a crunched disk, at
  # "jsr DEEXO_ENTRY / jmp TERP_LOAD" - which is what says the sectors hold an
  # exomizer stream rather than the interpreter itself.
  def find_entry(from)
    (from..[from + 64, @image.length - 6].min).each do |i|
      if @image[i] == 0x20 and @image[i + 3] == 0x4c
        @deexo_entry = @image[i + 1] | (@image[i + 2] << 8)
        @terp_entry  = @image[i + 4] | (@image[i + 5] << 8)
        return
      elsif @image[i] == 0x4c
        @terp_entry = @image[i + 1] | (@image[i + 2] << 8)
        return
      end
    end
  end


  # skew_table is 16 bytes of (i * A2_INTERLEAVE) & 15, which identifies both
  # the table and the interleave the boot loader was built for.
  def find_skew
    (0..(@image.length - 16)).each do |i|
      next unless @image[i] == 0
      (1..15).each do |n|
        if (0..15).all? { |k| @image[i + k] == (k * n) & 15 }
          @skew = n
          return
        end
      end
    end
  end
end

# ---------------------------------------------------------------------------
# The config track, which is this disk's directory: the same bytes the
# interpreter copies into disk_info at boot, plus the vmem map behind them.
# ---------------------------------------------------------------------------
class ConfigTrack
  Disk = Struct.new(:index, :size, :device, :story_sectors, :track_map, :name)

  attr_reader :bytes, :build_id, :info_len, :interleave, :save_slots, :disks
  attr_reader :vmem_suggested, :vmem_preloaded, :vmem_high, :vmem_low, :problems
  attr_reader :save_track, :save_slot_sectors

  def initialize(disk, track)
    @bytes    = disk.sector(track, 0) + disk.sector(track, 1)
    @problems = []
    @build_id = @bytes[0, 4]
    # disk_info in the assembly starts at byte 5: the interpreter copies
    # config_load_address + 4 .. + 4 + config[4] into disk_info - 1.
    @info_len   = @bytes[4]
    @interleave = @bytes[5]
    @save_slots = @bytes[6]
    # The last four bytes of the config block are the save area: where it
    # starts and how long a slot is. They are not part of the disk entries,
    # because a save here is not a file - see build_A2 and disk.asm.
    @save_track        = @bytes[508]
    @save_slot_sectors = @bytes[509]
    @disks      = []
    parse_disks
    parse_vmem
  end

  # The story disk is the one that actually holds story data; on a single disk
  # build that is disk 1, the boot/story disk.
  def story_disk
    @disks.find { |d| d.story_sectors > 0 }
  end

  private

  def parse_disks
    count = @bytes[7]
    idx   = 8
    count.times do |i|
      size    = @bytes[idx]
      if size.nil? or size < 5 or idx + size > @bytes.length
        @problems << "disk #{i}: record size #{size.inspect} is not usable"
        return
      end
      device  = @bytes[idx + 1]
      sectors = (@bytes[idx + 2] << 8) | @bytes[idx + 3]
      ntracks = @bytes[idx + 4]
      map     = @bytes[idx + 5, ntracks]
      name    = @bytes[(idx + 5 + ntracks)...(idx + size)].take_while { |b| b != 0 }
      @disks << Disk.new(i, size, device, sectors, map, decode_name(name))
      idx += size
    end
    unless idx == 4 + @info_len
      @problems << "the disk records end at byte #{idx} but the header says #{4 + @info_len}"
    end
    @disks.each do |d|
      total = d.track_map.sum { |b| b & 0x3f }
      if total != d.story_sectors
        @problems << "disk #{d.index}: the map holds #{total} story sectors, the header says #{d.story_sectors}"
      end
    end
  end

  def decode_name(bytes)
    bytes.map { |b| DISK_NAME_WORDS[b] || (b >= 32 && b < 127 ? b.chr : "?") }.join.strip
  end

  # The vmem map follows the disk records; ozmoo.asm reads its count at
  # config_load_address + 6 + config[4].
  def parse_vmem
    base = 4 + @info_len
    return @problems << "there is no room for a vmem map" if base + 4 > @bytes.length
    n = @bytes[base + 2]
    @vmem_suggested = n
    @vmem_preloaded = @bytes[base + 3]
    @vmem_high = @bytes[base + 4, n]
    @vmem_low  = @bytes[base + 4 + n, n]
  end
end

# ---------------------------------------------------------------------------
# Where a story data block lives. This is asm/disk.asm's readblock, in Ruby:
# walk the config track's per track map to find the track, then lay the track's
# sectors down at the interleave to find the sector. make.rb's add_story_data
# is the same algorithm from the writing end, which is the point of doing it
# again here.
# ---------------------------------------------------------------------------
class StoryMap
  Place = Struct.new(:track, :sector)

  def initialize(track_map, interleave)
    @map        = track_map
    @interleave = interleave
    @cache      = {}
    @total      = track_map.sum { |b| b & 0x3f }
  end

  attr_reader :total

  def place(block)
    return nil if block < 0 or block >= @total
    build unless @cache.key?(0)
    @cache[block]
  end

  # Every block of every track, in the order the interpreter numbers them.
  def each_track
    build unless @cache.key?(0)
    @tracks.each { |t| yield t }
  end

  private

  def build
    @tracks = []
    block   = 0
    @map.each_with_index do |b, i|
      track = i + 1                        # the map starts at track 1
      used  = b & 0x3f
      skip  = (b >> 6) * 2                 # sectors reserved at the start
      next if b == 0
      count = used + skip                  # the track is this long, not 16
      taken = Array.new(count, false)
      skip.times { |s| taken[s] = true }
      sector  = 0
      sectors = []
      used.times do
        sector = (sector + 1) % count while taken[sector]
        taken[sector] = true
        sectors << sector
        @cache[block] = Place.new(track, sector)
        block += 1
        sector = (sector + @interleave) % count
      end
      @tracks << { track: track, skip: skip, used: used, count: count,
                   first_block: block - used, sectors: sectors }
    end
  end
end

# ---------------------------------------------------------------------------
# The story file, reassembled. Dynamic memory is not on the story data tracks:
# make.rb appends it to the interpreter, so it arrives with it in one sweep and
# the disk's first story block is the story file's first block *above* dynamic
# memory. Its size is not written down anywhere on the disk, so it is found by
# trying each 512 byte boundary in the interpreter blob for a z-machine header
# whose own checksum then validates the whole reconstruction.
# ---------------------------------------------------------------------------
class Story
  attr_reader :version, :release, :serial, :dynmem, :declared_length, :static_mem
  attr_reader :checksum, :computed_checksum, :data

  def initialize(terp_blob, story_data)
    @found = false
    return if terp_blob.nil? or terp_blob.empty?
    dyn = 512
    while dyn <= terp_blob.length
      off = terp_blob.length - dyn
      if try(terp_blob[off, dyn], story_data)
        @found = true
        return
      end
      dyn += 512
    end
  end

  def found?    = @found
  def checksum? = @checksum && @checksum != 0 && @checksum == @computed_checksum

  private

  # A candidate is accepted when the whole reassembled file agrees with the
  # checksum in its own header. Not every story file carries one - dejavu's is
  # zero - so when it does not, three properties of the header have to line up
  # instead, the sharpest being that make.rb chose the dynamic memory size as
  # ceil(static memory / 512), which pins it to within one block.
  def try(dynmem, story_data)
    version = dynmem[0]
    return false unless (1..8).cover?(version)
    static = (dynmem[0x0e] << 8) | dynmem[0x0f]
    return false unless static <= dynmem.length and static > dynmem.length - 512
    serial = dynmem[0x12, 6]
    return false unless serial.all? { |b| b >= 32 and b < 127 }
    scale  = version <= 3 ? 2 : version <= 5 ? 4 : 8
    length = ((dynmem[0x1a] << 8) | dynmem[0x1b]) * scale
    whole  = dynmem + story_data
    # The story file is padded up to a 512 byte boundary before it is written,
    # so the disk holds the whole of it and less than one block of padding.
    return false unless length > dynmem.length and length <= whole.length
    return false unless whole.length - length < 512
    sum = 0
    (0x40...length).each { |i| sum += whole[i] }
    computed = sum & 0xffff
    stored   = (dynmem[0x1c] << 8) | dynmem[0x1d]
    return false if stored != 0 and stored != computed
    @version           = version
    @release           = (dynmem[2] << 8) | dynmem[3]
    @serial            = serial.map(&:chr).join
    @static_mem        = static
    @dynmem            = dynmem.length
    @declared_length   = length
    @checksum          = stored
    @computed_checksum = computed
    @data              = whole[0, length]
    true
  end
end

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

def hexdump(bytes, base = 0)
  bytes.each_slice(16).with_index do |row, i|
    hex   = row.map { |b| "%02x" % b }.each_slice(8).map { |g| g.join(" ") }.join("  ")
    ascii = row.map { |b| (b >= 32 && b < 127) ? b.chr : "." }.join
    puts "  %04x  %-49s |%s|" % [base + i * 16, hex, ascii]
  end
end

def field(name, value)
  puts "  %-28s %s" % [name, value]
end

def report(disk, boot, conf, opts)
  puts File.basename(disk.path)
  field "size", "#{disk.bytes.length} bytes, #{TRACKS} tracks x #{SECTORS_PER_TRACK} sectors x #{SECTOR_SIZE}"
  field "sector order", disk.order == :dos ? "DOS 3.3 (.dsk / .do)" : "ProDOS (.po)"
  puts

  puts "Track 0: boot chain and resident RWTS"
  field "sectors the PROM loads", "#{boot.sectors}  ($0800-$%04x)" % (0x800 + boot.sectors * 256 - 1)
  if boot.ok?
    field "$0801 jmp", "$%04x   (boot, where the PROM jumps)" % boot.entry
    field "$0804 jmp", "$%04x   (rwts_read, the interpreter's sector reader)" % boot.read_entry
  else
    field "$0801 / $0804", "NOT jmp instructions - this is not an Ozmoo boot chain"
  end
  if boot.terp_track
    field "interpreter", "track #{boot.terp_track}, #{boot.terp_sectors} sectors, loads at $%04x" % boot.terp_load
    if boot.crunched?
      field "$%04x jsr" % boot.deexo_entry,
        "the decruncher: those sectors are an exomizer stream, unpacked to $%04x" % boot.terp_entry
    end
  else
    field "interpreter", "(the load sequence in the boot code was not recognised)"
  end
  field "skew table", boot.skew ? boot.skew.to_s : "(not found)"
  puts

  puts "Track #{opts[:config_track]}: config track (sectors 0 and 1)"
  field "build id", "$" + conf.build_id.map { |b| "%02x" % b }.join
  field "disk info", "#{conf.info_len} bytes"
  field "interleave", conf.interleave.to_s
  field "save slots", conf.save_slots.to_s
  field "disks", conf.disks.length.to_s
  conf.disks.each do |d|
    where = d.story_sectors > 0 ?
      "#{d.story_sectors} story sectors over #{d.track_map.count { |b| b != 0 }} tracks" :
      "no story data"
    puts "    %d  %-20s device %-3s %s" % [d.index, "\"#{d.name}\"", d.device == 0 ? "auto" : d.device.to_s, where]
  end
  if conf.vmem_suggested
    field "vmem map", "#{conf.vmem_suggested} blocks suggested, #{conf.vmem_preloaded} preloaded"
  end
  conf.problems.each { |p| puts "  ! #{p}" }
  puts
end

# The save area, and what is in it. A slot is a fixed run of sectors in the free
# tail of the disk; the first sector of the area is a directory of ten fourteen
# character comments and a flag each, which is what the game's save and restore
# listings print.
def report_saves(disk, conf)
  puts "Save slots"
  if conf.save_track.nil? or conf.save_track.zero? or conf.save_slots.zero?
    field "area", "none: the story leaves no room on this disk"
    puts
    return
  end
  sectors = conf.save_slots * conf.save_slot_sectors + 1
  last = conf.save_track + (sectors + SECTORS_PER_TRACK - 1) / SECTORS_PER_TRACK - 1
  field "area", "tracks #{conf.save_track}-#{last}, #{conf.save_slots} slots of " \
                "#{conf.save_slot_sectors} sectors"
  field "directory", "track #{conf.save_track}, physical sector 0"
  dir = disk.sector(conf.save_track, 0)
  used = 0
  conf.save_slots.times do |i|
    next if dir[140 + i].zero?
    used += 1
    name = dir[i * 14, 14].take_while { |c| c != 0 }.map(&:chr).join
    field "  slot #{i}", name.strip.empty? ? "(in use, no comment)" : name
  end
  field "in use", "none" if used.zero?
  puts
end

def report_story_data(conf, map, boot)
  puts "Story data"
  field "blocks", "#{map.total} sectors, #{map.total * SECTOR_SIZE} bytes, at interleave #{conf.interleave}"
  tracks = []
  map.each_track { |t| tracks << t[:track] }
  field "tracks used", tracks.empty? ? "none" : "#{tracks.first}-#{tracks.last} (#{tracks.length} of them)"
  if boot.terp_track and boot.terp_sectors
    last = boot.terp_track + (boot.terp_sectors + SECTORS_PER_TRACK - 1) / SECTORS_PER_TRACK - 1
    field "interpreter tracks", "#{boot.terp_track}-#{last}, no story data on them"
  end
  puts
end

def report_map(disk, conf, map, boot)
  # Which physical sector holds which sector of the interpreter, in the order
  # the boot loader reads them: its skew_table, then on to the next track.
  terp = {}
  if boot.terp_track and boot.terp_sectors
    boot.terp_sectors.times do |i|
      track  = boot.terp_track + i / SECTORS_PER_TRACK
      sector = ((i % SECTORS_PER_TRACK) * conf.interleave) & 15
      (terp[track] ||= {})[sector] = i
    end
  end
  by_track = {}
  map.each_track { |t| by_track[t[:track]] = t }

  puts "Track map. Physical sectors 0-15 left to right, as the drive names them."
  puts "  B boot chain   C config track   I interpreter   . unused"
  puts "  0-9a-z         the block on that track, in the order it is read"
  puts
  TRACKS.times do |track|
    cells = Array.new(SECTORS_PER_TRACK, ".")
    note  = ""
    if track == 0
      boot.sectors.times { |s| cells[s] = "B" }
      note = "boot chain and resident RWTS"
    end
    if (t = terp[track])
      t.each_key { |s| cells[s] = "I" }
      first, last = t.values.minmax
      note = "interpreter sectors #{first}-#{last}" +
             (track == boot.terp_track ? ", loaded at $%04x" % boot.terp_load : "")
    end
    if (t = by_track[track])
      t[:skip].times { |s| cells[s] = "C" }
      t[:sectors].each_with_index { |s, i| cells[s] = i.to_s(36) }
      note = "story blocks #{t[:first_block]}-#{t[:first_block] + t[:used] - 1}" +
             (t[:skip] > 0 ? ", #{t[:skip]} sectors reserved for the config track" : "")
    end
    puts ("  track %2d  %s  %s" % [track, cells.join, note]).rstrip
  end
  puts
end

def report_block(disk, map, n)
  place = map.place(n)
  abort "there is no story data block #{n}; this disk holds #{map.total}" unless place
  puts "Story data block #{n} is at track #{place.track}, physical sector #{place.sector}"
  hexdump(disk.sector(place.track, place.sector)[0, 64], 0)
  puts
end

def read_story_data(disk, map)
  out = []
  map.total.times do |i|
    p = map.place(i)
    out += disk.sector(p.track, p.sector)
  end
  out
end

def read_interpreter(disk, boot, interleave)
  return nil unless boot.terp_track and boot.terp_sectors
  out = []
  boot.terp_sectors.times do |i|
    track  = boot.terp_track + i / SECTORS_PER_TRACK
    sector = ((i % SECTORS_PER_TRACK) * interleave) & 15   # the boot loader's skew_table
    out += disk.sector(track, sector)
  end
  boot.crunched? ? decrunch(out) : out
end

# A crunched disk (make.rb -a2c) holds the exomizer stream from the start of
# the blob, with the decruncher itself behind it - which the decoder never
# reaches, since it stops at the stream's own end marker. exomizer decrunches
# it here the same way asm/apple2-deexo.asm does on the machine; without it
# this tool can still report the layout but cannot read the story back.
def decrunch(blob)
  exo = ENV['EXOMIZER'] || File.join(__dir__, '..', 'exomizer', 'src', 'exomizer')
  return nil unless File.executable?(exo)
  require 'tmpdir'
  Dir.mktmpdir do |dir|
    IO.binwrite(File.join(dir, 'in'), blob.pack('C*'))
    ok = system(exo, 'raw', '-q', '-d', '-c', '-P0',
                '-o', File.join(dir, 'out'), File.join(dir, 'in'))
    return nil unless ok
    return IO.binread(File.join(dir, 'out')).unpack('C*')
  end
end

def report_story(story, map)
  puts "Story file"
  unless story.found?
    puts "  Could not reassemble it: no z-machine header with a matching checksum was found"
    puts "  in the tail of the interpreter's tracks. That is expected for a disk built by"
    puts "  something other than build_A2, and a bug in the layout otherwise."
    puts
    return
  end
  field "z-machine version", story.version.to_s
  field "release / serial", "#{story.release} / #{story.serial}"
  field "length", "#{story.declared_length} bytes (from its own header)"
  field "dynamic memory", "#{story.dynmem} bytes (static memory starts at $%04x), carried behind the interpreter" % story.static_mem
  field "on the story tracks", "#{map.total * SECTOR_SIZE} bytes"
  if story.checksum == 0
    field "header checksum", "none in this story file (computed $%04x)" % story.computed_checksum
    puts "  %-28s %s" % ["", "(so the story is identified by its length and static"]
    puts "  %-28s %s" % ["", " memory size, and not confirmed by a checksum)"]
  else
    field "header checksum", "$%04x, computed $%04x: %s" %
      [story.checksum, story.computed_checksum, story.checksum? ? "ok" : "MISMATCH"]
  end
  puts
end

# ---------------------------------------------------------------------------

opts = { order: :dos, config_track: 1 }
args = ARGV.dup
image_path = nil
while (a = args.shift)
  case a
  when "--map"          then opts[:map] = true
  when "--brief"        then opts[:brief] = true
  when "--block"        then opts[:block] = Integer(args.shift)
  when "--sector"       then opts[:sector] = args.shift
  when "--extract"      then opts[:extract] = args.shift
  when "--verify"       then opts[:verify] = args.shift
  when "--order"        then opts[:order] = args.shift.to_sym
  when "--config-track" then opts[:config_track] = Integer(args.shift)
  when "-h", "--help"
    puts File.read(__FILE__).lines.drop(1).take_while { |l| l.start_with?("#") }
           .reject { |l| l.start_with?("# ---") }.map { |l| l.sub(/^# ?/, "") }.join
    exit 0
  else
    abort "unknown option #{a}" if a.start_with?("-")
    image_path = a
  end
end
abort "usage: ruby tools/apple2-cat.rb [options] <image.dsk>   (--help for the options)" unless image_path

disk = Image.new(image_path, opts[:order])
boot = BootChain.new(disk)
conf = ConfigTrack.new(disk, opts[:config_track])
sd   = conf.story_disk
abort "the config track names no disk with story data on it" unless sd
map  = StoryMap.new(sd.track_map, conf.interleave)

report(disk, boot, conf, opts)
report_saves(disk, conf)
report_story_data(conf, map, boot)

if boot.skew and boot.skew != conf.interleave
  puts "! The boot loader's skew table is #{boot.skew} but the config track says #{conf.interleave}."
  puts "  The interpreter would be read back in a different order than it was written.\n\n"
end

report_map(disk, conf, map, boot) if opts[:map]
report_block(disk, map, opts[:block]) if opts[:block]

if opts[:sector]
  t, s = opts[:sector].split(%r{[/,:]}).map { |v| Integer(v) }
  puts "Track #{t}, physical sector #{s}"
  hexdump(disk.sector(t, s))
  puts
end

story = nil
unless opts[:brief]
  story = Story.new(read_interpreter(disk, boot, conf.interleave), read_story_data(disk, map))
  report_story(story, map)
end

if opts[:extract]
  abort "cannot extract: the story file could not be reassembled" unless story&.found?
  File.binwrite(opts[:extract], story.data.pack("C*"))
  puts "Wrote #{story.data.length} bytes to #{opts[:extract]}"
end

if opts[:verify]
  abort "cannot verify: the story file could not be reassembled" unless story&.found?
  want = File.binread(opts[:verify]).unpack("C*")
  got  = story.data
  if want.length < got.length
    abort "MISMATCH against #{opts[:verify]}: the file is #{want.length} bytes, the disk holds #{got.length}"
  end
  diffs = (0...got.length).select { |i| want[i] != got[i] }
  # make.rb stamps the target number, the Ozmoo version and "OZ" into bytes
  # $38-$3f of the header on its way to the disk (and, with -un, a user name),
  # so a disk that matches everywhere else is right.
  stamp = diffs.all? { |i| i >= 0x38 and i < 0x40 }
  if diffs.empty?
    puts "Verified against #{opts[:verify]}: all #{got.length} bytes identical"
  elsif stamp
    puts "Verified against #{opts[:verify]}: #{got.length} bytes identical apart from " +
         "#{diffs.length} bytes at $%02x-$%02x, which make.rb stamps into the header at build time" %
         [diffs.first, diffs.last]
  else
    i = diffs.first
    abort "MISMATCH against #{opts[:verify]}: #{diffs.length} bytes differ, the first at " +
          "byte #{i} ($%04x): disk $%02x, file $%02x" % [i, got[i], want[i]]
  end
  extra = want.length - got.length
  puts "  (the file has #{extra} bytes beyond the length in its header)" if extra > 0
end
