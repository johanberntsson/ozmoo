# specialised make for Ozmoo

require 'fileutils'

$is_windows = (ENV['OS'] == 'Windows_NT')

if $is_windows then
	# Paths on Windows
    $X64 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\x64.exe -autostart-warp" # -autostart-delay-random"
    $C1541 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\c1541.exe"
    $EXOMIZER = "C:\\ProgramsWoInstall\\Exomizer-3.0.2\\win32\\exomizer.exe"
    $ACME = "C:\\ProgramsWoInstall\\acme0.96.4win\\acme\\acme.exe"
else
	# Paths on Linux
    $X64 = "/usr/bin/x64 -autostart-delay-random"
    $C1541 = "/usr/bin/c1541"
    $EXOMIZER = "exomizer/src/exomizer"
    $ACME = "acme"
end

$PRINT_DISK_MAP = false # Set to true to print which blocks are allocated

# Typically only SMALLBLOCK should be enabled.
$GENERALFLAGS = [
	'SMALLBLOCK', # Use 512 byte blocks instead of 1024 byte blocks for virtual memory. NOTE: 1024 byte mode is slower and currently broken.
#	'UNSAFE', # Remove almost all runtime error checking. This makes the terp ~100 bytes smaller.
#	'SLOW', # Remove some optimizations for speed. This makes the terp ~100 bytes smaller.
#	'VICE_TRACE', # Send the last instructions executed to Vice, to aid in debugging
#	'TRACE', # Save a trace of the last instructions executed, to aid in debugging
#	'COUNT_SWAPS', # Keep track of how many vmem block reads have been done.
]

# For a production build, none of these flags should be enabled.
$DEBUGFLAGS = [
#	'DEBUG', # This gives some debug capabilities, like informative error messages. It is automatically included if any other debug flags are used.
#	'VIEW_STACK_RECORDS',
#	'PRINTSPEED'
#	'BENCHMARK',
#	'VMEM_STRESS', # very slow but gives vmem a workout
#	'TRACE_FLOPPY',
#	'TRACE_VM',
#	'PRINT_SWAPS',
#	'TRACE_FLOPPY_VERBOSE',
#	'TRACE_PRINT_ARRAYS',
#	'TRACE_PROP',
#	'TRACE_READTEXT',
#	'TRACE_SHOW_DICT_ENTRIES',
#	'TRACE_TOKENISE',
]

$CACHE_PAGES = 4 # Should normally be 2-8. Use 4 unless you have a good reason not to. One page will be added automatically if it would otherwise be wasted due to vmem alignment issues.

$CONFIG_TRACK = 1

MODE_P = 1
MODE_S1 = 2
MODE_S2 = 3
MODE_D2 = 4
MODE_D3 = 5
MODE_81 = 6

mode = MODE_S1

DISKNAME_BOOT = 128
DISKNAME_STORY = 129
DISKNAME_SAVE = 130
DISKNAME_DISK = 131

$BUILD_ID = Random.rand(0 .. 2**32-1)

$VMEM_BLOCKSIZE = $GENERALFLAGS.include?('SMALLBLOCK') ? 512 : 1024

$ZEROBYTE = 0.chr

$EXECDIR = Dir.pwd
$SRCDIR = File.join(__dir__, 'asm')
$TEMPDIR = File.join(__dir__, 'temp')
Dir.mkdir($TEMPDIR) unless Dir.exist?($TEMPDIR)

$labels_file = File.join($TEMPDIR, 'acme_labels.txt')
$loader_labels_file = File.join($TEMPDIR, 'acme_labels_loader.txt')
# $loader_pic_file = File.join($EXECDIR, 'loaderpic.kla')
$loader_file = File.join($TEMPDIR, 'loader')
$loader_zip_file = File.join($TEMPDIR, 'loader_zip')
$ozmoo_file = File.join($TEMPDIR, 'ozmoo')
$zip_file = File.join($TEMPDIR, 'ozmoo_zip')
$good_zip_file = File.join($TEMPDIR, 'ozmoo_zip_good')
$compmem_filename = File.join($TEMPDIR, 'compmem.tmp')

$beyondzork_releases = {
    "r47-s870915" => "f347 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r49-s870917" => "f2c0 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r51-s870923" => "f2a8 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r57-s871221" => "f384 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r60-s880610" => "f2dc 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1"
}

class Disk_image
	def base_initialize
		@interleave = 1
		@config_track = $CONFIG_TRACK
		@skip_tracks = Array.new(@tracks)
		offset = 0
		@track_offset = @track_length.map {|len| k = offset; offset += len; k }
#		puts "offset = #{@track_offset}"
		@reserved_sectors = Array.new(@track_length.length, 0)
		@config_track_map = []
		@contents = Array.new(256 * @track_length.inject(0, :+), 0)
		@storydata_start_track = 0
		@storydata_end_track = 0
		@storydata_blocks = 0
	end

	def calculate_initial_free_blocks
		@free_blocks = @track_length.inject(0, :+) - @reserved_sectors.inject(0, :+)
		puts "Free disk blocks at start: #{@free_blocks}"
	end
	
	def free_blocks
		@free_blocks
	end

	def interleave
		@interleave
	end
	
	def add_story_data(max_story_blocks:, add_at_end:)
	
		max_story_blocks -= 1 if max_story_blocks % 2 != 0
		story_data_length = $story_file_data.length - $story_file_cursor
		num_sectors = [story_data_length / 256, max_story_blocks].min

		first_story_track = 1
		first_story_track_max_sectors = get_track_length(first_story_track) - get_reserved_sectors(first_story_track)
		temp_sectors = num_sectors
		if add_at_end then
			@tracks.downto(1) do |track|
				track_sectors = get_track_length(track) - get_reserved_sectors(track)
				if temp_sectors > track_sectors then
					temp_sectors -= track_sectors
				else
					first_story_track = track
					first_story_track_max_sectors = temp_sectors
					break
				end
			end
		end

		for track in 1 .. @tracks do
			print "#{track}:" if $PRINT_DISK_MAP
			if num_sectors > 0 then
				reserved_sectors = get_reserved_sectors(track)
				sector_count = get_track_length(track)
				if track < first_story_track then
					sector_count = reserved_sectors
				elsif track == first_story_track
					sector_count = first_story_track_max_sectors + reserved_sectors
				elsif sector_count - reserved_sectors > num_sectors
					sector_count = num_sectors + reserved_sectors
				end
				track_map = Array.new(sector_count, 0)
				reserved_sectors.times do |i|
					track_map[i] = 1
				end
				free_sectors_in_track = sector_count - reserved_sectors
				last_story_sector = 0
	#	Find right sector.
	#		1. Start at 0
	#		2. Find next free sector
	#		3. Decrease blocks to go. If < 0, we are done
	#		4. Mark sector as used.
	#		5. Add interleave, go back to 2	
				sector = 0
				[free_sectors_in_track, num_sectors].min.times do
					while track_map[sector] != 0
						sector = (sector + 1) % sector_count
					end
					track_map[sector] = 1
					allocate_sector(track, sector)
					add_story_block(track, sector)
					last_story_sector += 1
					@free_blocks -= 1
					num_sectors -= 1
					@storydata_start_track = track if @storydata_start_track < 1
					@storydata_end_track = track
					@storydata_blocks += 1
					sector = (sector + @interleave) % sector_count
				end

				@config_track_map.push(64 * reserved_sectors / 2 + last_story_sector)
			else
				@config_track_map.push 0
			end # if num_sectors > 0
			puts if $PRINT_DISK_MAP
		end # for track
