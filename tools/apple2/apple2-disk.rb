# ---------------------------------------------------------------------------
# Apple II 5.25" disk image writer
#
# A .dsk (a.k.a. .do) image is 35 tracks x 16 sectors x 256 bytes of plain
# sector data with no header, and Ozmoo's Apple II disks carry no filesystem at
# all: make.rb will lay out the boot chain, the config track and the story as
# raw sectors, exactly as it lays out a d64 today.  So this is the Apple
# counterpart of make.rb's D64_image, kept standalone for the step 0 spike and
# meant to move into make.rb (as AppleDiskImage, MODE_A2) at step 2.
#
# The one subtlety is sector order.  A .dsk stores each track's sectors in DOS
# 3.3 *logical* order, while what is actually written round the track - and
# what the address field of each sector says, and what our RWTS will ask for -
# is the *physical* sector number.  An emulator interleaves them as it
# nibblizes the track.  Since we own both ends (make.rb's layout and our own
# RWTS) the interleave is ours to choose for demand-paging speed, so this class
# addresses sectors physically and does the mapping itself.
#
# The mapping is AppleWin's own, from AppleWin/source/DiskImageHelper.cpp,
# where NibblizeTrack() walks the physical sectors 0..15 in order, writes each
# one's number into its address field, and takes its data from file offset
# ms_SectorNumber[eDOSOrder][physical] << 8. ms_SectorNumber[eDOSOrder] is
# the DOS33 table below.  MAME does the same.
# ---------------------------------------------------------------------------

class Apple2DiskImage
  TRACKS            = 35
  SECTORS_PER_TRACK = 16
  SECTOR_SIZE       = 256
  IMAGE_SIZE        = TRACKS * SECTORS_PER_TRACK * SECTOR_SIZE  # 143_360

  # Index into the image file, given a physical sector number.
  DOS33  = [0, 7, 14, 6, 13, 5, 12, 4, 11, 3, 10, 2, 9, 1, 8, 15].freeze
  PRODOS = [0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15].freeze

  attr_reader :order

  # order: :dos for a .dsk/.do image (what every emulator assumes for that
  # extension), :prodos for a .po one.
  def initialize(order: :dos)
    @order = order
    @map = order == :dos ? DOS33 : PRODOS
    @data = "\x00".b * IMAGE_SIZE
    @used = {}
  end

  # Write one 256-byte sector, addressed the way the drive sees it: by physical
  # sector number within the track.  Short data is zero padded.
  def write_sector(track, sector, bytes)
    check(track, sector)
    raise "sector #{track}/#{sector} is #{bytes.bytesize} bytes, max #{SECTOR_SIZE}" if bytes.bytesize > SECTOR_SIZE
    warn "warning: sector #{track}/#{sector} written twice" if @used[[track, sector]]
    @used[[track, sector]] = true
    @data[offset(track, sector), SECTOR_SIZE] = bytes.b.ljust(SECTOR_SIZE, "\x00")
  end

  # Write a blob across consecutive physical sectors, starting at
  # track/sector and stepping by `skew` sectors within a track (skew 1 is
  # every sector in address-field order; a larger skew is the interleave that
  # gives the drive time to hand a sector over before the next one arrives).
  # Returns the [track, sector] one past the end.
  def write_blob(track, sector, bytes, skew: 1)
    seen = {}
    (0...bytes.bytesize).step(SECTOR_SIZE) do |i|
      raise "blob does not fit: track #{track} is past the end of the disk" if track >= TRACKS
      write_sector(track, sector, bytes[i, SECTOR_SIZE])
      seen[sector] = true
      sector = (sector + skew) % SECTORS_PER_TRACK
      if seen[sector]                       # this track is full
        track += 1
        sector = 0
        seen = {}
      end
    end
    [track, sector]
  end

  def read_sector(track, sector)
    check(track, sector)
    @data[offset(track, sector), SECTOR_SIZE]
  end

  def save(path)
    File.binwrite(path, @data)
    path
  end

  private

  def offset(track, sector)
    (track * SECTORS_PER_TRACK + @map[sector]) * SECTOR_SIZE
  end

  def check(track, sector)
    raise "track #{track} out of range 0..#{TRACKS - 1}" unless (0...TRACKS).cover?(track)
    raise "sector #{sector} out of range 0..#{SECTORS_PER_TRACK - 1}" unless (0...SECTORS_PER_TRACK).cover?(sector)
  end
end