#		puts num_sectors.to_s
		add_directory()

		@config_track_map = @config_track_map.reverse.drop_while{|i| i==0}.reverse # Drop trailing zero elements

		@free_blocks
	end

	def config_track_map
		@config_track_map
	end
	
	def set_config_data(data)
		if !@is_boot_disk then
			puts "ERROR: Tried to save config data on a non-boot disk."
			exit 1
		elsif !(data.is_a?(Array)) or data.length > 512 then
			puts "ERROR: Config data array is not the right length."
			exit 1
		end
		data[5] = @interleave
		@contents[@track_offset[@config_track] * 256 .. @track_offset[@config_track] * 256 + data.length - 1] = data
	end
	
	def save
		begin
			diskimage_file = File.open(@diskimage_filename, "wb")
		rescue
			puts "ERROR: Can't open #{@diskimage_filename} for writing"
			exit 1
		end
		diskimage_file.write @contents.pack("C*")
		diskimage_file.close
	end

	def get_track_length(track)
		@track_length[track]
	end

	def get_reserved_sectors(track)
		@reserved_sectors[track]
	end
	
	def add_story_block(track, sector)
		story_block_added = false
		if $story_file_data.length > $story_file_cursor + 1
			@contents[256 * (@track_offset[track] + sector) .. 256 * (@track_offset[track] + sector) + 255] =
				$story_file_data[$story_file_cursor .. $story_file_cursor + 255].unpack("C*")
			$story_file_cursor += 256
			story_block_added = true
		end
		story_block_added
	end
end  # class Disk_image

class D64_image < Disk_image
	def initialize(disk_title:, diskimage_filename:, is_boot_disk:, forty_tracks:)
		puts "Creating disk image..."

		@disk_title = disk_title
		@diskimage_filename = diskimage_filename
		@is_boot_disk = is_boot_disk

		@tracks = forty_tracks ? 40 : 35 # 35 or 40 are useful options
		@track_length = Array.new(@tracks + 1) {|track| 
			track == 0 ? 0 :
			track < 18 ? 21 : 
			track < 25 ? 19 : 
			track < 31 ? 18 :
			17
		}
#		puts "Tracks: #{@track_length.to_s}"

		base_initialize()

		@interleave = 9

		# NOTE: Blocks to skip can only be 0, 2, 4 or 6, or entire track.
		@reserved_sectors[18] = 2 # 2: Skip BAM and 1 directory block, 19: Skip entire track
		@reserved_sectors[@config_track] = 2 if @is_boot_disk

		calculate_initial_free_blocks()
			
		# BAM
		@track1800 = [
			# $16500 = 91392 = 357 (18,0)
			0x12,0x01, # track/sector
			0x41, # DOS version
			0x00, # unused
			# <free sectors>,<0-7>,<8-15>,<16-?, remaining bits 0>
			0x15,0xff,0xff,0x1f, # 16504, track 01 (21 sectors)
			0x15,0xff,0xff,0x1f, # 16508, track 02
			0x15,0xff,0xff,0x1f, # 1650c, track 03
			0x15,0xff,0xff,0x1f, # 16510, track 04
			0x15,0xff,0xff,0x1f, # 16514, track 05
			0x15,0xff,0xff,0x1f, # 16518, track 06
			0x15,0xff,0xff,0x1f, # 1651c, track 07
			0x15,0xff,0xff,0x1f, # 16520, track 08
			0x15,0xff,0xff,0x1f, # 16524, track 09
			0x15,0xff,0xff,0x1f, # 16528, track 10
			0x15,0xff,0xff,0x1f, # 1652c, track 11
			0x15,0xff,0xff,0x1f, # 16530, track 12
			0x15,0xff,0xff,0x1f, # 16534, track 13
			0x15,0xff,0xff,0x1f, # 16538, track 14
			0x15,0xff,0xff,0x1f, # 1653c, track 15
			0x15,0xff,0xff,0x1f, # 16540, track 16
			0x15,0xff,0xff,0x1f, # 16544, track 17
			0x11,0xfc,0xff,0x07, # 16548, track 18 (19 sectors)
			0x13,0xff,0xff,0x07, # 1654c, track 19
			0x13,0xff,0xff,0x07, # 16550, track 20
			0x13,0xff,0xff,0x07, # 16554, track 21
			0x13,0xff,0xff,0x07, # 16558, track 22
			0x13,0xff,0xff,0x07, # 1655c, track 23
			0x13,0xff,0xff,0x07, # 16560, track 24
			0x12,0xff,0xff,0x03, # 16564, track 25 (18 sectors)
			0x12,0xff,0xff,0x03, # 16568, track 26
			0x12,0xff,0xff,0x03, # 1656c, track 27
			0x12,0xff,0xff,0x03, # 16570, track 28
			0x12,0xff,0xff,0x03, # 16574, track 29
			0x12,0xff,0xff,0x03, # 16578, track 30
			0x11,0xff,0xff,0x01, # 1657c, track 31 (17 sectors)
			0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,
			0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,
			0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0, # label (game name)
			0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,
			0xa0,0xa0,0x30,0x30,0xa0,0x32,0x41,0xa0,
			0xa0,0xa0,0xa0,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,
			0x11,0xff,0xff,0x01,0x11,0xff,0xff,0x01,
			0x11,0xff,0xff,0x01,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		]

		# Create a disk image. Return number of free blocks, or -1 for failure.

		for track in 36 .. 40 do
			@track1800[0xc0 + 4 * (track - 36) .. 0xc0 + 4 * (track - 36) + 3] = (track > @tracks ? [0,0,0,0] : [0x11,0xff,0xff,0x01])
		end
		
		# Set disk title
		c64_title = name_to_c64(disk_title)
		@track1800[0x90 .. 0x9f] = Array.new(0x10, 0xa0)
		[c64_title.length, 0x10].min.times do |charno|
			@track1800[0x90 + charno] = c64_title[charno].ord
		end
		
		if @is_boot_disk then
			allocate_sector(@config_track, 0)
			allocate_sector(@config_track, 1)
		end

		@free_blocks
	end # initialize


	private
	
	def allocate_sector(track, sector)
		print "*" if $PRINT_DISK_MAP
		index1 = 4 * track
		index2 = 4 * track + 1 + (sector / 8)
		if track > 35 then # Use SpeedDOS 40-track BAM layout
			index1 += 0x30
			index2 += 0x30
		end
		# adjust number of free sectors
		@track1800[index1] -= 1
		# allocate sector
		index3 = 255 - 2**(sector % 8)
		@track1800[index2] &= index3
	end

	def add_directory()
		# Add disk info and BAM at 18:00
		@contents[@track_offset[18] * 256 .. @track_offset[18] * 256 + 255] = @track1800

		# Add directory at 18:01
		@contents[@track_offset[18] * 256 + 256] = 0 
		@contents[@track_offset[18] * 256 + 257] = 0xff 
	end
	
end # class D64_image

class D81_image < Disk_image
	def initialize(disk_title:, diskimage_filename:)
		puts "Creating disk image..."

		@disk_title = disk_title
		@diskimage_filename = diskimage_filename
		@is_boot_disk = true

		@tracks = 80
		@track_length = Array.new(@tracks + 1, 40)
		@track_length[0] = 0

		base_initialize()

		# NOTE: Blocks to skip can only be 0, 2, 4 or 6, or entire track.
		@reserved_sectors[40] = 40 # 4: Skip BAM and 1 directory block, 6: Skip BAM and 3 directory blocks, 40: Skip entire track
		@reserved_sectors[@config_track] = 2

		calculate_initial_free_blocks()
			
		# BAM
		@track4000 = [
			# $16500 = 91392 = 357 (18,0)
			0x28, 0x03, # track/sector of first directory sector
			0x44, # DOS version
			0x00, # Not used, don't alter value
			0x4F, 0x5A, 0x4D, 0x4F, 0x4F, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, 0xA0, # Disk name
			0xA0, 0xA0, # Not used, don't alter value 
			0x31, 0x41, # Disk ID
			0xA0, # Not used, don't alter value
			0x33, # DOS version
			0x44, # Disk version
			0xA0, 0xA0 # Not used, don't alter value
		]	

		@track4001 = [
			0x28,0x02, # track/sector of next BAM sector
			0x44, # Version#
			0xBB, # One's complement of version#
			0x31,0x41, # Disk ID (same as in 40:00)
			0xC0, # I/O byte
			0x00, # Auto-boot-loader flags
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, # Reserved for future use
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 1
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 2-4
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 5-8
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 9-12
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 13-16
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 17-20
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 21-24
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 25-28
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 29-32
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 33-36
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x24,0xF0,0xFF,0xFF,0xFF,0xFF, # Track 37-40
		# Sector 40:02
			0x00,0xFF, # track/sector of next BAM sector
			0x44, # Version#
			0xBB, # One's complement of version#
			0x31,0x41, # Disk ID (same as in 40:00)
			0xC0, # I/O byte
			0x00, # Auto-boot-loader flags
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, # Reserved for future use
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 41
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 42-44
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 45-48
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 49-52
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 53-56
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 57-60
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 61-64
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 65-68
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 69-72
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF, # Track 73-76
			0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF,0x28,0xFF,0xFF,0xFF,0xFF,0xFF  # Track 77-80
		]

		# Create a disk image. Return number of free blocks, or -1 for failure.

		# Set disk title
		c64_title = name_to_c64(disk_title)
		@track4000[0x04 .. 0x13] = Array.new(0x10, 0xa0)
		[c64_title.length, 0x10].min.times do |charno|
			@track4000[0x04 + charno] = c64_title[charno].ord
		end
		
		allocate_sector(@config_track, 0)
		allocate_sector(@config_track, 1)

		@free_blocks
	end # initialize

	def create_story_partition
		if @storydata_start_track > 0 and @storydata_end_track > @storydata_start_track

			sector = @contents[(@track_offset[40] + 3) * 256 .. (@track_offset[40] + 3) * 256 + 255]
			@storydata_start_track -= 1 if @config_track == @storydata_start_track - 1
			@storydata_end_track += 1 if @config_track == @storydata_end_track + 1
			allocate_track(@storydata_end_track)
			allocate_track(@config_track)
			
			if @storydata_start_track < 40 and @storydata_end_track > 40
				return false unless create_a_partition(sector, @storydata_start_track, 39, 'data-a') == true
				@contents[(@track_offset[40] + 3) * 256 .. (@track_offset[40] + 3) * 256 + 255] = sector
				return false unless create_a_partition(sector, 41, @storydata_end_track, 'data-b') == true
				@contents[(@track_offset[40] + 3) * 256 .. (@track_offset[40] + 3) * 256 + 255] = sector
			else
				return false unless create_a_partition(sector, @storydata_start_track, @storydata_end_track, 'data') == true
				@contents[(@track_offset[40] + 3) * 256 .. (@track_offset[40] + 3) * 256 + 255] = sector
			end
			if @config_track < @storydata_start_track or @config_track > @storydata_end_track 
				return false unless create_a_partition(sector, @config_track, @config_track, 'cfg') == true
				@contents[(@track_offset[40] + 3) * 256 .. (@track_offset[40] + 3) * 256 + 255] = sector
			end
			true
		else
			false
		end
	end


	private
	
	def allocate_sector(track, sector)
		print "*" if $PRINT_DISK_MAP
		index1 = (track > 40 ? 0x100: 0) + 0x10 +  6 * ((track - 1) % 40)
		index2 = index1 + 1 + (sector / 8)

		# adjust number of free sectors
		@track4001[index1] -= 1
		# allocate sector
		index3 = 255 - 2**(sector % 8)
		@track4001[index2] &= index3
	end

	def add_directory()
		# Add disk info at 40:00
		@contents[@track_offset[40] * 256 .. @track_offset[40] * 256 + @track4000.length - 1] = @track4000

		# Add BAM at 40:01 and 40:02
		@contents[(@track_offset[40] + 1) * 256 .. (@track_offset[40] + 1) * 256 + @track4001.length - 1] = @track4001

		# Add directory at 40:03
		@contents[(@track_offset[40] + 3) * 256] = 0 
		@contents[(@track_offset[40] + 3) * 256 + 1] = 0xff 
	end

	def create_a_partition(sector, start_track, end_track, name)
		entry = 1
		while entry < 8 and sector[0x20 * entry + 2] > 0
			entry += 1
		end
		return false if entry > 7
		entrybase = 0x20 * entry
		sector[entrybase + 2] = 0x85 # CBM type ( = partition)
		sector[entrybase + 3] = start_track
		sector[entrybase + 4] = 0 # Start sector
		c64_title = name_to_c64(name)
		sector[entrybase + 0x5 .. entrybase + 0x14] = Array.new(0x10, 0xa0)
		[c64_title.length, 0x10].min.times do |charno|
			sector[entrybase + 0x5 + charno] = c64_title[charno].ord
		end
		sector[entrybase + 0x15 .. entrybase + 0x1d] = Array.new(9, 0)
		part_size = (end_track - start_track + 1) * 40
		sector[entrybase + 0x1e] = part_size % 256
		sector[entrybase + 0x1f] = part_size / 256
		true
	end
	
	def allocate_track(track)
		index1 = (track > 40 ? 0x100: 0) + 0x10 +  6 * ((track - 1) % 40)
		@contents[(@track_offset[40] + 1) * 256 + index1 .. (@track_offset[40] + 1) * 256 + index1 + 5] = Array.new(6, 0)
	end
	
end # class D81_image

################################## END Disk image classes

def filename_to_title(name, remove_the_if_longer_than)
	# Convert camel case and underscore to spaces. Remove "The" or "A" at beginning if the name gets too long.
	title = name.dup
	camel_case = title =~ /[a-z]/ and title =~ /[A-Z]/ and title !~ / |_/ 
	if camel_case then
		title.gsub!(/([a-z])([A-Z])/,'\1 \2')
		title.gsub!(/A([A-Z])/,'A \1')
	end
	title.gsub!(/_+/," ")
	title.gsub!(/(^ +)|( +)$/,"")
	if remove_the_if_longer_than
		title.gsub!(/^(the|a) (.*)$/i,'\2') if title.length > remove_the_if_longer_than 
	end
	title.capitalize! if title =~ /^[a-z]/
	title
end

def name_to_c64(name)

	c64_name = filename_to_title(name, 16)

	c64_name.length.times do |charno|
		code = c64_name[charno].ord
		code &= 0xdf if code >= 0x61 and code <= 0x7a
		c64_name[charno] = code.chr
	end
	c64_name
end

def build_interpreter()
	necessarysettings =  " --setpc #{$start_address} -DCACHE_PAGES=#{$CACHE_PAGES} -DSTACK_PAGES=#{$stack_pages} -D#{$ztype}=1 -DCONF_TRK=#{$CONFIG_TRACK}"
	necessarysettings +=  " --cpu 6510 --format cbm"
	optionalsettings = ""
	optionalsettings += " -DSPLASHWAIT=#{$splash_wait}" if $splash_wait
	optionalsettings += " -DTERPNO=#{$interpreter_number}" if $interpreter_number
	if $target
		optionalsettings += " -DTARGET_#{$target.upcase}=1"
	end
	
	generalflags = $GENERALFLAGS.empty? ? '' : " -D#{$GENERALFLAGS.join('=1 -D')}=1"
	debugflags = $DEBUGFLAGS.empty? ? '' : " -D#{$DEBUGFLAGS.join('=1 -D')}=1"
	colourflags = $colour_replacement_clause
	unless $default_colours.empty? # or $zcode_version >= 5
		colourflags += " -DBGCOL=#{$default_colours[0]} -DFGCOL=#{$default_colours[1]}"
	end
	if $border_colour
		colourflags += " -DBORDERCOL=#{$border_colour}"
	end
	if $statusline_colour
		colourflags += " -DSTATCOL=#{$statusline_colour}"
	end
	if $no_darkmode
		colourflags += " -DNODARKMODE=1"
	else
		unless $default_colours_dm.empty? # or $zcode_version >= 5
			colourflags += " -DBGCOLDM=#{$default_colours_dm[0]} -DFGCOLDM=#{$default_colours_dm[1]}"
		end
		if $border_colour_dm
			colourflags += " -DBORDERCOLDM=#{$border_colour_dm}"
		end
		if $statusline_colour_dm
			colourflags += " -DSTATCOLDM=#{$statusline_colour_dm}"
		end
		if $cursor_colour_dm
			colourflags += " -DCURSORCOLDM=#{$cursor_colour_dm}"
		end
	end
	if $cursor_colour
		colourflags += " -DCURSORCOL=#{$cursor_colour}"
	end
	if $cursor_shape
		cursor_shapes = {
			'b' => 224,     # block      $e0
			'u' => 100,     # underscore $e4 AND $7f
			'l' => 101      # line       $e5 AND $7f
		}
		colourflags += " -DCURSORCHAR=#{cursor_shapes[$cursor_shape]}"
	end
	if $cursor_blink
	    colourflags += " -DUSE_BLINKING_CURSOR=#{$cursor_blink}"
	end

	fontflag = $font_filename ? ' -DCUSTOM_FONT=1' : ''
    compressionflags = ''

    cmd = "#{$ACME}#{necessarysettings}#{optionalsettings}#{fontflag}#{colourflags}#{generalflags}" +
		"#{debugflags}#{compressionflags} -l \"#{$labels_file}\" --outfile \"#{$ozmoo_file}\" ozmoo.asm"
	puts cmd
	Dir.chdir $SRCDIR
    ret = system(cmd)
	Dir.chdir $EXECDIR
	unless ret
		puts "ERROR: There was a problem calling Acme"
		exit 1
	end
	$storystart = 0
	read_labels($labels_file);
	puts "Interpreter size: #{$program_end_address - $start_address} bytes."
end

def read_labels(label_file_name)
	File.open(label_file_name).each do |line|
		$storystart = $1.to_i(16) if line =~ /\tstory_start\t=\s*\$(\w{3,4})\b/;
		$program_end_address = $1.to_i(16) if line =~ /\tprogram_end\t=\s*\$(\w{3,4})\b/;
		$loader_pic_start = $1.to_i(16) if line =~ /\tloader_pic_start\t=\s*\$(\w{3,4})\b/;
	end
end

def build_loader_file()
	necessarysettings =  " --cpu 6510 --format cbm"
	optionalsettings = ""
	optionalsettings += " -DFLICKER=1" if $loader_flicker
	
    cmd = "#{$ACME}#{necessarysettings}#{optionalsettings}" +
		" -l \"#{$loader_labels_file}\" --outfile \"#{$loader_file}\" picloader.asm"
	puts cmd
	Dir.chdir $SRCDIR
    ret = system(cmd)
	Dir.chdir $EXECDIR
	unless ret
		puts "ERROR: There was a problem calling Acme"
		exit 1
	end
	read_labels($loader_labels_file);
	puts "Loader pic address: #{$loader_pic_start}"

	imagefile_clause = " \"#{$loader_pic_file}\"@#{$loader_pic_start},2,10001"
	exomizer_cmd = "#{$EXOMIZER} sfx basic -B \"#{$loader_file}\"#{imagefile_clause} -o \"#{$loader_zip_file}\""

	puts exomizer_cmd
	ret = system(exomizer_cmd)
	unless ret
		puts "ERROR: There was a problem calling Exomizer"
		exit 1
	end

	File.size($loader_zip_file)
end


def build_specific_boot_file(vmem_preload_blocks, vmem_contents)
	compmem_clause = " \"#{$compmem_filename}\"@#{$storystart},0,#{[($dynmem_blocks + vmem_preload_blocks) * $VMEM_BLOCKSIZE, 0x10000 - $storystart, File.size($compmem_filename)].min}"

	font_clause = ""
	if $font_filename then
		font_clause = " \"#{$font_filename}\"@2048"
	end
#	exomizer_cmd = "#{$EXOMIZER} sfx basic -B -X \'LDA $D012 STA $D020 STA $D418\' ozmoo #{$compmem_filename},#{$storystart} -o ozmoo_zip"
#	exomizer_cmd = "#{$EXOMIZER} sfx #{$start_address} -B -M256 -C -x1 #{font_clause} \"#{$ozmoo_file}\"#{compmem_clause} -o \"#{$zip_file}\""
	exomizer_cmd = "#{$EXOMIZER} sfx #{$start_address} -B -M256 -C #{font_clause} \"#{$ozmoo_file}\"#{compmem_clause} -o \"#{$zip_file}\""

	puts exomizer_cmd
	ret = system(exomizer_cmd)
	unless ret
		puts "ERROR: There was a problem calling Exomizer"
		exit 1
	end

#	puts "Building with #{vmem_preload_blocks} blocks gives file size #{File.size($zip_file)}."
	File.size($zip_file)
end

def save_good_boot_file()
	File.delete($good_zip_file) if File.exist?($good_zip_file)
	File.rename($zip_file, $good_zip_file)
end

def build_boot_file(vmem_preload_blocks, vmem_contents, free_blocks)
	begin
		compmem_filehandle = File.open($compmem_filename, "wb")
	rescue
		puts "ERROR: Can't open #{$compmem_filename} for writing"
		exit 1
	end
	compmem_filehandle.write(vmem_contents[0 .. ($dynmem_blocks + vmem_preload_blocks) * $VMEM_BLOCKSIZE - 1])
	compmem_filehandle.close

	max_file_size = free_blocks * 254
	puts "Max file size is #{max_file_size} bytes."
	if build_specific_boot_file(vmem_preload_blocks, vmem_contents) <= max_file_size then
		save_good_boot_file()
		return vmem_preload_blocks
	end
	puts "##### Built bootfile/interpreter with #{vmem_preload_blocks} virtual memory blocks preloaded: Too big #####\n\n"
	max_ok_blocks = -1 # If we never find a number of blocks which work, -1 will be returned to signal failure.  
	
	done = false
	min_failed_blocks = vmem_preload_blocks
	actual_blocks = -1
	last_build = -2
	until done
		if min_failed_blocks - max_ok_blocks < 2
			actual_blocks = max_ok_blocks
			done = true
		elsif min_failed_blocks < 1
			actual_blocks = max_ok_blocks
			done = true
		else
			mid = (min_failed_blocks + max_ok_blocks) / 2
#			puts "Trying #{mid} blocks..."
			size = build_specific_boot_file(mid, vmem_contents)
			last_build = mid
			if size > max_file_size then
				puts "##### Built bootfile/interpreter with #{mid} virtual memory blocks preloaded: Too big #####\n\n"
				min_failed_blocks = mid
			else
				save_good_boot_file()
				puts "##### Built bootfile/interpreter with #{mid} virtual memory blocks preloaded: OK      #####\n\n"
				max_ok_blocks = mid
#				max_ok_blocks = [mid + (1.25 * (max_file_size - size) / $VMEM_BLOCKSIZE).floor.to_i, min_failed_blocks - 1].min  
			end
		end
	end
#	build_specific_boot_file(actual_blocks, vmem_contents) unless last_build == actual_blocks
	puts "Picked #{actual_blocks} blocks." if max_ok_blocks >= 0
	actual_blocks
end

def add_loader_file(diskimage_filename)
	puts "#{$C1541} -attach \"#{diskimage_filename}\" -write \"#{$loader_zip_file}\" loader"
	system("#{$C1541} -attach \"#{diskimage_filename}\" -write \"#{$loader_zip_file}\" loader")
end

def add_boot_file(finaldiskname, diskimage_filename)
	ret = FileUtils.cp("#{diskimage_filename}", "#{finaldiskname}")
	puts "#{$C1541} -attach \"#{finaldiskname}\" -write \"#{$good_zip_file}\" story"
	system("#{$C1541} -attach \"#{finaldiskname}\" -write \"#{$good_zip_file}\" story")
end

def play(filename)
	command = "#{$X64} #{filename}"
	puts command
    system(command)
end

def limit_vmem_data(vmem_data)
#	puts "### #{$vmem_size} < #{(vmem_data[2] + $dynmem_blocks) * $VMEM_BLOCKSIZE} ###"
	if $vmem_size < (vmem_data[2] + $dynmem_blocks) * $VMEM_BLOCKSIZE
		vmem_data[2] = $vmem_size / $VMEM_BLOCKSIZE - $dynmem_blocks
	end
end

def build_P(storyname, diskimage_filename, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks, extended_tracks)
	max_story_blocks = 0
	
	boot_disk = false
	
	diskfilename = "#{storyname}.d64"
	
	if $vmem_size < $story_size
		puts "#{$vmem_size} < #{$story_size}"
		puts "ERROR: The whole story doesn't fit in memory. Please try another build mode."
		exit 1
	end
	
	disk = D64_image.new(disk_title: storyname, diskimage_filename: diskimage_filename, is_boot_disk: boot_disk, forty_tracks: extended_tracks)

	disk.add_story_data(max_story_blocks: max_story_blocks, add_at_end: extended_tracks) # Has to be run to finalize the disk

	disk.save()

	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}"

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}"
		if add_loader_file(diskimage_filename) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
	
	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(diskfilename, diskimage_filename) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end

	$bootdiskname = diskfilename
	puts "Successfully built game as #{$bootdiskname}"
	nil # Signal success
end

def build_S1(storyname, diskimage_filename, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks, extended_tracks)
	max_story_blocks = 9999
	
	boot_disk = true

	diskfilename = "#{storyname}.d64"

	disk = D64_image.new(disk_title: storyname, diskimage_filename: diskimage_filename, is_boot_disk: boot_disk, forty_tracks: extended_tracks)

	disk.add_story_data(max_story_blocks: max_story_blocks, add_at_end: extended_tracks)
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end
	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}"

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}"
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
#	puts "vmem_preload_blocks(#{vmem_preload_blocks} < $dynmem_blocks#{$dynmem_blocks}"
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[2] = vmem_preload_blocks

	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot / Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [DISKNAME_BOOT, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk.set_config_data(config_data)
	
	disk.save()
	
	# Add picture loader
	if $loader_pic_file
		if add_loader_file(diskimage_filename) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(diskfilename, diskimage_filename) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end

	$bootdiskname = "#{diskfilename}"
	puts "Successfully built game as #{$bootdiskname}"
	nil # Signal success
end

def build_S2(storyname, d64_filename_1, d64_filename_2, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks, extended_tracks)

	config_data[7] = 3 # 3 disks used in total
	outfile1name = "#{storyname}_boot.d64"
	outfile2name = "#{storyname}_story.d64"
	max_story_blocks = 9999
	disk1 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_1, is_boot_disk: true, forty_tracks: false)
	disk2 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_2, is_boot_disk: false, forty_tracks: extended_tracks)
	free_blocks = disk1.add_story_data(max_story_blocks: 0, add_at_end: false)
	free_blocks = disk2.add_story_data(max_story_blocks: max_story_blocks, add_at_end: false)
	puts "Free disk blocks after story data has been written: #{free_blocks}"
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}"
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, 664)
	vmem_data[2] = vmem_preload_blocks
	
	# Add config data about boot disk
	disk_info_size = 8
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot disk"
	config_data += [disk_info_size, 0, 0, 0, 0]
	config_data += [DISKNAME_BOOT, DISKNAME_DISK, 0]  # Name: "Boot disk"
	config_data[4] += disk_info_size
	
	# Add config data about story disk
	disk_info_size = 8 + disk2.config_track_map.length
	last_block_plus_1 = 0
	disk2.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk2.config_track_map.length] + disk2.config_track_map
	config_data += [DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Story disk"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk1.set_config_data(config_data)
	disk1.save()
	disk2.save()
	
	# Add picture loader
	if $loader_pic_file
		if add_loader_file(d64_filename_1) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(outfile1name, d64_filename_1) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end
	File.delete(outfile2name) if File.exist?(outfile2name)
	File.rename(d64_filename_2, "./#{outfile2name}")
	
	$bootdiskname = "#{outfile1name}"
	puts "Successfully built game as #{$bootdiskname} + #{outfile2name}"
	nil # Signal success
end

def build_D2(storyname, d64_filename_1, d64_filename_2, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks, extended_tracks)

	config_data[7] = 3 # 3 disks used in total
	outfile1name = "#{storyname}_boot_story_1.d64"
	outfile2name = "#{storyname}_story_2.d64"
	disk1 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_1, is_boot_disk: true, forty_tracks: extended_tracks)
	disk2 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_2, is_boot_disk: false, forty_tracks: extended_tracks)

	# Figure out how to put story blocks on the disks in optimal way.
	# Rule 1: Save 160 blocks for bootfile on boot disk, if possible. 
	# Rule 2: Spread story data as evenly as possible, so heads will move less.
	max_story_blocks = 9999
	total_raw_story_blocks = ($story_size - $story_file_cursor) / 256
	if disk1.free_blocks() - 160 >= total_raw_story_blocks / 2 and disk2.free_blocks >= disk1.free_blocks
		# Story data can be evenly spread over the two disks
		max_story_blocks = total_raw_story_blocks / 2
	elsif disk1.free_blocks() - 160 + disk2.free_blocks >= total_raw_story_blocks
		# There is room for a full-size bootfile on boot disk, if we spread the data unevenly over the two disks
		max_story_blocks = disk1.free_blocks() - 160
	else
		# Fill disk 2 with story data, put the rest on disk 1, and squeeze in the biggest bootfile that there is room for.
		disk2_free = disk2.free_blocks()
		disk2_free -= 1 if disk2_free % 2 > 0
		max_story_blocks = total_raw_story_blocks - disk2_free
	end
	
	free_blocks_1 = disk1.add_story_data(max_story_blocks: max_story_blocks, add_at_end: extended_tracks)
	puts "Free disk blocks on disk #1 after story data has been written: #{free_blocks_1}"
	free_blocks_2 = disk2.add_story_data(max_story_blocks: 9999, add_at_end: false)
	puts "Free disk blocks on disk #2 after story data has been written: #{free_blocks_2}"
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks_1 -= (loader_size / 254.0).ceil
		puts "Free disk blocks on disk #1 after loader has been written: #{free_blocks_1}"
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks_1)
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[2] = vmem_preload_blocks
	
	# Add config data about boot disk / story disk 1
	disk_info_size = 13 + disk1.config_track_map.length
#	last_block_plus_1 = $dynmem_blocks * $VMEM_BLOCKSIZE / 256
	last_block_plus_1 = 0
	disk1.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk1.config_track_map.length] + disk1.config_track_map
	config_data += [DISKNAME_BOOT, DISKNAME_DISK, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, "1".ord, 0]  # Name: "Boot disk / Story disk 1"
	config_data[4] += disk_info_size
	
	# Add config data about story disk 2
	disk_info_size = 9 + disk2.config_track_map.length
	disk2.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk2.config_track_map.length] + disk2.config_track_map
	config_data += [DISKNAME_STORY, DISKNAME_DISK, "2".ord, 0]  # Name: "Story disk 2"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk1.set_config_data(config_data)
	disk1.save()
	disk2.save()
	
	# Add picture loader
	if $loader_pic_file
		if add_loader_file(d64_filename_1) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(outfile1name, d64_filename_1) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end
	File.delete(outfile2name) if File.exist?(outfile2name)
	File.rename(d64_filename_2, "./#{outfile2name}")
	
	$bootdiskname = "#{outfile1name}"
	puts "Successfully built game as #{$bootdiskname} + #{outfile2name}"
	nil # Signal success
end

def build_D3(storyname, d64_filename_1, d64_filename_2, d64_filename_3, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks, extended_tracks)

	config_data[7] = 4 # 4 disks used in total
	outfile1name = "#{storyname}_boot.d64"
	outfile2name = "#{storyname}_story_1.d64"
	outfile3name = "#{storyname}_story_2.d64"
	disk1 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_1, is_boot_disk: true, forty_tracks: false)
	disk2 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_2, is_boot_disk: false, forty_tracks: extended_tracks)
	disk3 = D64_image.new(disk_title: storyname, diskimage_filename: d64_filename_3, is_boot_disk: false, forty_tracks: extended_tracks)

	# Figure out how to put story blocks on the disks in optimal way.
	# Rule: Spread story data as evenly as possible, so heads will move less.
	total_raw_story_blocks = ($story_size - $story_file_cursor) / 256
	max_story_blocks = total_raw_story_blocks / 2
	
	free_blocks_1 = disk1.add_story_data(max_story_blocks: 0, add_at_end: false)
	puts "Free disk blocks on disk #1 after story data has been written: #{free_blocks_1}"
	free_blocks_2 = disk2.add_story_data(max_story_blocks: max_story_blocks, add_at_end: false)
	puts "Free disk blocks on disk #2 after story data has been written: #{free_blocks_2}"
	free_blocks_3 = disk3.add_story_data(max_story_blocks: 9999, add_at_end: false)
	puts "Free disk blocks on disk #3 after story data has been written: #{free_blocks_3}"
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks_1 -= (loader_size / 254.0).ceil
		puts "Free disk blocks on disk #1 after loader has been written: #{free_blocks_1}"
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, 664)
	vmem_data[2] = vmem_preload_blocks
	
	# Add config data about boot disk
	disk_info_size = 8
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot disk"
	config_data += [disk_info_size, 0, 0, 0, 0]
	config_data += [DISKNAME_BOOT, DISKNAME_DISK, 0]  # Name: "Boot disk"
	config_data[4] += disk_info_size

	last_block_plus_1 = 0
	
	# Add config data about story disk 1
	disk_info_size = 9 + disk2.config_track_map.length
	disk2.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk2.config_track_map.length] + disk2.config_track_map
	config_data += [DISKNAME_STORY, DISKNAME_DISK, "1".ord, 0]  # Name: "Story disk 1"
	config_data[4] += disk_info_size

	# Add config data about story disk 2
	disk_info_size = 9 + disk3.config_track_map.length
	disk3.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk3.config_track_map.length] + disk3.config_track_map
	config_data += [DISKNAME_STORY, DISKNAME_DISK, "2".ord, 0]  # Name: "Story disk 2"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk1.set_config_data(config_data)
	disk1.save()
	disk2.save()
	disk3.save()
	
	# Add picture loader
	if $loader_pic_file
		if add_loader_file(d64_filename_1) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(outfile1name, d64_filename_1) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end
	File.delete(outfile2name) if File.exist?(outfile2name)
	File.rename(d64_filename_2, "./#{outfile2name}")
	File.delete(outfile3name) if File.exist?(outfile3name)
	File.rename(d64_filename_3, "./#{outfile3name}")
	
	$bootdiskname = "#{outfile1name}"
	puts "Successfully built game as #{$bootdiskname} + #{outfile2name} + #{outfile3name}"
	nil # Signal success
end

def build_81(storyname, diskimage_filename, config_data, vmem_data, vmem_contents, preload_max_vmem_blocks)

	diskfilename = "#{storyname}.d81"
	
	disk = D81_image.new(disk_title: storyname, diskimage_filename: diskimage_filename)

	disk.add_story_data(max_story_blocks: 9999, add_at_end: false)
	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}"

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}"
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
#	puts "vmem_preload_blocks(#{vmem_preload_blocks} < $dynmem_blocks#{$dynmem_blocks}"
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[2] = vmem_preload_blocks

	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot / Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [DISKNAME_BOOT, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk.set_config_data(config_data)
	
	if disk.create_story_partition() == false
		puts "ERROR: Could not create partition to protect data on disk."
		exit 1
	end
	
	disk.save()

	# Add picture loader
	if $loader_pic_file
		if add_loader_file(diskimage_filename) != true
			puts "ERROR: Failed to write loader to disk."
			exit 1
		end
	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(diskfilename, diskimage_filename) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end

	$bootdiskname = "#{storyname}.d81"
	puts "Successfully built game as #{$bootdiskname}"
	nil # Signal success
end

def print_usage_and_exit
	puts "Usage: make.rb [-t:target] [-S1|-S2|-D2|-D3|-81|-P]"
	puts "         [-p:[n]] [-c <preloadfile>] [-o] [-sp:[n]]"
	puts "         [-s] [-r] [-f <fontfile>] [-cm:[xx]] [-in:[n]]"
	puts "         [-i <imagefile>] [-if <imagefile>]"
	puts "         [-rc:[n]=[c],[n]=[c]...] [-dc:[n]:[n]] [-bc:[n]] [-sc:[n]]"
	puts "         [-dmdc:[n]:[n]] [-dmbc:[n]] [-dmsc:[n]] [-ss[1-4]:\"text\"]"
	puts "         [-sw:[nnn]] [-cb:[n]] [-cc:[n]] [-dmcc:[n]] [-cs:[b|u|l]] "
	puts "         <storyfile>"
	puts "  -t: specify target machine. Available targets are c64 (default)."
	puts "  -S1|-S2|-D2|-D3|-81|-P: specify build mode. Defaults to S1. See docs for details."
	puts "  -p: preload a a maximum of n virtual memory blocks to make game faster at start"
	puts "  -c: read preload config from preloadfile, previously created with -o"
	puts "  -o: build interpreter in PREOPT (preload optimization) mode. See docs for details."
	puts "  -sp: Use the specified number of pages for stack (2-9, default is 4)."
	puts "  -s: start game in Vice if build succeeds"
	puts "  -r: Use reduced amount of RAM (-$CFFF). Only with -P."
	puts "  -f: Embed the specified font with the game. See docs for details."
	puts "  -cm: Use the specified character map (sv, da, de, it, es or fr)"
	puts "  -in: Set the interpreter number (0-19). Default is 2 for Beyond Zork, 8 for other games."
	puts "  -i: Add a loader using the specified Koala Painter multicolour image (filesize: 10003 bytes)."
	puts "  -if: Like -i but add a flicker effect in the border while loading."
	puts "  -rc: Replace the specified Z-code colours with the specified C64 colours. See docs for details."
	puts "  -dc/dmdc: Use the specified background and foreground colours. See docs for details."
	puts "  -bc/dmbc: Use the specified border colour. 0=same as bg, 1=same as fg. See docs for details."
	puts "  -sc/dmsc: Use the specified status line colour. Only valid for Z3 games. See docs for details."
	puts "  -ss1, -ss2, -ss3, -ss4: Add up to four lines of text to the splash screen."
	puts "  -sw: Set the splash screen wait time (0-999 s). Default is 10 if text has been added, 3 if not."
	puts "  -cb: Set cursor blink frequency (0-9, where 9 is fastest)."
	puts "  -cc/dmcc: Use the specified cursor colour.  Defaults to foreground colour."
	puts "  -cs: Use the specified cursor shape.  ([b]lock (default), [u]nderscore or [l]ine)"
	puts "  storyfile: path optional (e.g. infocom/zork1.z3)"
	exit 1
end

splashes = [
"", "", "", ""
]
$interpreter_number = nil
i = 0
reduced_ram = false
await_preloadfile = false
await_fontfile = false
await_imagefile = false
preloadfile = nil
$font_filename = nil
$loader_pic_file = nil
$loader_flicker = false
auto_play = false
optimize = false
extended_tracks = false
preload_max_vmem_blocks = 2**16 / $VMEM_BLOCKSIZE
limit_preload_vmem_blocks = false
$start_address = 0x0801
$program_end_address = 0x10000
$colour_replacements = []
$default_colours = []
$default_colours_dm = []
$statusline_colour = nil
$statusline_colour_dm = nil
$target = nil
$border_colour = nil
$border_colour_dm = nil
$stack_pages = 4 # Should normally be 2-6. Use 4 unless you have a good reason not to.
$border_colour = 0
$char_map = nil
$splash_wait = nil
$cursor_colour = nil
$cursor_shape = nil
$cursor_blink = nil

begin
	while i < ARGV.length
		if await_preloadfile then
			await_preloadfile = false
			preloadfile = ARGV[i]
		elsif await_fontfile then
			await_fontfile = false
			$font_filename = ARGV[i]
		elsif await_imagefile then
			await_imagefile = false
			$loader_pic_file = ARGV[i]
#		elsif ARGV[i] =~ /^-x$/ then
#			extended_tracks = true
		elsif ARGV[i] =~ /^-o$/ then
			optimize = true
		elsif ARGV[i] =~ /^-in:(1?\d)$/ then
			$interpreter_number = $1
		elsif ARGV[i] =~ /^-s$/ then
			auto_play = true
		elsif ARGV[i] =~ /^-r$/ then
			reduced_ram = true
		elsif ARGV[i] =~ /^-p:(\d+)$/ then
			preload_max_vmem_blocks = $1.to_i
			limit_preload_vmem_blocks = true
		elsif ARGV[i] =~ /^-P$/ then
			mode = MODE_P
		elsif ARGV[i] =~ /^-t:(c64|mega65)$/ then
			$target = $1
		elsif ARGV[i] =~ /^-S1$/ then
			mode = MODE_S1
		elsif ARGV[i] =~ /^-S2$/ then
			mode = MODE_S2
		elsif ARGV[i] =~ /^-D2$/ then
			mode = MODE_D2
		elsif ARGV[i] =~ /^-D3$/ then
			mode = MODE_D3
		elsif ARGV[i] =~ /^-81$/ then
			mode = MODE_81
		elsif ARGV[i] =~ /^-rc:((?:\d\d?=\d\d?)(?:,\d=\d\d?)*)$/ then
			$colour_replacements = $1.split(/,/)
		elsif ARGV[i] =~ /^-dc:([2-9]):([2-9])$/ then
			$default_colours = [$1.to_i,$2.to_i]
		elsif ARGV[i] =~ /^-dmdc:([2-9]):([2-9])$/ then
			$default_colours_dm = [$1.to_i,$2.to_i]
		elsif ARGV[i] =~ /^-bc:([0-9])$/ then
			$border_colour = $1.to_i
		elsif ARGV[i] =~ /^-dmbc:([0-9])$/ then
			$border_colour_dm = $1.to_i
		elsif ARGV[i] =~ /^-sc:([2-9])$/ then
			$statusline_colour = $1.to_i
		elsif ARGV[i] =~ /^-dmsc:([2-9])$/ then
			$statusline_colour_dm = $1.to_i
		elsif ARGV[i] =~ /^-sp:([2-9])$/ then
			$stack_pages = $1.to_i
		elsif ARGV[i] =~ /^-cm:(sv|da|de|it|es|fr)$/ then
			$char_map = $1
		elsif ARGV[i] =~ /^-c$/ then
			await_preloadfile = true
		elsif ARGV[i] =~ /^-f$/ then
			await_fontfile = true
			$start_address = 0x1000
		elsif ARGV[i] =~ /^-if?$/ then
			await_imagefile = true
			$loader_flicker = ARGV[i] =~ /f$/
		elsif ARGV[i] =~ /^-ss([1-4]):(.*)$/ then
			splashes[$1.to_i - 1] = $2 
		elsif ARGV[i] =~ /^-sw:(\d{1,3})$/ then
			$splash_wait = $1
		elsif ARGV[i] =~ /^-cc:([0-9])$/ then
			$cursor_colour = $1.to_i
		elsif ARGV[i] =~ /^-dmcc:([0-9])$/ then
			$cursor_colour_dm = $1.to_i
		elsif ARGV[i] =~ /^-cs:([b|u|l])$/ then
			$cursor_shape = $1
		elsif ARGV[i] =~ /^-cb:([0-9])$/ then
			$cursor_blink = $1
		elsif ARGV[i] =~ /^-/i then
			puts "Unknown option: " + ARGV[i]
			raise "error"
		else 
			$story_file = ARGV[i]
		end
		i = i + 1
	end
	if !$story_file
		print_usage_and_exit()
	end
rescue
	print_usage_and_exit()
end

$VMEM = (mode != MODE_P)

$GENERALFLAGS.push('DANISH_CHARS') if $char_map == 'da'
$GENERALFLAGS.push('SWEDISH_CHARS') if $char_map == 'sv'
$GENERALFLAGS.push('GERMAN_CHARS') if $char_map == 'de'
$GENERALFLAGS.push('ITALIAN_CHARS') if $char_map == 'it'
$GENERALFLAGS.push('SPANISH_CHARS') if $char_map == 'es'
$GENERALFLAGS.push('FRENCH_CHARS') if $char_map == 'fr'

$GENERALFLAGS.push('VMEM') if $VMEM

$GENERALFLAGS.push('ALLRAM') unless reduced_ram

$ALLRAM = $GENERALFLAGS.include?('ALLRAM')

$colour_replacement_clause = ''
unless $colour_replacements.empty?
	$colour_replacements.each do |r|
		r =~ /^(\d\d?)=(\d\d?)$/
		zcode_colour = $1
		c64_colour = $2
		if zcode_colour !~ /^[2-9]$/
			puts "-rc requires a Z-code colour value (2-9) to the left of the = character."
			exit 1
		end
		if c64_colour !~ /^([0-9]|1[0-5])$/
			puts "-rc requires a C64 colour value (0-15) to the right of the = character."
			exit 1
		end
		$colour_replacement_clause += " -DCOL#{zcode_colour}=#{c64_colour}" unless $colour_replacement_clause.include? "-DCOL#{zcode_colour}=" 
	end
end

if reduced_ram and mode != MODE_P
	puts "Option -r can't be used with this build mode."
	exit 1
end

if $stack_pages < 4 and mode != MODE_P
	puts "Stack pages < 4 is only allowed in build mode P."
	exit 1
end

if optimize and mode == MODE_P
	puts "Option -o can't be used with this build mode."
	exit 1
end

if limit_preload_vmem_blocks and !$VMEM
	puts "Option -p can't be used with this build mode."
	exit 1
end

if extended_tracks and !$VMEM
	puts "Option -x can't be used with this build mode."
	exit 1
end

if optimize then
	if preloadfile then
		puts "-c (preload story data) can not be used with -o."
		exit 1
	end
	$DEBUGFLAGS.push('PREOPT')
end

$DEBUGFLAGS.push('DEBUG') unless $DEBUGFLAGS.empty? or $DEBUGFLAGS.include?('DEBUG')


print_usage_and_exit() if await_preloadfile

# Check for file specifying which blocks to preload
preload_data = nil
if preloadfile then
	preload_raw_data = File.read(preloadfile)
	vmem_type = "clock"
	if preload_raw_data =~ /\$\$\$#{vmem_type}\n(([0-9a-f]{4}:\n?)+)\n?\$\$\$/i
		preload_data = $1.gsub(/\n/, '').gsub(/:$/,'').split(':')
		puts "#{preload_data.length} blocks found for initial caching."
	else
		puts "No preload config data found (for vmem type \"#{vmem_type}\")."
		exit 1
	end
end

# divide $story_file into path, filename, extension (if possible)
path = File.dirname($story_file)
extension = File.extname($story_file)
filename = File.basename($story_file)
storyname = File.basename($story_file, extension)
#puts "storyname: #{storyname}" 

begin
	puts "Reading file #{$story_file}..."
	$story_file_data = IO.binread($story_file)
rescue
	puts "ERROR: Can't open #{$story_file} for reading"
	exit 1
end

$zcode_version = $story_file_data[0].ord
$ztype = "Z#{$zcode_version}"

$zmachine_memory_size = $story_file_data[0x1a .. 0x1b].unpack("n")[0]
if $zcode_version == 3
	$zmachine_memory_size *= 2
elsif $zcode_version == 8
	$zmachine_memory_size *= 8
else
	$zmachine_memory_size *= 4
end

# unless $story_file_data.length == $zmachine_memory_size
	# $story_file_data.slice!($zmachine_memory_size)
# end


unless $story_file_data.length % $VMEM_BLOCKSIZE == 0
	$story_file_data += $ZEROBYTE * ($VMEM_BLOCKSIZE - ($story_file_data.length % $VMEM_BLOCKSIZE))
end


$vmem_highbyte_mask = ($zcode_version == 3) ? 0x01 : (($zcode_version == 8) ? 0x07 : 0x03)

if $statusline_colour and $zcode_version > 3
	puts "Option -sc can only be used with z3 story files."
	exit 1
end	

# check header.high_mem_start (size of dynmem + statmem)
high_mem_start = $story_file_data[4 .. 5].unpack("n")[0]

# check header.static_mem_start (size of dynmem)
$static_mem_start = $story_file_data[14 .. 15].unpack("n")[0]

# check header.release and serial to find out if beyondzork or not
release = $story_file_data[2 .. 3].unpack("n")[0]
serial = $story_file_data[18 .. 23]
storyfile_key = "r%d-s%d" % [ release, serial ]
is_beyondzork = $zcode_version == 5 && $beyondzork_releases.has_key?(storyfile_key)

$no_darkmode = nil
if is_beyondzork
	$interpreter_number = 2 unless $interpreter_number
	$no_darkmode = true
	patch_data_string = $beyondzork_releases[storyfile_key]
	patch_data_arr = patch_data_string.split(/ /)
	patch_address = patch_data_arr.shift.to_i(16)
	patch_check = patch_data_arr.shift.to_i(16)
	# Change all hex strings to 8-bit unsigned ints instead, due to bug in Ruby's array.pack("H")
	patch_data_arr.length.times do |i|
		patch_data_arr[i] = patch_data_arr[i].to_i(16)
	end
	if $story_file_data[patch_address .. (patch_address + 1)].unpack("n")[0] == patch_check
		$story_file_data[patch_address .. (patch_address + patch_data_arr.length - 1)] =
			patch_data_arr.pack("C*")
		puts "Successfully patched Beyond Zork story file."
	else
		puts "### WARNING: Story file matches serial + version# for Beyond Zork, but contents differ. Failed to patch."
	end
end

# get dynmem size (in vmem blocks)
$dynmem_blocks = ($static_mem_start.to_f / $VMEM_BLOCKSIZE).ceil
puts "Dynmem blocks: #{$dynmem_blocks}"
# if $VMEM and preload_max_vmem_blocks and preload_max_vmem_blocks < $dynmem_blocks then
	# puts "Max preload blocks adjusted to dynmem size, from #{preload_max_vmem_blocks} to #{$dynmem_blocks}."
	# preload_max_vmem_blocks = $dynmem_blocks
# end

$story_file_cursor = $dynmem_blocks * $VMEM_BLOCKSIZE

$story_size = $story_file_data.length


 
puts "$zmachine_memory_size = #{$zmachine_memory_size}"
puts "$story_size = #{$story_size}"


save_slots = [255, 664 / (($static_mem_start.to_f + 256 * $stack_pages + 20) / 254).ceil.to_i].min
#puts "Static mem start: #{$static_mem_start}"
#puts "Save blocks: #{(($static_mem_start.to_f + 256 * $stack_pages + 20) / 254).ceil.to_i}"
#puts "Save slots: #{save_slots}"

config_data = 
[$BUILD_ID].pack("I>").unpack("CCCC") + 
[
# 0, 0, 0, 0, # Game ID
12, # Number of bytes used for disk information, including this byte
1, #Interleave value (can be changed later)
save_slots, # Save slots, change later if wrong
2, # Number of disks, change later if wrong
# Data for save disk: 8 bytes used, device# = 0 (auto), Last story data sector + 1 = 0 (word), tracks used for story data, name = "Save disk"
8, 0, 0, 0, 0, DISKNAME_SAVE, DISKNAME_DISK, 0 
]

# Create config data for vmem
if preload_data then
	vmem_data = [
		3 + 2 * preload_data.length, # Size of vmem data
		preload_data.length, # Number of suggested blocks
		preload_data.length, # Number of preloaded blocks (May change later due to lack of space on disk)
		]
	lowbytes = []
	preload_data.each do |block|
		vmem_data.push(block[0 .. 1].to_i(16))
		lowbytes.push(block[2 .. 3].to_i(16))
	end
	vmem_data += lowbytes;
	if preload_max_vmem_blocks and preload_max_vmem_blocks > preload_data.length then
		puts "Max preload blocks adjusted to suggested preload blocks, from #{preload_max_vmem_blocks} to #{preload_data.length}."
		preload_max_vmem_blocks = preload_data.length
	end
else # No preload data available
#	$dynmem_blocks = $dynmem_size / $VMEM_BLOCKSIZE
	referenced_blocks = -1
	total_vmem_blocks = $story_size / $VMEM_BLOCKSIZE
	mapped_vmem_blocks = 0 #all_vmem_blocks - $dynmem_blocks
	if $DEBUGFLAGS.include?('PREOPT') then
#		all_vmem_blocks = $dynmem_blocks
		mapped_vmem_blocks = 0
	else
#		all_vmem_blocks = [51 * 1024 / $VMEM_BLOCKSIZE, total_vmem_blocks].min()
		if mode == MODE_P 
			mapped_vmem_blocks = total_vmem_blocks - $dynmem_blocks
		else
			mapped_vmem_blocks = [51 * 1024 / $VMEM_BLOCKSIZE - $dynmem_blocks, total_vmem_blocks - $dynmem_blocks].min()
		end
		referenced_blocks = mapped_vmem_blocks / 2 # Mark the first half of the non-dynmem blocks as referenced 
	end
	vmem_data = [
		3 + 2 * mapped_vmem_blocks, # Size of vmem data
		mapped_vmem_blocks, # Number of suggested blocks
		mapped_vmem_blocks, # Number of preloaded blocks (May change later due to lack of space on disk)
		]
	lowbytes = []
	mapped_vmem_blocks.times do |i|
#		vmem_data.push(i <= referenced_blocks ? 0x20 : 0x00)
		vmem_data.push(256 - 8 * (i / 4) - 32 ) # The later the block, the higher its age
#		0-25 -> 0-200 -> 32-232
		lowbytes.push(($dynmem_blocks + i) * $VMEM_BLOCKSIZE / 256)
	end
	vmem_data += lowbytes;
end

vmem_contents = $story_file_data[0 .. $dynmem_blocks * $VMEM_BLOCKSIZE - 1]
vmem_data[1].times do |i|
	start_address = (vmem_data[3 + i] & $vmem_highbyte_mask) * 256 * 256 + vmem_data[3 + vmem_data[1] + i] * 256
	# puts start_address
	# puts $story_file_data.length
	vmem_contents += $story_file_data[start_address .. start_address + $VMEM_BLOCKSIZE - 1]
end



# Splashscreen

# splashes = [
# "", "", "", ""
# ]
# splashes[0] = filename_to_title(storyname, 40)
splash = File.read(File.join($SRCDIR, 'splashlines.tpl'))
version = File.read(File.join(__dir__, 'version.txt'))
version.gsub!(/[^\d\.]/m,'')
splash.sub!("@vs@", version)
splash.sub!(/"(.*)\(F1 = darkmode\)/,'"          \1') if $no_darkmode
4.times do |i|
	text = splashes[i]
	indent = 0
	if text.length > 0
		$splash_wait = 10 unless $splash_wait
		text.gsub!(/(\n|\t)+/, ' ')
		if text.length > 40
			puts "Splashline #{i + 1} is longer than 40 characters."
			exit 1
		end
		indent = (40 - text.length) / 2
		text.gsub!(/"/, '",34,"')
	end
	splash.sub!("@#{i}s@", text)
	splash.sub!("@#{i}c@", indent.to_s)
end
File.write(File.join($SRCDIR, 'splashlines.asm'), splash)

build_interpreter()

$vmem_size = ($ALLRAM ? 0x10000 : 0xd000) - $storystart

if $storystart + $dynmem_blocks * $VMEM_BLOCKSIZE > 0xd000 then
	puts "ERROR: Dynamic memory is too big (#{$dynmem_blocks * $VMEM_BLOCKSIZE} bytes), would pass $D000. Maximum dynmem size is #{0xd000 - $storystart} bytes." 
	exit 1
end

limit_vmem_data(vmem_data)

if $VMEM and preload_max_vmem_blocks and preload_max_vmem_blocks > vmem_data[2] then
	puts "Max preload blocks adjusted to total vmem size, from #{preload_max_vmem_blocks} to #{vmem_data[2]}."
	preload_max_vmem_blocks = vmem_data[2]
end

if $VMEM 
	if mode == MODE_P
		puts "ERROR: Tried to use build mode -P with VMEM."
		exit 1
	end
elsif mode != MODE_P
	puts "ERROR: Tried to use build mode other than -P with VMEM disabled."
	exit 1
end

case mode
when MODE_P
	diskimage_filename = File.join($TEMPDIR, "temp1.d64")
	error = build_P(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_S1
	diskimage_filename = File.join($TEMPDIR, "temp1.d64")
	error = build_S1(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_S2
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	error = build_S2(storyname, d64_filename_1, d64_filename_2, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_D2
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	error = build_D2(storyname, d64_filename_1, d64_filename_2, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_D3
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	d64_filename_3 = File.join($TEMPDIR, "temp3.d64")
	error = build_D3(storyname, d64_filename_1, d64_filename_2, d64_filename_3, 
		config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_81
	diskimage_filename = File.join($TEMPDIR, "temp1.d81")
	error = build_81(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks)
else
	puts "Unsupported build mode."
	exit 1
end

if !error and auto_play then 
	play("#{$bootdiskname}")
end


exit 0


