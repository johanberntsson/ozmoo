# specialised make for Ozmoo

require 'fileutils'

$is_windows = (ENV['OS'] == 'Windows_NT')

if $is_windows then
	# Paths on Windows
    $X64 = "C:\\ProgramsWoInstall\\GTK3VICE-3.7.1-win64\\bin\\x64sc.exe -autostart-warp" # -autostart-delay-random"
    $X128 = "C:\\ProgramsWoInstall\\GTK3VICE-3.7.1-win64\\bin\\x128.exe -80 -autostart-delay-random"
    $XPLUS4 = "C:\\ProgramsWoInstall\\GTK3VICE-3.7.1-win64\\bin\\xplus4.exe -autostart-delay-random"
	$MEGA65 = "\"C:\\Program Files\\xemu\\xmega65.exe\" -syscon" # -syscon is a workaround for a serious xemu bug
    $C1541 = "C:\\ProgramsWoInstall\\GTK3VICE-3.7.1-win64\\bin\\c1541.exe"
    $EXOMIZER = "C:\\ProgramsWoInstall\\Exomizer-3.1.0\\win32\\exomizer.exe"
    $ACME = "C:\\ProgramsWoInstall\\acme0.97win\\acme\\acme.exe"
	$commandline_quotemark = "\""
else
	# Paths on Linux
    $X64 = "x64 -autostart-delay-random"
    $X128 = "x128 -autostart-delay-random"
    #$X128 = "x128 -80col -autostart-delay-random"
    $XPLUS4 = "xplus4 -autostart-delay-random"
    $MEGA65 = "xemu-xmega65 -besure"
    $C1541 = "c1541"
    $EXOMIZER = "exomizer/src/exomizer"
    $ACME = "acme"
	$commandline_quotemark = "'"
end

$PRINT_DISK_MAP = false # Set to true to print which blocks are allocated

# Typically none should be enabled.
$GENERALFLAGS = [
#	'CHECK_ERRORS' # Check for all runtime errors, making code bigger and slower
#	'SLOW', # Remove some optimizations for speed. This makes the terp ~100 bytes smaller.
#	'NODARKMODE', # Disables darkmode support. This makes the terp ~100 bytes smaller.
#	'NOSCROLLBACK', # Disables scrollback support (MEGA65, C64, C128). This makes the terp ~1 KB smaller.
#	'REUBOOST', # Enables REU Boost (MEGA65, C64, C128). This makes the terp ~160 bytes larger.
#	'VICE_TRACE', # Send the last instructions executed to Vice, to aid in debugging
#	'TRACE', # Save a trace of the last instructions executed, to aid in debugging
#	'COUNT_SWAPS', # Keep track of how many vmem block reads have been done.
#   'TIMING', # Store the lowest word of the jiffy clock in 0-->2 in the Z-code header
#	'UNDO', # Support UNDO (using REU)
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
#	'TRACE_HISTORY',
]

$CACHE_PAGES = 4 # Should normally be 2-8. Use 4 unless you have a good reason not to. One page will be added automatically if it would otherwise be wasted due to vmem alignment issues.

$CONFIG_TRACK = 1

MODE_P = 1
MODE_S1 = 2
MODE_S2 = 3
MODE_D2 = 4
MODE_D3 = 5
MODE_71 = 6
MODE_81 = 7

DISKNAME_BOOT = 128
DISKNAME_STORY = 129
DISKNAME_SAVE = 130
DISKNAME_DISK = 131

$BUILD_ID = Random.rand(0 .. 2**32-1)

$VMEM_BLOCKSIZE = 512

$ZEROBYTE = 0.chr

$EXECDIR = Dir.pwd
$SRCDIR = File.join(__dir__, 'asm')
$TEMPDIR = File.join(__dir__, 'temp')
Dir.mkdir($TEMPDIR) unless Dir.exist?($TEMPDIR)

$wrapper_labels_file = File.join($TEMPDIR, 'wrapper_labels.txt')
$wrapper_file = File.join($TEMPDIR, 'wrapper')
$labels_file = File.join($TEMPDIR, 'acme_labels.txt')
$loader_labels_file = File.join($TEMPDIR, 'acme_labels_loader.txt')
# $loader_pic_file = File.join($EXECDIR, 'loaderpic.kla')
$loader_file = File.join($TEMPDIR, 'loader')
$loader_zip_file = File.join($TEMPDIR, 'loader_zip')
$ozmoo_file = File.join($TEMPDIR, 'ozmoo')
$zip_file = File.join($TEMPDIR, 'ozmoo_zip')
$good_zip_file = File.join($TEMPDIR, 'ozmoo_zip_good')
$compmem_filename = File.join($TEMPDIR, 'compmem.tmp')
$universal_file = File.join($TEMPDIR, 'universal')
$config_filename = File.join($TEMPDIR, 'config.tmp')

$trinity_releases = {
	"r11-s860509" => "fddd 2058 01",
	"r12-s860926" => "fddd 2048 01",
	"r15-s870628" => "fd8d 2048 01"
}

$lurkinghorror_releases = {
	"r203-s870506" => "",
	"r219-s870912" => "",
	"r221-s870918" => ""
}

$beyondzork_releases = {
    "r47-s870915" => "f347 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r49-s870917" => "f2c0 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r51-s870923" => "f2a8 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r57-s871221" => "f384 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1",
    "r60-s880610" => "f2dc 14c2 00 a6 0b 64 23 57 62 97 80 84 a0 02 ca b2 13 44 d4 a5 8c 00 09 b2 11 24 50 9c 92 65 e5 7f 5d b1 b1 b1 b1 b1 b1 b1 b1 b1 b1 b1"
}

$d81interleave = [
	# 0:No interleave
	{},
	# 1: 0,1,  4,5,  8,9,  12,13, ...
	{	1 => 4, 5 => 8, 9 => 12, 13 => 16, 17 => 20, 21 => 24, 25 => 28, 29 => 32, 33 => 36, 37 => 0, 
		3 => 6, 7 => 10, 11 => 14, 15 => 18, 19 => 22, 23 => 26, 27 => 30, 31 => 34, 35 => 38, 39 => 2
	},
	# 2: 0, 4, 8, 12, ...
	{	0 => 4, 4 => 8, 8 => 12, 12 => 16, 16 => 20, 20 => 24, 24 => 28, 28 => 32, 32 => 36, 36 => 1,
		1 => 5, 5 => 9, 9 => 13, 13 => 17, 17 => 21, 21 => 25, 25 => 29, 29 => 33, 33 => 37, 37 => 2,
		2 => 6, 6 => 10, 10 => 14, 14 => 18, 18 => 22, 22 => 26, 26 => 30, 30 => 34, 34 => 38, 38 => 3,
		3 => 7, 7 => 11, 11 => 15, 15 => 19, 19 => 23, 23 => 27, 27 => 31, 31 => 35, 35 => 39
	},
]

$i81 = $d81interleave[1] # Optimal scheme for MEGA65, as far as we can tell. File copying is not done in make.rb for other platforms.

class Disk_image
	def base_initialize
		@reserve_dir_track = nil
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
		puts "Free disk blocks at start: #{@free_blocks}" if $verbose
	end
	
	def free_blocks
		@free_blocks
	end

	def interleave
		@interleave
	end

	attr_accessor :interleave_scheme
	
	# def interleave_scheme
		# @interleave_scheme
	# end
	
	# def interleave_scheme = (interleave_scheme)
		# @interleave_scheme = interleave_scheme
	# end
	
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

				if reserved_sectors == sector_count
					@config_track_map.push 0
				elsif reserved_sectors % 2 == 0 and reserved_sectors <= 6
					@config_track_map.push(64 * reserved_sectors / 2 + last_story_sector)
				else
					puts "Incorrect number of reserved sectors on track #{track}: #{reserved_sectors}"
					exit 1
				end
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
	def initialize(disk_title:, diskimage_filename:, is_boot_disk:, forty_tracks: nil, reserve_dir_track: nil)
		puts "Creating disk image..." if $verbose

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
		@reserved_sectors[18] = reserve_dir_track ? @track_length[18] : 2 # 2: Skip BAM and 1 directory block, 19: Skip entire track
		@reserved_sectors[@config_track] = 2 if @is_boot_disk and @config_track

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
		
		if @is_boot_disk  and @config_track then
			allocate_sector(@config_track, 0)
			allocate_sector(@config_track, 1)
		end

		@free_blocks
	end # initialize


	private
	
	def allocate_sector(track, sector)
		print " #{sector}" if $PRINT_DISK_MAP
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

class D71_image < Disk_image
	def initialize(disk_title:, diskimage_filename:, is_boot_disk:, reserve_dir_track: nil)
		puts "Creating disk image..." if $verbose

		@disk_title = disk_title
		@diskimage_filename = diskimage_filename
		@is_boot_disk = is_boot_disk

		@tracks = 70
		@track_length = Array.new(@tracks + 1) {|track| 
			track == 0 ? 0 :
			track < 18 ? 21 : 
			track < 25 ? 19 : 
			track < 31 ? 18 :
			track < 36 ? 17 :
			track < 53 ? 21 :
			track < 60 ? 19 :
			track < 66 ? 18 :
			17
		}
#		puts "Tracks: #{@track_length.to_s}"

		base_initialize()

		@interleave = 5

		# NOTE: Blocks to skip can only be 0, 2, 4 or 6, or entire track.
		@reserved_sectors[18] = reserve_dir_track ? @track_length[18] : 2 # 2: Skip BAM and 1 directory block, 19: Skip entire track
		@reserved_sectors[53] = reserve_dir_track ? @track_length[53] : 2 # 2: Skip BAM and 1 extra block (we can't skip just 1 block)
		@reserved_sectors[@config_track] = 2 if @is_boot_disk and @config_track

		calculate_initial_free_blocks()
			
		# BAM
		@track1800 = [
			# $16500 = 91392 = 357 (18,0)
			0x12,0x01, # track/sector
			0x41, # DOS version
			0x80, # $80 = Double-sided
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
			0x11,0xff,0xff,0x01, # track 32
			0x11,0xff,0xff,0x01, # track 33
			0x11,0xff,0xff,0x01, # track 34
			0x11,0xff,0xff,0x01, # track 35
			0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0, # label (game name)
			0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,
			0xa0,0xa0,0x30,0x30,0xa0,0x32,0x41,0xa0,
			0xa0,0xa0,0xa0,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00, # -$dc
			0x15,0x15,0x15, # $dd- (free sector count for track 36-70)
			0x15,0x15,0x15,0x15,0x15,0x15,0x15,0x15,
			0x15,0x15,0x15,0x15,0x15,0x15,0x11,0x13,
			0x13,0x13,0x13,0x13,0x13,0x12,0x12,0x12,
			0x12,0x12,0x12,0x11,0x11,0x11,0x11,0x11
		]
		@track5300 = [
			# <0-7>,<8-15>,<16-?, remaining bits 0>
			0xff,0xff,0x1f, # track 36 (21 sectors)
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xff,0xff,0x1f,
			0xfc,0xff,0x07, # track 53 (19 sectors, 2 used)
			0xff,0xff,0x07, # track 54 (19 sectors)
			0xff,0xff,0x07,
			0xff,0xff,0x07,
			0xff,0xff,0x07,
			0xff,0xff,0x07,
			0xff,0xff,0x07,
			0xff,0xff,0x03, # track 60 (18 sectors)
			0xff,0xff,0x03,
			0xff,0xff,0x03,
			0xff,0xff,0x03,
			0xff,0xff,0x03,
			0xff,0xff,0x03,
			0xff,0xff,0x01, # track 66 (17 sectors)
			0xff,0xff,0x01,
			0xff,0xff,0x01,
			0xff,0xff,0x01,
			0xff,0xff,0x01,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00, # $69-$6f
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$70-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$80-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$90-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$a0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$b0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$c0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$d0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$e0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, #$f0-
			0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		]
		# Create a disk image. Return number of free blocks, or -1 for failure.

#		for track in 36 .. 40 do
#			@track1800[0xc0 + 4 * (track - 36) .. 0xc0 + 4 * (track - 36) + 3] = (track > @tracks ? [0,0,0,0] : [0x11,0xff,0xff,0x01])
#		end
		
		# Set disk title
		c64_title = name_to_c64(disk_title)
		@track1800[0x90 .. 0x9f] = Array.new(0x10, 0xa0)
		[c64_title.length, 0x10].min.times do |charno|
			@track1800[0x90 + charno] = c64_title[charno].ord
		end
		
		if @is_boot_disk and @config_track then
			allocate_sector(@config_track, 0)
			allocate_sector(@config_track, 1)
		end

		@free_blocks
	end # initialize


	private
	
	def allocate_sector(track, sector)
		print "*" if $PRINT_DISK_MAP
		if track > 35 then # BAM is (mostly) in sector 53:0
			index1 = 0xdd + track - 36
			index2 = 3 * (track - 36) + (sector / 8)
			# adjust number of free sectors
			@track1800[index1] -= 1

			# allocate sector
			index3 = 255 - 2**(sector % 8)
			@track5300[index2] &= index3
		else
			index1 = 4 * track
			index2 = 4 * track + 1 + (sector / 8)
			if track > 35 then # BAM is (mostly) in sector 53:0
				index1 += 0x30
				index2 += 0x30
			end
			# adjust number of free sectors
			@track1800[index1] -= 1
			# allocate sector
			index3 = 255 - 2**(sector % 8)
			@track1800[index2] &= index3
		end
	end

	def add_directory()
		# Add disk info and BAM at 18:00
		@contents[@track_offset[18] * 256 .. @track_offset[18] * 256 + 255] = @track1800

		# Add directory at 18:01
		@contents[@track_offset[18] * 256 + 256] = 0 
		@contents[@track_offset[18] * 256 + 257] = 0xff 

		# Add BAM 53:00
		@contents[@track_offset[53] * 256 .. @track_offset[53] * 256 + 255] = @track5300

	end
	
end # class D71_image

class D81_image < Disk_image
	def initialize(disk_title:, diskimage_filename:)
		puts "Creating disk image..." if $verbose

		@disk_title = disk_title
		@diskimage_filename = diskimage_filename
		@is_boot_disk = true

		@tracks = 80
		@track_length = Array.new(@tracks + 1, 40)
		@track_length[0] = 0
		@add_to_dir = []

		base_initialize()

		# NOTE: Blocks to skip can only be 0, 2, 4 or 6, or entire track.
		@reserved_sectors[40] = 40 # 4: Skip BAM and 1 directory block, 6: Skip BAM and 3 directory blocks, 40: Skip entire track
		if @config_track
			@reserved_sectors[@config_track] = 2
		end

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

		# Add BAM at 40:01 and 40:02
		@contents[(@track_offset[40] + 1) * 256 .. (@track_offset[40] + 1) * 256 + @track4001.length - 1] = @track4001

		# Create a disk image. Return number of free blocks, or -1 for failure.

		# Set disk title
		c64_title = name_to_c64(disk_title)
		@track4000[0x04 .. 0x13] = Array.new(0x10, 0xa0)
		[c64_title.length, 0x10].min.times do |charno|
			@track4000[0x04 + charno] = c64_title[charno].ord
		end
		
		if @config_track
			allocate_sector(@config_track, 0)
			allocate_sector(@config_track, 1)
		end

		@free_blocks
	end # initialize

	def create_story_partition
		if @storydata_start_track > 0 and @storydata_end_track >= @storydata_start_track

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

	def add_file(filename, filecontents, last_sector = nil) # Returns last sector used
		sector_count = 0
		last_sector_used = nil
		if filecontents == nil or filecontents.length == 0
			start_sector = [0,0]
			last_sector_used = start_sector
		else
			# Find first free sector as close as possible to the last sector used by the last file
			start_sector = find_free_file_start_sector(last_sector)
			last_sector_used = start_sector
			if start_sector == nil
				puts "ERROR: No free blocks left on disk."
				exit 1
			end
			sector_count += 1
			this_sector = start_sector
			while filecontents.length > 254
				next_sector = find_next_free_sector(this_sector[0], this_sector[1])
				if next_sector == nil
					puts "ERROR: No free blocks left on disk."
					exit 1
				end
				last_sector_used = next_sector
				
				sector_count += 1
				block_contents = next_sector.pack("CC") + filecontents[0 .. 253]
				filecontents = filecontents[254 .. filecontents.size - 1]
				@contents[256 * (@track_offset[this_sector[0]] + this_sector[1]) .. 
							256 * (@track_offset[this_sector[0]] + this_sector[1]) + 255] =
					block_contents.unpack("C*")
				this_sector = next_sector
			end
			block_contents = [0, filecontents.length + 2 - 1].pack("CC") + filecontents + Array.new(254 - filecontents.length).fill(0).pack("c*")
			@contents[256 * (@track_offset[this_sector[0]] + this_sector[1]) .. 
						256 * (@track_offset[this_sector[0]] + this_sector[1]) + 255] =
				block_contents.unpack("C*")
		end
		
		# Add file to directory
		dir_entry = ([0x81] + start_sector).pack("CCC") + 
			name_to_c64(filename).ljust(16, 0xa0.chr) +
			"".ljust(9, 0.chr) + 
			[sector_count % 256, sector_count / 256].pack("CC")
		
		@add_to_dir.push dir_entry
		
		return last_sector_used
	end

	

	private
	
	def allocate_sector(track, sector)
		print "*" if $PRINT_DISK_MAP
		index1 = (track > 40 ? 0x100: 0) + 0x10 +  6 * ((track - 1) % 40)
		index2 = index1 + 1 + (sector / 8)

		# adjust number of free sectors

		free = @contents[(@track_offset[40] + 1) * 256 + index1]
		if free < 1 or free > 40
			puts "BAD FREE TRACK SPACE: #{track}, #{sector}"
		end
		
		@contents[(@track_offset[40] + 1) * 256 + index1] = free - 1
		# allocate sector
		index3 = 255 - 2**(sector % 8)
		@contents[(@track_offset[40] + 1) * 256 + index2] &= index3
	end

	def sector_allocated?(track, sector)
		index1 = (track > 40 ? 0x100: 0) + 0x10 +  6 * ((track - 1) % 40)
		index2 = index1 + 1 + (sector / 8)
		index3 = 2**(sector % 8)

		# is sector allocated?
		return @contents[(@track_offset[40] + 1) * 256 + index2] & index3 == 0
	end
	
	def find_free_file_start_sector(last_sector = nil)
		if last_sector
			return find_next_free_sector(last_sector[0], last_sector[1])
		else
			1.upto 40 do |t|
				40.times do |s|
					unless t > 39 or sector_allocated?(40 - t, s)
						allocate_sector(40 - t, s)
						return [40 - t, s]
					end
					unless sector_allocated?(40 + t, s)
						allocate_sector(40 + t, s)
						return [40 + t, s]
					end
				end
			end
		end
		return nil
	end

	def find_next_free_sector(track, sector)
		start_track = track
		tried_track_1 = nil
		tried_track_80 = nil
		tried_sectors = []
		if interleave_scheme && interleave_scheme.has_key?(sector)
			next_sector = interleave_scheme[sector]
		else
			next_sector = (sector + 1) % 40
		end
		loop do
			unless sector_allocated?(track, next_sector)
				allocate_sector(track, next_sector)
				return [track, next_sector]
			end
			tried_sectors.push next_sector unless tried_sectors.include? next_sector 
			if tried_sectors.length > 39
				# This track is full, go to next
				tried_track_1 = true if track == 1
				tried_track_80 = true if track == 80
				return nil if tried_track_1 and tried_track_80 # No free sectors, fail!
				# Choose a track to try next
				if track < 40
					if track > 1
						track -= 1
					else
						track = 41
					end
				else
					if track < 80
						track += 1
					else
						track = 39
					end
				end
				next_sector = (sector + 8)
				next_sector = next_sector - (next_sector % 2)
				next_sector = next_sector % 40
			else
				next_sector = (next_sector > 38) ? 0 : next_sector + 1
			end
		end
	end

	def add_directory()
		# Add disk info at 40:00
		@contents[@track_offset[40] * 256 .. @track_offset[40] * 256 + @track4000.length - 1] = @track4000

		# Add directory at 40:03
		@contents[(@track_offset[40] + 3) * 256] = 0 
		@contents[(@track_offset[40] + 3) * 256 + 1] = 0xff

		add_files_to_dir(3,2)
	end

	def add_files_to_dir(sector, entry)
		unless @add_to_dir.empty?
			block_data = @contents[(@track_offset[40] + sector) * 256 .. (@track_offset[40] + sector) * 256 + 255]
			block_data[1] = 0xff
			while !@add_to_dir.empty? do
				while entry < 8 and block_data[0x20 * entry + 2] > 0
					entry += 1
				end
				if entry > 7
					block_data[0] = 40
					block_data[1] = sector + 1
					allocate_sector(40, sector + 1)
					add_files_to_dir(sector + 1, 0)
				else
					dir_entry = @add_to_dir[0]
					@add_to_dir = @add_to_dir.drop(1)
					block_data[0x20 * entry + 2 .. 0x20 * entry + 0x1f] = dir_entry.unpack("C*")
				end
			end
			@contents[(@track_offset[40] + sector) * 256 .. (@track_offset[40] + sector) * 256 + 255] = block_data
			@add_to_dir = []
		end
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
	necessarysettings =  " --setpc #{$start_address} -DCACHE_PAGES=#{$CACHE_PAGES} -DSTACK_PAGES=#{$stack_pages} -D#{$ztype}=1"
	necessarysettings +=  " -DCONF_TRK=#{$CONFIG_TRACK}" if $CONFIG_TRACK
	if $target == 'mega65' then
		necessarysettings +=  " --cpu m65"
	else
		necessarysettings +=  " --cpu 6510"
	end
	necessarysettings +=  " --format cbm"
	optionalsettings = ""
	optionalsettings += " -DSPLASHWAIT=#{$splash_wait}" if $splash_wait
	optionalsettings += " -DTERPNO=#{$interpreter_number}" if $interpreter_number
	optionalsettings += " -DNOSECTORPRELOAD=1" if $no_sector_preload
	optionalsettings += " -DSCROLLBACK_RAM_PAGES=#{$scrollback_ram_pages}" if $scrollback_ram_pages
	if $target
		optionalsettings += " -DTARGET_#{$target.upcase}=1"
	end
	if $is_lurkinghorror
		# need to know if compiling a Lurking Horror game
		# since the sound in this game doesn't follow the spec
		optionalsettings += " -DLURKING_HORROR=1"
	end
	if $use_history and $use_history > 0
		optionalsettings += " -DUSE_HISTORY=#{$use_history}"
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
	if $input_colour
		colourflags += " -DINPUTCOL=#{$input_colour}"
	end
	unless $GENERALFLAGS.include?('NODARKMODE')
		unless $default_colours_dm.empty? # or $zcode_version >= 5
			colourflags += " -DBGCOLDM=#{$default_colours_dm[0]} -DFGCOLDM=#{$default_colours_dm[1]}"
		end
		if $border_colour_dm
			colourflags += " -DBORDERCOLDM=#{$border_colour_dm}"
		end
		if $statusline_colour_dm
			colourflags += " -DSTATCOLDM=#{$statusline_colour_dm}"
		end
		if $input_colour_dm
			colourflags += " -DINPUTCOLDM=#{$input_colour_dm}"
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

	if $target == "mega65" then
		cmd = "#{$ACME} --setpc 0x2001 --cpu m65 --format cbm -l \"#{$wrapper_labels_file}\" --outfile \"#{$wrapper_file}\" c65toc64wrapper.asm"
		puts cmd if $verbose
		Dir.chdir $SRCDIR
		ret = system(cmd)
		Dir.chdir $EXECDIR
		exit 0 unless ret
	end
    
	cmd = "#{$ACME}#{necessarysettings}#{optionalsettings}#{fontflag}#{colourflags}#{generalflags}" +
		"#{debugflags}#{compressionflags} -l \"#{$labels_file}\" --outfile \"#{$ozmoo_file}\" ozmoo.asm"
	puts cmd if $verbose
	Dir.chdir $SRCDIR
	ret = system(cmd)
	Dir.chdir $EXECDIR
	unless ret
		puts "ERROR: There was a problem calling Acme"
		exit 1
	end
	$storystart = 0
	read_labels($labels_file);
	puts "Interpreter size: #{$program_end_address - $start_address} bytes." if $verbose
end

def read_labels(label_file_name)
	File.open(label_file_name).each do |line|
		$storystart = $1.to_i(16) if line =~ /\tstory_start\t=\s*\$(\w{3,4})\b/;
		$program_end_address = $1.to_i(16) if line =~ /\tprogram_end\t=\s*\$(\w{3,4})\b/;
		$loader_pic_start = $1.to_i(16) if line =~ /\tloader_pic_start\t=\s*\$(\w{3,4})\b/;
		$config_load_address = $1.to_i(16) if line =~ /\tconfig_load_address\t=\s*\$(\w{3,4})\b/;
	end
end

def build_loader_file()
	necessarysettings =  ""
	exo_target = ""
	if $target == 'c64'
		necessarysettings =  " --cpu 6510 --format cbm -DTARGET_C64=1"
	end
	if $target == 'plus4'
		necessarysettings =  " --cpu 6510 --format cbm -DTARGET_PLUS4=1"
		exo_target = " -t4"
	end

	optionalsettings = ""
	optionalsettings += " -DFLICKER=1" if $loader_flicker
	
    cmd = "#{$ACME}#{necessarysettings}#{optionalsettings}" +
		" -l \"#{$loader_labels_file}\" --outfile \"#{$loader_file}\" picloader.asm"
	puts cmd if $verbose
	Dir.chdir $SRCDIR
    ret = system(cmd)
	Dir.chdir $EXECDIR
	unless ret
		puts "ERROR: There was a problem calling Acme"
		exit 1
	end
	read_labels($loader_labels_file);
	puts "Loader pic address: #{$loader_pic_start}"

	imagefile_clause = " \"#{$loader_pic_file}\"@#{$loader_pic_start},2"
	exomizer_cmd = "#{$EXOMIZER} sfx basic -B#{exo_target} \"#{$loader_file}\"#{imagefile_clause} -o \"#{$loader_zip_file}\""

	puts exomizer_cmd if $verbose
	ret = system(exomizer_cmd)
	unless ret
		puts "ERROR: There was a problem calling Exomizer"
		exit 1
	end
	File.size($loader_zip_file)
end


def build_specific_boot_file(vmem_preload_blocks, vmem_contents)
	compmem_clause = " \"#{$compmem_filename}\"@#{$storystart},0,#{[($dynmem_blocks +
		vmem_preload_blocks) * $VMEM_BLOCKSIZE, $memory_end_address - $storystart, 
		File.size($compmem_filename)].min}"

	font_clause = ""
	asm_clause = ""
	decrunch_effect = ""
	if $font_filename
		font_clause = " \"#{$font_filename}\"@#{$font_address}"
	end
	exo_target = ""
	if $target == 'plus4'
		exo_target = " -t4"
		asm_clause = " -s #{$commandline_quotemark}lda $ff15 sta $ff19 lda $ff06 and \#$ef sta $ff06#{$commandline_quotemark} -f #{$commandline_quotemark}lda $ff06 ora \#$10 sta $ff06#{$commandline_quotemark}"
	end
	if $target == 'c128'
		exo_target = " -t128"
		asm_clause = " -s #{$commandline_quotemark}lda $d021 sta $d020 lda \#1 sta $d030 lda $d011 and \#111 sta $d011#{$commandline_quotemark} -f #{$commandline_quotemark}lda \#0 sta $d030 lda $d011 ora \#16 and \#127 sta $d011#{$commandline_quotemark}"
#		decrunch_effect = " -X #{$commandline_quotemark}txa and \#$1f sta $0400 sty $d800#{$commandline_quotemark}"
#		decrunch_effect = " -X #{$commandline_quotemark}stx $0400#{$commandline_quotemark}"
		decrunch_effect = " -n"
	end

#	exomizer_cmd = "#{$EXOMIZER} sfx basic -B -X \'LDA $D012 STA $D020 STA $D418\' ozmoo #{$compmem_filename},#{$storystart} -o ozmoo_zip"
#	exomizer_cmd = "#{$EXOMIZER} sfx #{$start_address} -B -M256 -C -x1 #{font_clause} \"#{$ozmoo_file}\"#{compmem_clause} -o \"#{$zip_file}\""
 #  -Di_irq_during=0 -Di_irq_exit=0
	exomizer_cmd = "#{$EXOMIZER} sfx #{$start_address}#{exo_target} -B -M256 -C #{decrunch_effect}#{font_clause}#{asm_clause} \"#{$ozmoo_file}\"#{compmem_clause} -o \"#{$zip_file}\""

	puts exomizer_cmd if $verbose
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
	puts "Max file size is #{max_file_size} bytes." if $verbose
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
	c1541_cmd = "#{$C1541} -attach \"#{diskimage_filename}\" -write \"#{$loader_zip_file}\" loader"
	puts c1541_cmd if $verbose
	system(c1541_cmd)
end

def add_boot_file(finaldiskname, diskimage_filename)
	if $target == "mega65" then	
	        # Put C65/C64 mode switch wrapper on the front
			base = IO.binread($wrapper_file)
			to_append = IO.binread($good_zip_file)
			IO.binwrite($universal_file, base + to_append);
	end
	ret = FileUtils.cp(diskimage_filename, finaldiskname)

	opt = ""
#	opt = "-silent " unless $verbose # Doesn't work on older Vice versions
	
	c1541_cmd = "#{$C1541} #{opt}-attach \"#{finaldiskname}\" -write \"#{$good_zip_file}\" #{$file_name}"
	if $target == "mega65" then	
		c1541_cmd = "#{$C1541} #{opt}-attach \"#{finaldiskname}\" -write \"#{$universal_file}\" #{$file_name}"
#		c1541_cmd += " -write \"#{$story_file}\" \"zcode,s\""
#		c1541_cmd += " -write \"#{$config_filename}\" \"ozmoo.cfg,p\"" # No longer needed
		# $sound_files.each do |file|
			# f = file
			# tf = f.gsub(/^.*\//,'')
			# f = f.gsub(/\//,"\\") if $is_windows
		    # c1541_cmd += " -write \"#{f}\" \")#{tf},s\""
		# end
	end
	if $verbose
		puts c1541_cmd 
		system(c1541_cmd)
	else
		`#{c1541_cmd}`
		return true
	end
end

def play(filename)
	if $target == "mega65" then
		if defined? $MEGA65 then
			command = "#{$MEGA65} -8 \"#{filename}\""
		else
			puts "Location of MEGA65 emulator unknown. Please set $MEGA65 at start of make.rb"
			exit 0
		end
	elsif $target == "plus4" then
	    command = "#{$XPLUS4} \"#{filename}\""
	elsif $target == "c128" then
	    command = "#{$X128} \"#{filename}\""
	else
	    command = "#{$X64} \"#{filename}\""
	end
	puts command if $verbose
    system(command)
end

def limit_vmem_data_preload(vmem_data)
#	puts "%%% #{$dynmem_and_vmem_size_bank_0_max}, #{vmem_data[3]} #{$dynmem_blocks} #{$VMEM_BLOCKSIZE}"
	if $dynmem_and_vmem_size_bank_0_max < (vmem_data[3] + $dynmem_blocks) * $VMEM_BLOCKSIZE
		vmem_data[3] = $dynmem_and_vmem_size_bank_0_max / $VMEM_BLOCKSIZE - $dynmem_blocks
	end
end

def	sort_vmem_data(vmem_data, first_block_to_sort, last_block_to_sort)
	entries = vmem_data[2]
	sort_array = []
	mask = $zcode_version > 5 ? 0b0000001111111111 :
		$zcode_version < 4 ? 0b0000000011111111 : 0b0000000111111111
	(last_block_to_sort - first_block_to_sort + 1).times do |i|
		blockid_with_age = 256 * vmem_data[first_block_to_sort + 4 + i] + 
			vmem_data[first_block_to_sort + entries + 4 + i]
		blockid = blockid_with_age & mask
		age = blockid_with_age - blockid
		sort_array.push [blockid, age]
	end
	sort_array.sort_by! {|a| a[0]}
	(last_block_to_sort - first_block_to_sort + 1).times do |i|
		value = sort_array[i][0]
		age = sort_array[i][1]
		age_and_value = age + value
		lowbyte = age_and_value & 255
		highbyte = (age_and_value - lowbyte) >> 8
		vmem_data[first_block_to_sort + 4 + i] = highbyte
		vmem_data[first_block_to_sort + entries + 4 + i] = lowbyte
	end
end


def limit_vmem_data(vmem_data, max_length)
	oversize = vmem_data.length - max_length
	if oversize > 0
		entries = vmem_data[2]
		part1 = vmem_data[4..(entries + 3)]
		part2 = vmem_data[(4 + entries)..(3 + entries + entries)]
		trim = (oversize / 2.0).ceil()
		keep = part1.length - trim
		vmem_data[(4 + entries)..(3 + entries + entries)] = part2.take(keep)
		vmem_data[4 ..(entries + 3)] = part1.take(keep)
		vmem_data[2] = keep
		vmem_data[3] = keep if vmem_data[3] > keep
		size = 4 + 2 * keep
		vmem_data [0 .. 1] = [size / 256, size % 256]
		puts "Limited vmem_data to #{max_length} bytes by removing #{trim} blocks."
	end
	if $unbanked_vmem_blocks > 1 # and vmem_data[3] vmem_data[2] - vmem_data[3]
		# Vmem blocks are entirely or partially in unbanked memory
		first_block_to_sort = vmem_data[3]
		last_block_to_sort = [vmem_data[3], [$unbanked_vmem_blocks, vmem_data[2]].min()].max() - 1
		if first_block_to_sort < last_block_to_sort then
			sort_vmem_data(vmem_data, first_block_to_sort, last_block_to_sort)
			puts "Sorted unbanked VMEM blocks #{first_block_to_sort} to " + 
				"#{last_block_to_sort}" if $verbose
		end
	end
	if vmem_data[3] < vmem_data[2] then
		# There are vmem block load suggestions
		if $vmem_blocks_in_ram > $unbanked_vmem_blocks
			# Vmem blocks are entirely or partially in banked memory
			first_block_to_sort = [vmem_data[3], $unbanked_vmem_blocks].max()
			last_block_to_sort = vmem_data[2] - 1
			if first_block_to_sort < last_block_to_sort then
				sort_vmem_data(vmem_data, first_block_to_sort, last_block_to_sort)
				puts "Sorted banked VMEM blocks #{first_block_to_sort} to " + 
					"#{last_block_to_sort}" if $verbose
			end
		end
	end
end

def build_P(storyname, diskimage_filename, config_data, vmem_data, vmem_contents,
				preload_max_vmem_blocks, extended_tracks)
	max_story_blocks = 0
	
	boot_disk = false
	
	diskfilename = "#{$target}_#{storyname}.d64"
	
	if $dynmem_and_vmem_size_bank_0 < $story_size
		puts "#{$dynmem_and_vmem_size_bank_0} < #{$story_size}"
		puts "ERROR: The whole story doesn't fit in memory. Please try another build mode."
		exit 1
	end
	
	disk = D64_image.new(disk_title: $disk_title, diskimage_filename: diskimage_filename, 
		is_boot_disk: boot_disk, forty_tracks: extended_tracks, reserve_dir_track: nil)

	disk.add_story_data(max_story_blocks: max_story_blocks, add_at_end: extended_tracks) # Has to be run to finalize the disk

	disk.save()

	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}" if $verbose

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}" if $verbose
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

def build_S1(storyname, diskimage_filename, config_data, vmem_data, vmem_contents,
				preload_max_vmem_blocks, extended_tracks, reserve_dir_track)
	max_story_blocks = 9999
	
	boot_disk = true

	diskfilename = "#{$target}_#{storyname}.d64"

	disk = D64_image.new(disk_title: $disk_title, diskimage_filename: diskimage_filename, is_boot_disk: boot_disk, forty_tracks: extended_tracks, reserve_dir_track: reserve_dir_track)

	disk.add_story_data(max_story_blocks: max_story_blocks, add_at_end: extended_tracks)
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end
	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}" if $verbose

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}" if $verbose
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
#	puts "vmem_preload_blocks(#{vmem_preload_blocks} < $dynmem_blocks#{$dynmem_blocks}"
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[3] = vmem_preload_blocks

	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot / Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [DISKNAME_BOOT, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors

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

def build_S2(storyname, d64_filename_1, d64_filename_2, config_data, vmem_data, vmem_contents,
				preload_max_vmem_blocks, extended_tracks, reserve_dir_track)

	config_data[7] = 3 # 3 disks used in total
	outfile1name = "#{$target}_#{storyname}_boot.d64"
	outfile2name = "#{$target}_#{storyname}_story.d64"
	disk1title = $disk_title + ($disk_title.length < 13 ? ' 1/2' : '')
	disk2title = $disk_title + ($disk_title.length < 13 ? ' 2/2' : '')
	max_story_blocks = 9999
	disk1 = D64_image.new(disk_title: disk1title, diskimage_filename: d64_filename_1, 
		is_boot_disk: true, forty_tracks: false, reserve_dir_track: reserve_dir_track)
	disk2 = D64_image.new(disk_title: disk2title, diskimage_filename: d64_filename_2, 
		is_boot_disk: false, forty_tracks: extended_tracks, reserve_dir_track: nil)
	free_blocks = disk1.add_story_data(max_story_blocks: 0, add_at_end: false)
	free_blocks = disk2.add_story_data(max_story_blocks: max_story_blocks, add_at_end: false)
	puts "Free disk blocks after story data has been written: #{free_blocks}" if $verbose
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}" if $verbose
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, 664)
	vmem_data[3] = vmem_preload_blocks
	
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
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors

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

def build_D2(storyname, d64_filename_1, d64_filename_2, config_data, vmem_data, vmem_contents,
				preload_max_vmem_blocks, extended_tracks, reserve_dir_track)

	config_data[7] = 3 # 3 disks used in total
	outfile1name = "#{$target}_#{storyname}_boot_story_1.d64"
	outfile2name = "#{$target}_#{storyname}_story_2.d64"
	disk1title = $disk_title + ($disk_title.length < 13 ? ' 1/2' : '')
	disk2title = $disk_title + ($disk_title.length < 13 ? ' 2/2' : '')
	disk1 = D64_image.new(disk_title: disk1title, diskimage_filename: d64_filename_1, 
		is_boot_disk: true, forty_tracks: extended_tracks, reserve_dir_track: reserve_dir_track)
	disk2 = D64_image.new(disk_title: disk2title, diskimage_filename: d64_filename_2, 
		is_boot_disk: false, forty_tracks: extended_tracks, reserve_dir_track: nil)

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
	puts "Free disk blocks on disk #1 after story data has been written: #{free_blocks_1}" if $verbose
	free_blocks_2 = disk2.add_story_data(max_story_blocks: 9999, add_at_end: false)
	puts "Free disk blocks on disk #2 after story data has been written: #{free_blocks_2}" if $verbose
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks_1 -= (loader_size / 254.0).ceil
		puts "Free disk blocks on disk #1 after loader has been written: #{free_blocks_1}" if $verbose
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks_1)
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[3] = vmem_preload_blocks
	
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
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors

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

def build_D3(storyname, d64_filename_1, d64_filename_2, d64_filename_3, config_data, vmem_data,
				vmem_contents, preload_max_vmem_blocks, extended_tracks, reserve_dir_track)

	config_data[7] = 4 # 4 disks used in total
	outfile1name = "#{$target}_#{storyname}_boot.d64"
	outfile2name = "#{$target}_#{storyname}_story_1.d64"
	outfile3name = "#{$target}_#{storyname}_story_2.d64"
	disk1title = $disk_title + ($disk_title.length < 13 ? ' 1/3' : '')
	disk2title = $disk_title + ($disk_title.length < 13 ? ' 2/3' : '')
	disk3title = $disk_title + ($disk_title.length < 13 ? ' 3/3' : '')
	disk1 = D64_image.new(disk_title: disk1title, diskimage_filename: d64_filename_1, 
		is_boot_disk: true, forty_tracks: false, reserve_dir_track: reserve_dir_track)
	disk2 = D64_image.new(disk_title: disk2title, diskimage_filename: d64_filename_2, 
		is_boot_disk: false, forty_tracks: extended_tracks, reserve_dir_track: nil)
	disk3 = D64_image.new(disk_title: disk3title, diskimage_filename: d64_filename_3, 
		is_boot_disk: false, forty_tracks: extended_tracks, reserve_dir_track: nil)

	# Figure out how to put story blocks on the disks in optimal way.
	# Rule: Spread story data as evenly as possible, so heads will move less.
	total_raw_story_blocks = ($story_size - $story_file_cursor) / 256
	max_story_blocks = total_raw_story_blocks / 2
	
	free_blocks_1 = disk1.add_story_data(max_story_blocks: 0, add_at_end: false)
	puts "Free disk blocks on disk #1 after story data has been written: #{free_blocks_1}" if $verbose
	free_blocks_2 = disk2.add_story_data(max_story_blocks: max_story_blocks, add_at_end: false)
	puts "Free disk blocks on disk #2 after story data has been written: #{free_blocks_2}" if $verbose
	free_blocks_3 = disk3.add_story_data(max_story_blocks: 9999, add_at_end: false)
	puts "Free disk blocks on disk #3 after story data has been written: #{free_blocks_3}" if $verbose
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks_1 -= (loader_size / 254.0).ceil
		puts "Free disk blocks on disk #1 after loader has been written: #{free_blocks_1}" if $verbose
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, 664)
	vmem_data[3] = vmem_preload_blocks
	
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
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors

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

def build_71(storyname, diskimage_filename, config_data, vmem_data, vmem_contents, 
				preload_max_vmem_blocks, reserve_dir_track)
	max_story_blocks = 9999
	
	boot_disk = true

	diskfilename = "#{$target}_#{storyname}.d71"

	disk = D71_image.new(disk_title: $disk_title, diskimage_filename: diskimage_filename, 
		is_boot_disk: boot_disk, reserve_dir_track: reserve_dir_track)

	disk.add_story_data(max_story_blocks: max_story_blocks, add_at_end: nil)
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end
	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}" if $verbose

#	# Build picture loader
#	if $loader_pic_file
#		loader_size = build_loader_file()
#		free_blocks -= (loader_size / 254.0).ceil
#		puts "Free disk blocks after loader has been written: #{free_blocks}" if $verbose
#	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
#	puts "vmem_preload_blocks(#{vmem_preload_blocks} < $dynmem_blocks#{$dynmem_blocks}"
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[3] = vmem_preload_blocks

	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot / Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [DISKNAME_BOOT, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors
	
	config_data += vmem_data

	#	puts config_data
	disk.set_config_data(config_data)
	
	disk.save()
	
#	# Add picture loader
#	if $loader_pic_file
#		if add_loader_file(diskimage_filename) != true
#			puts "ERROR: Failed to write loader to disk."
#			exit 1
#		end
#	end

	# Add bootfile + terp + preloaded vmem blocks file to disk
	if add_boot_file(diskfilename, diskimage_filename) != true
		puts "ERROR: Failed to write bootfile/interpreter to disk."
		exit 1
	end

	$bootdiskname = "#{diskfilename}"
	puts "Successfully built game as #{$bootdiskname}"
	nil # Signal success
end

def build_81(storyname, diskimage_filename, config_data, vmem_data, vmem_contents, 
				preload_max_vmem_blocks)

	diskfilename = "#{$target}_#{storyname}.d81"
	
	disk = D81_image.new(disk_title: $disk_title, diskimage_filename: diskimage_filename)
	if $i81
		disk.interleave_scheme = $i81
	end

	if $target == "mega65" then
		last_sector = nil
		$sound_files.each do |file|
			f = file
			tf = ')' + f.gsub(/^.*\//,'')
			f = f.gsub(/\//,"\\") if $is_windows
			file_contents = IO.binread(f)
#			last_sector = disk.add_file(tf, file_contents, last_sector);
			 # Don't use the option to add new file just after last file!
			last_sector = disk.add_file(tf, file_contents);
		end
		dynbytes = $dynmem_blocks * $VMEM_BLOCKSIZE
#		disk.add_file('zcode-dyn', $story_file_data[0 .. dynbytes - 1])
#		disk.add_file('zcode-stat', $story_file_data[dynbytes .. $story_file_data.length - 1])
		disk.add_file('zcode', $story_file_data)
		disk.add_story_data(max_story_blocks: 0, add_at_end: false)
	else
		disk.add_story_data(max_story_blocks: 9999, add_at_end: false)
	end
	free_blocks = disk.free_blocks()
	puts "Free disk blocks after story data has been written: #{free_blocks}" if $verbose

	# Build picture loader
	if $loader_pic_file
		loader_size = build_loader_file()
		free_blocks -= (loader_size / 254.0).ceil
		puts "Free disk blocks after loader has been written: #{free_blocks}" if $verbose
	end

	# Build bootfile + terp + preloaded vmem blocks as a file
#	puts "build_boot_file(#{preload_max_vmem_blocks}, #{vmem_contents.length}, #{free_blocks})"
	vmem_preload_blocks = build_boot_file(preload_max_vmem_blocks, vmem_contents, free_blocks)
#	puts "vmem_preload_blocks(#{vmem_preload_blocks} < $dynmem_blocks#{$dynmem_blocks}"
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the bootfile/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[3] = vmem_preload_blocks

	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x3f)}
# Data for disk: bytes used, device# = 0 (auto), Last story data sector + 1 (word), tracks used for story data, name = "Boot / Story disk"
	config_data += [disk_info_size, 0, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [DISKNAME_BOOT, "/".ord, " ".ord, DISKNAME_STORY, DISKNAME_DISK, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	limit_vmem_data(vmem_data, 512 - config_data.length) # Limit config data to two sectors

	config_data += vmem_data

	#	puts config_data
	# if $target == "mega65" then
		# config_filehandle = File.open($config_filename, "wb")
		# config_filehandle.write [$config_load_address % 256, $config_load_address / 256].pack("C*")
		# config_filehandle.write config_data.pack("C*")
		# config_filehandle.close
	# else
	unless $target == "mega65" then
		disk.set_config_data(config_data)
	end
	
	
	unless $target == "mega65" then
		if $statmem_blocks > 0
			if disk.create_story_partition() == false
				puts "ERROR: Could not create partition to protect data on disk."
				exit 1
			end
		end
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

	$bootdiskname = "#{diskfilename}"
	puts "Successfully built game as #{$bootdiskname}"
	nil # Signal success
end

def print_usage_and_exit
	print_usage
	exit 1
end

def print_usage
	puts "Usage: make.rb [-t:target] [-S1|-S2|-D2|-D3|-71|-81|-P] -v"
	puts "         [-p:[n]] [-b] [-o] [-c <preloadfile>] [-cf <preloadfile>]"
	puts "         [-sp:[n]] [-re[:0|1]] [-sl[:0|1]] [-s] " 
	puts "         [-fn:<name>] [-f <fontfile>] [-cm:[xx]] [-in:[n]]"
	puts "         [-i <imagefile>] [-if <imagefile>] [-ch[:n]] [-sb[:0|1|6|8|10|12]] [-rb[:0|1]]"
	puts "         [-rc:[n]=[c],[n]=[c]...] [-dc:[n]:[n]] [-bc:[n]] [-sc:[n]] [-ic:[n]]"
	puts "         [-dm[:0|1]] [-dmdc:[n]:[n]] [-dmbc:[n]] [-dmsc:[n]] [-dmic:[n]]"
	puts "         [-ss[1-4]:\"text\"] [-sw:[nnn]] [-smooth[:0|1]]"
	puts "         [-cb:[n]] [-cc:[n]] [-dmcc:[n]] [-cs:[b|u|l]] "
	puts "         [-dt:\"text\"] [-rd] [-as(a|w) <soundpath>] "
	puts "         [-u[:0|1|r]] <storyfile>"
	puts "  -t: specify target machine. Available targets are c64 (default), c128, plus4 and mega65."
	puts "  -S1|-S2|-D2|-D3|-71|-81|-P: build mode. Defaults to S1 (71 for C128, 81 for MEGA65). See docs."
	puts "  -v: Verbose mode. Print as much details as possible about what make.rb is doing."
	puts "  -p: preload a a maximum of n virtual memory blocks to make game faster at start."
	puts "  -b: only preload virtual memory blocks that can be included in the boot file."
	puts "  -o: build interpreter in PREOPT (preload optimization) mode. See docs for details."
	puts "  -c: read preload config from preloadfile, previously created with -o"
	puts "  -cf: read preload config (see -c) + fill up with best-guess vmem blocks"
	puts "  -sp: Use the specified number of pages for stack (2-64, default is 4)."
	puts "  -re: Perform all checks for runtime errors, making code slightly bigger and slower."
	puts "  -sl: Remove some optimizations for speed. This makes the terp ~100 bytes smaller."
	puts "  -s: start game in Vice if build succeeds"
	puts "  -fn: boot file name (default: story)"
	puts "  -f: Embed the specified font with the game. See docs for details."
	puts "  -cm: Use the specified character map (sv, da, de, it, es or fr)"
	puts "  -in: Set the interpreter number (0-19). Default is 2 for Beyond Zork, 8 for other games."
	puts "  -i: Add a loader using the specified Koala Painter multicolour image (filesize: 10003 bytes)."
	puts "  -if: Like -i but add a flicker effect in the border while loading."
	puts "  -ch: Use command line history, with min size of n bytes (0 to disable, 1 for default size)."
	puts "  -sb: Use the scrollback buffer (1 = in REU/Attic, 6,8,10,12 = use RAM if needed (KB))"
	puts "  -rb: Enable the REU Boost feature"
	puts "  -rc: Replace the specified Z-code colours with the specified C64 colours. See docs for details."
	puts "  -dc/dmdc: Use the specified background and foreground colours. See docs for details."
	puts "  -bc/dmbc: Use the specified border colour. 0=same as bg, 1=same as fg. See docs for details."
	puts "  -sc/dmsc: Use the specified status line colour. Only valid for Z3 games. See docs for details."
	puts "  -ic/dmic: Use the specified input colour. Only valid for Z3 and Z4 games. See docs for details."
	puts "  -dm: Enable the ability to switch to dark mode"
	puts "  -ss1, -ss2, -ss3, -ss4: Add up to four lines of text to the splash screen."
	puts "  -sw: Set the splash screen wait time (1-999 s), or 0 to disable splash screen."
	puts "  -smooth: Enable smooth-scrolling support (C64, C128)."
	puts "  -cb: Set cursor blink frequency (1-99, where 1 is fastest)."
	puts "  -cc/dmcc: Use the specified cursor colour.  Defaults to foreground colour."
	puts "  -cs: Use the specified cursor shape.  ([b]lock (default), [u]nderscore or [l]ine)"
	puts "  -dt: Set the disk title to the specified text."
	puts "  -rd: Reserve the entire directory track, typically for directory art."
	puts "  -asa: Add the .aiff sound files found at the specified path (003.aiff - 255.aiff)."
	puts "  -asw: Add the .wav sound files found at the specified path (003.wav - 255.wav)."
	puts "  -u: Add support for UNDO. Enabled by default for MEGA65. Use -u:r for RAM buffer (C128 only)"
	puts "  storyfile: path optional (e.g. infocom/zork1.z3)"
end

splashes = [
"", "", "", ""
]
mode = nil
$interpreter_number = nil
i = 0
fill_preload = nil
await_soundpath = false
await_preloadfile = false
await_fontfile = false
await_imagefile = false
preloadfile = nil
$sound_path = nil
$sound_files = []
$font_filename = nil
$font_address = nil
$loader_pic_file = nil
$loader_flicker = false
auto_play = false
optimize = false
extended_tracks = false
preload_max_vmem_blocks = 2**17 / $VMEM_BLOCKSIZE
limit_preload_vmem_blocks = false
$start_address = 0x0801
$program_end_address = 0x10000
$memory_end_address = 0x10000
$normal_ram_end_address = 0xd000
$unbanked_ram_end_address = 0xd000
$colour_replacements = []
$default_colours = []
$default_colours_dm = []
$statusline_colour = nil
$statusline_colour_dm = nil
$input_colour = nil
$input_colour_dm = nil
$target = 'c64'
$border_colour = nil
$border_colour_dm = nil
$stack_pages = 4 # Should normally be 2-6. Use 4 unless you have a good reason not to.
$border_colour = 0
$char_map = nil
$splash_wait = nil
$cursor_colour = nil
$cursor_shape = nil
$cursor_blink = nil
$verbose = nil
$use_history = nil
$no_sector_preload = nil
$file_name = 'story'
custom_file_name = nil
$undo = nil
$undo_ram = nil
$sound_format = nil
$disk_title = nil
$scrollback_ram_pages = nil
reserve_dir_track = nil
check_errors = nil
dark_mode = nil
smooth_scroll = nil
scrollback = nil
reu_boost = nil

begin
	while i < ARGV.length
		if await_preloadfile then
			await_preloadfile = false
			preloadfile = ARGV[i]
		elsif await_soundpath then
			await_soundpath = false
			$sound_path = ARGV[i]
		elsif await_fontfile then
			await_fontfile = false
			$font_filename = ARGV[i]
		elsif await_imagefile then
			await_imagefile = false
			$loader_pic_file = ARGV[i]
		elsif ARGV[i] =~ /^-o$/ then
			optimize = true
			$no_sector_preload = true
		elsif ARGV[i] =~ /^-in:(1?\d)$/ then
			$interpreter_number = $1
		elsif ARGV[i] =~ /^-s$/ then
			auto_play = true
		elsif ARGV[i] =~ /^-rd$/ then
			reserve_dir_track = true
		elsif ARGV[i] =~ /^-p:(\d+)$/ then
			preload_max_vmem_blocks = $1.to_i
			limit_preload_vmem_blocks = true
		elsif ARGV[i] =~ /^-t:(c64|c128|mega65|plus4)$/ then
			$target = $1
			if $target == "mega65" then
			    $start_address = 0x1001
			elsif $target == "plus4" then
			    $start_address = 0x1001
				$memory_end_address = 0xfc00
				$unbanked_ram_end_address = $memory_end_address
				$normal_ram_end_address = $memory_end_address
			elsif $target == "c128" then
			    $start_address = 0x1200
				$memory_end_address = 0xfc00
				$unbanked_ram_end_address = 0xc000
				$normal_ram_end_address = $memory_end_address
				$CACHE_PAGES = 4 # Cache is static size on C128
			end
		elsif ARGV[i] =~ /^-P$/ then
			mode = MODE_P
			$CACHE_PAGES = 2 # We're not actually using the cache, but there may be a splash screen in it
		elsif ARGV[i] =~ /^-S1$/ then
			mode = MODE_S1
		elsif ARGV[i] =~ /^-S2$/ then
			mode = MODE_S2
		elsif ARGV[i] =~ /^-D2$/ then
			mode = MODE_D2
		elsif ARGV[i] =~ /^-D3$/ then
			mode = MODE_D3
		elsif ARGV[i] =~ /^-71$/ then
			mode = MODE_71
		elsif ARGV[i] =~ /^-81$/ then
			mode = MODE_81
		elsif ARGV[i] =~ /^-ch(?::(\d{1,3}))?$/ then
			if $1 == nil
				$use_history = 1
			else
				$use_history = $1.to_i
			end
		elsif ARGV[i] =~ /^-v$/ then
			$verbose = true
		elsif ARGV[i] =~ /^-debug$/ then
			$force_debug = true
		elsif ARGV[i] =~ /^-b$/ then
			$no_sector_preload = true
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
		elsif ARGV[i] =~ /^-ic:([2-9])$/ then
			$input_colour = $1.to_i
		elsif ARGV[i] =~ /^-dmic:([2-9])$/ then
			$input_colour_dm = $1.to_i
		elsif ARGV[i] =~ /^-sp:(0?[2-9]|[1-5][0-9]|6[0-4])$/ then
			$stack_pages = $1.to_i
		elsif ARGV[i] =~ /^-cm:(sv|da|de|it|es|fr)$/ then
			$char_map = $1
		elsif ARGV[i] =~ /^-asa$/ then
			if $sound_format
				puts "ERROR: Only one sound path can be specified."
				exit 1
			end
			$sound_format = 'aiff'
			await_soundpath = true
		elsif ARGV[i] =~ /^-asw$/ then
			if $sound_format
				puts "ERROR: Only one sound path can be specified."
				exit 1
			end
			$sound_format = 'wav'
			await_soundpath = true
		elsif ARGV[i] =~ /^-u(?::([01r]))?$/ then
			if $1 == nil
				$undo = 1
			elsif $1 == 'r'
				$undo = 1
				$undo_ram = 1
			else
				$undo = $1.to_i
			end
		elsif ARGV[i] =~ /^-cf$/ then
			await_preloadfile = true
			fill_preload = true
		elsif ARGV[i] =~ /^-c$/ then
			await_preloadfile = true
		elsif ARGV[i] =~ /^-f$/ then
			await_fontfile = true
		elsif ARGV[i] =~ /^-if?$/ then
			await_imagefile = true
			$loader_flicker = ARGV[i] =~ /f$/
		elsif ARGV[i] =~ /^-ss([1-4]):(.*)$/ then
			splashes[$1.to_i - 1] = $2
		elsif ARGV[i] =~ /^-dt:(.*)$/ then
			$disk_title = $1
		elsif ARGV[i] =~ /^-sw:(\d{1,3})$/ then
			$splash_wait = $1
		elsif ARGV[i] =~ /^-cc:([0-9])$/ then
			$cursor_colour = $1.to_i
		elsif ARGV[i] =~ /^-dmcc:([0-9])$/ then
			$cursor_colour_dm = $1.to_i
		elsif ARGV[i] =~ /^-cs:([b|u|l])$/ then
			$cursor_shape = $1
		elsif ARGV[i] =~ /^-cb:([1-9]|[1-9][0-9])$/ then
			$cursor_blink = $1
		elsif ARGV[i] =~ /^-re(?::([0-1]))?$/ then
			if $1 == nil
				check_errors = 1
			else
				check_errors = $1.to_i
			end
		elsif ARGV[i] =~ /^-sl(?::([0-1]))?$/ then
			if $1 == '0'
				$GENERALFLAGS.delete('SLOW') if $GENERALFLAGS.include?('SLOW')
			else
				$GENERALFLAGS.push('SLOW') unless $GENERALFLAGS.include?('SLOW') 
			end
		elsif ARGV[i] =~ /^-dm(?::([01]))?$/ then
			if $1 == nil
				dark_mode = 1
			else
				dark_mode = $1.to_i
			end
		elsif ARGV[i] =~ /^-smooth(?::([01]))?$/ then
			if $1 == nil
				smooth_scroll = 1
			else
				smooth_scroll = $1.to_i
			end
		elsif ARGV[i] =~ /^-sb(?::(0|1|6|8|10|12))?$/ then
			if $1 == nil
				scrollback = 1
			else
				scrollback = $1.to_i
			end
		elsif ARGV[i] =~ /^-rb(?::([01]))?$/ then
			if $1 == nil
				reu_boost = 1
			else
				reu_boost = $1.to_i
			end
		elsif ARGV[i] =~ /^-fn:([a-z0-9]+)$/ then
			custom_file_name = $1
		elsif ARGV[i] =~ /^-(bc|ic|sc|dc|cc|dmbc|dmsc|dmic|dmdc|dmcc):/ then
			raise "Color index for -#{$1} is out of range, please be sure to use the Z-code palette with index 2-9."
		elsif ARGV[i] =~ /^-/i then
			raise "Unknown option: " + ARGV[i]
		else 
			$story_file = ARGV[i]
		end
		i = i + 1
	end
	if !$story_file
		print_usage_and_exit()
		exit 1
	end
rescue => e
	print_usage()
	puts
	print "ERROR: "
	puts e.message
	exit 1
end

if $target == "mega65"
	$file_name = 'autoboot.c65'
end

if custom_file_name
	$file_name = custom_file_name
end

if $target =~ /^c(64|128)$/ and reu_boost == nil
	reu_boost = 1
end
if reu_boost == 1
	$GENERALFLAGS.push('REUBOOST') unless $GENERALFLAGS.include?('REUBOOST')
	if $target !~ /^c(64|128)$/
		puts "ERROR: REU Boost is not available for this platform." 
		exit 1
	end
end

if smooth_scroll == nil
	smooth_scroll = 0
end
if $target !~ /^(c64|c128)$/ and smooth_scroll == 1
	puts "ERROR: Smooth scroll is not available for this platform." 
	exit 1
end

if $target == "mega65" and $use_history == nil
	$use_history = 1 # Default size, set in next step
end
if $use_history and $use_history > 0
	# set default history size
	if $use_history == 1 then
		if $target == "mega65" then
			# MEGA65 has lots of space, default to the max (255)
			$use_history = 255
		elsif $target == "c128" then
			# c128 doesn't adjust the buffer to .align so we need
			# to specify the size we actually want.
			$use_history = 200
		else
			# history will use all available space until the next 
			# .align command, but since we can't predict how much
			# space will be available allocate minimal buffer.
			# The real size is in the range [40,255] bytes.
			$use_history = 40
		end
	end
	if $use_history < 20 || $use_history > 255 then
		puts "ERROR: -ch only takes an argument in the 20-255 range."
		exit 1
	end
end

if $target == "mega65"
	$GENERALFLAGS.push('CHECK_ERRORS') unless $GENERALFLAGS.include?('CHECK_ERRORS')
end
if check_errors == 0
	$GENERALFLAGS.delete('CHECK_ERRORS') if $GENERALFLAGS.include?('CHECK_ERRORS')
elsif check_errors == 1
	$GENERALFLAGS.push('CHECK_ERRORS') unless $GENERALFLAGS.include?('CHECK_ERRORS')
end


if $target == "mega65"
	if preloadfile or (limit_preload_vmem_blocks and preload_max_vmem_blocks > 0) then
		puts "ERROR: Preloading blocks (option -c/-cf/-p) is not supported on this target platform."
		exit 1
	end
	# No config track
	$CONFIG_TRACK = nil
	# Force -p:0 -b (Don't include any vmem blocks in boot file, and don't preload any at start
	preload_max_vmem_blocks = 0
	limit_preload_vmem_blocks = true
	$no_sector_preload = true
end

print_usage_and_exit() if await_soundpath or await_preloadfile or await_fontfile or await_imagefile

unless mode
	if $target == 'c128'
		mode = MODE_71
	elsif $target == 'mega65'
		mode = MODE_81
	else 
		mode = MODE_S1
	end
end

if mode == MODE_P
	# In this mode, we don't use the vmem buffer for holding vmem data. However, the
	# splash screen resides in the buffer too. By default it's 2 pages in this mode.
	if $splash_wait == "0"
		$CACHE_PAGES = 0 # We don't have any use for the cache whatsoever
	else
		len = 0
		splashes.each { |s| len += s.length }
		if len <= 100
			$CACHE_PAGES = 1 # With this little text, we can go down from 2 pages to 1
		end
	end
end	

if mode != MODE_81 and $target == 'mega65'
	puts "ERROR: Only build mode 81 is supported on this target platform."
	exit 1
end

# if mode == MODE_71 and $target != 'c128'
	# puts "ERROR: Build mode 71 is not supported on this target platform."
	# exit 1
# end

if mode == MODE_P and $target == 'c128'
	puts "ERROR: Build mode P is not supported on this target platform."
	exit 1
end

if $loader_pic_file
	if $target != 'c64' and $target != 'plus4'
		puts "ERROR: Image loader is not supported on this target platform."
		exit 1
	end
	if $target == 'plus4' and $loader_flicker
		puts "ERROR: Flicker during loading is not supported on this target platform."
		exit 1
	end
end

if $font_filename
	if $target == 'c64'
		$font_address = 0x0800
		$start_address = 0x1000
	elsif $target == 'c128' 
		$font_address = 0x1800
		$start_address = 0x2000
	elsif $target == 'mega65'
		# It is not possible to disable shadow character roms on
		# the C64 and the MEGA65, so we cannot use $1000-$2000
		# for custom fonts. Instead we put the font in $0800, but
		# we also need to move the scren to $1000, since it will no
		# longer fit at $0400 because it is now 80 characters wide
		# and needs more space.
		$font_address = 0x0800
		$start_address = 0x1800
	elsif $target == 'plus4'
		$font_address = 0x1000
		$start_address = 0x1800
	else
		puts "ERROR: Custom fonts are currently not supported for this target platform."
		exit 1
	end
end

if $sound_path
	if $target != 'mega65'
		puts "ERROR: Sound is only supported for the MEGA65 target platform."
		exit 1
	end
	$sound_path = $sound_path.gsub(/\\/, '/');
	$sound_path += '/' if $sound_path !~ /\/$/ 
	$sound_files = Dir.glob($sound_path + '*').select { |e|
#		/^([0-9]{3})\.#{$sound_format}$/
#		puts e
		File.file?(e) && m = e[$sound_path.length .. -1].match(/^([0-9]{3})r?\.#{$sound_format}$/) and m[1].to_i.between?(3,255)
	}
	if $sound_files.empty?
		puts "ERROR: No sound files found. Note that sound files must be named " + 
			"003.#{$sound_format}, 004.#{$sound_format} etc, and the highest number allowed is 255."
		exit 1
	end
	$sound_files.sort!
	$GENERALFLAGS.push('SOUND')
	if $sound_format == 'wav'
		$GENERALFLAGS.push('SOUND_WAV_ENABLED')
	else
		$GENERALFLAGS.push('SOUND_AIFF_ENABLED')
	end
#	puts $sound_files
end

$VMEM = (mode != MODE_P && $target != 'mega65')

$GENERALFLAGS.push('DANISH_CHARS') if $char_map == 'da'
$GENERALFLAGS.push('SWEDISH_CHARS') if $char_map == 'sv'
$GENERALFLAGS.push('GERMAN_CHARS') if $char_map == 'de'
$GENERALFLAGS.push('ITALIAN_CHARS') if $char_map == 'it'
$GENERALFLAGS.push('SPANISH_CHARS') if $char_map == 'es'
$GENERALFLAGS.push('FRENCH_CHARS') if $char_map == 'fr'

$GENERALFLAGS.push('VMEM') if $VMEM

$colour_replacement_clause = ''
unless $colour_replacements.empty?
	$colour_replacements.each do |r|
		r =~ /^(\d\d?)=(\d\d?)$/
		zcode_colour = $1
		c64_colour = $2
		if zcode_colour !~ /^[2-9]$/
			puts "ERROR: -rc requires a Z-code colour value (2-9) to the left of the = character."
			exit 1
		end
		if c64_colour !~ /^([0-9]|1[0-5])$/
			puts "ERROR: -rc requires a C64 colour value (0-15) to the right of the = character."
			exit 1
		end
		$colour_replacement_clause += " -DCOL#{zcode_colour}=#{c64_colour}" unless $colour_replacement_clause.include? "-DCOL#{zcode_colour}=" 
	end
end

if $stack_pages < 4 and mode != MODE_P
	puts "ERROR: Stack pages < 4 is only allowed in build mode P."
	exit 1
end

if optimize and mode == MODE_P
	puts "ERROR: Option -o can't be used with this build mode."
	exit 1
end

if limit_preload_vmem_blocks and !$VMEM and $target != 'mega65'
	puts "ERROR: Option -p can't be used with this build mode."
	exit 1
end

if extended_tracks and !$VMEM
	puts "ERROR: Option -x can't be used with this build mode."
	exit 1
end

if optimize then
	if preloadfile then
		puts "ERROR: -c (preload story data) can not be used with -o."
		exit 1
	end
	$DEBUGFLAGS.push('PREOPT')
end

$DEBUGFLAGS.push('DEBUG') unless $DEBUGFLAGS.empty? or $DEBUGFLAGS.include?('DEBUG')


# Check for file specifying which blocks to preload
preload_data = nil
if preloadfile then
	preload_raw_data = File.read(preloadfile)
	vmem_type = "clock"
	if preload_raw_data =~ /^\$po\$:(([0-9a-f]{4}:\n?)+)\n?\$\$\$\$/i
		preload_data = $1.gsub(/\n/, '').gsub(/:$/,'').split(':')
		puts "#{preload_data.length} vmem blocks found for optimized preload."
	else
		puts "ERROR: No preload config data found (for vmem type \"#{vmem_type}\")."
		exit 1
	end
end

# divide $story_file into path, filename, extension (if possible)
path = File.dirname($story_file)
extension = File.extname($story_file)
filename = File.basename($story_file)
storyname = File.basename($story_file, extension)
$disk_title = storyname unless $disk_title

begin
	puts "Reading file #{$story_file}..." if $verbose
	$story_file_data = IO.binread($story_file)
rescue
	puts "ERROR: Can't open #{$story_file} for reading"
	exit 1
end

$zcode_version = $story_file_data[0].ord
$ztype = "Z#{$zcode_version}"

$zmachine_memory_size = $story_file_data[0x1a .. 0x1b].unpack("n")[0]
if $zcode_version < 4
	$zmachine_memory_size *= 2
elsif $zcode_version > 5
	$zmachine_memory_size *= 8
else
	$zmachine_memory_size *= 4
end

if $story_file_data.length % $VMEM_BLOCKSIZE != 0 # && mode != MODE_P
	$story_file_data += $ZEROBYTE * ($VMEM_BLOCKSIZE - ($story_file_data.length % $VMEM_BLOCKSIZE))
end


$vmem_highbyte_mask = ($zcode_version < 4) ? 0x00 : (($zcode_version > 5) ? 0x03 : 0x01)

if ($statusline_colour or $statusline_colour_dm) and $zcode_version > 3
	puts "ERROR: Options -sc and -dmsc can only be used with z1-z3 story files."
	exit 1
end	

if ($input_colour or $input_colour_dm) and $zcode_version > 4
	puts "ERROR: Options -ic and -dmic can only be used with z1-z4 story files."
	exit 1
end	

if scrollback == nil
	if $target == "mega65" and $zcode_version != 6
		scrollback = 1
	else
		scrollback = 0
	end
end
if scrollback == 1 and $target == "plus4"
	puts "ERROR: Scrollback buffer in REU is not supported on this target platform. Try e.g. -sb:6 to enable scrollback in RAM."
	exit 1
elsif scrollback > 0 and $zcode_version == 6
	puts "ERROR: Scrollback buffer not supported in version 6 games"
	exit 1
elsif scrollback == 0
	$GENERALFLAGS.push('NOSCROLLBACK') unless $GENERALFLAGS.include?('NOSCROLLBACK') 
end
if scrollback > 1
	if $target =~ /^(c64|c128|plus4)$/
		scrollback = 11 if $target == "c128" and scrollback > 11 # Because 11 KB fits above $d000 on C128
		$scrollback_ram_pages = 4 * scrollback
	else
		puts "ERROR: Scrollback buffer in RAM is not supported on this target platform."
		exit 1
	end
end
if scrollback > 0 and mode == MODE_P
	puts "ERROR: Scrollback is not supported for build mode P."
	exit 1
end



# check header.static_mem_start (size of dynmem)
$static_mem_start = $story_file_data[14 .. 15].unpack("n")[0]

# check header.release and serial to find out if beyondzork or not
release = $story_file_data[2 .. 3].unpack("n")[0]
serial = $story_file_data[18 .. 23]
storyfile_key = "r%d-s%s" % [ release, serial ]
is_trinity = $zcode_version == 4 && $trinity_releases.has_key?(storyfile_key)
is_beyondzork = $zcode_version == 5 && $beyondzork_releases.has_key?(storyfile_key)
$is_lurkinghorror = $zcode_version == 3 && $lurkinghorror_releases.has_key?(storyfile_key)

if dark_mode == 0
	$GENERALFLAGS.push('NODARKMODE') unless $GENERALFLAGS.include?('NODARKMODE')
end	

if smooth_scroll == 1
	$GENERALFLAGS.push('SMOOTHSCROLL') unless $GENERALFLAGS.include?('SMOOTHSCROLL')
end

if is_beyondzork
	$interpreter_number = 2 unless $interpreter_number
	# Turn off features that don't work properly in BZ anyway
	$use_history = nil 
	$GENERALFLAGS.push('NODARKMODE') unless $GENERALFLAGS.include?('NODARKMODE') or dark_mode == 1 
	$GENERALFLAGS.push('NOSCROLLBACK') unless $GENERALFLAGS.include?('NOSCROLLBACK') or scrollback == 1
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

if is_trinity
	patch_data_string = $trinity_releases[storyfile_key]
	patch_data_arr = patch_data_string.split(/ /)
	patch_address = patch_data_arr.shift.to_i(16)
	patch_check = patch_data_arr.shift.to_i(16)
	# Change all hex strings to 8-bit unsigned ints instead, due to bug in Ruby's array.pack("H")
	patch_data_arr.length.times do |i|
		patch_data_arr[i] = patch_data_arr[i].to_i(16)
	end
	if $story_file_data[patch_address .. (patch_address + 1)].unpack("n")[0] == patch_check
		puts patch_data_arr.length
		$story_file_data[patch_address .. (patch_address + patch_data_arr.length - 1)] =
			patch_data_arr.pack("C*")
		puts "Successfully patched Trinity story file."
	else
		puts "### WARNING: Story file matches serial + version# for Trinity, but contents differ. Failed to patch."
	end
end

if $target == 'c128' and $interpreter_number == nil
	$interpreter_number = 7
end


# get dynmem size (in vmem blocks)
$dynmem_blocks = ($static_mem_start.to_f / $VMEM_BLOCKSIZE).ceil
puts "Dynmem blocks: #{$dynmem_blocks}" if $verbose
# if $VMEM and preload_max_vmem_blocks and preload_max_vmem_blocks < $dynmem_blocks then
	# puts "Max preload blocks adjusted to dynmem size, from #{preload_max_vmem_blocks} to #{$dynmem_blocks}."
	# preload_max_vmem_blocks = $dynmem_blocks
# end

$story_file_cursor = $dynmem_blocks * $VMEM_BLOCKSIZE

$story_size = $story_file_data.length

$statmem_blocks = $story_size / $VMEM_BLOCKSIZE - $dynmem_blocks

if $verbose then 
	puts "$zmachine_memory_size = #{$zmachine_memory_size}"
	puts "$story_size = #{$story_size}"
end

$undo = 2 if ($undo == nil and $target == 'mega65') # undo is enabled by default on MEGA65
$undo = 0 if $undo == nil

undo_size = $dynmem_blocks * $VMEM_BLOCKSIZE + ($stack_pages + 1) * 256
max_dynmem_for_ram_undo = 18 # 18 KB dynmem is a good limit to keep a decent speed and vmem size. Up to 28 KB is possible.
max_ram_undo_size = (max_dynmem_for_ram_undo + 1) * 1024 + 256 # dynmem + stack + 256 bytes for ZP-vars 

if $undo > 0
	if $target !~ /^(c64|c128|mega65)$/
		puts "ERROR: Undo is only supported for the MEGA65, C64 and C128 target platforms."
		exit 1
	end
	if $undo_ram == 1
		$GENERALFLAGS.push('UNDO_RAM')
		if $target !~ /^c128$/ 
			puts "ERROR: Undo RAM buffer is only supported for the C128 target platform."
			exit 1
		elsif undo_size > max_ram_undo_size
			puts "ERROR: Undo size (dynmem + stack + 1 page) too big for Undo RAM buffer. Undo size is #{undo_size} bytes" +
				", while maximum allowed size is #{max_ram_undo_size} bytes."
			exit 1
		end
	end
	if undo_size > 64*1024
		if $undo == 1
			puts "ERROR: Dynmem + stack too large to support UNDO."
			exit 1
		else
			$undo = 0
		end
	end
	if $undo > 0
		$GENERALFLAGS.push('UNDO')
		$undo = 1
	end
end




# Splashscreen

# splashes = [
# "", "", "", ""
# ]
# splashes[0] = filename_to_title(storyname, 40)
splash = File.read(File.join($SRCDIR, 'splashlines.tpl'))
version = File.read(File.join(__dir__, 'version.txt'))
version.gsub!(/[^\d\.]/m,'')
splash.gsub!("@vs@", version)
#splash.sub!(/"(.*)\(F1 = darkmode\)/,'"          \1') if $GENERALFLAGS.include?('NODARKMODE')

4.times do |i|
	text = splashes[i]
	indent = 0
	if text.length > 0
		$splash_wait = 30 unless $splash_wait
		text.gsub!(/(\n|\t)+/, ' ')
		if text.length > 40
			puts "Splashline #{i + 1} is longer than 40 characters."
			exit 1
		end
		indent = ((40.0 - text.length) / 2.0).ceil
		text.gsub!(/"/, '",34,"')
	end
	splash.sub!("@#{i}s@", text)
	splash.sub!("@#{i}c@", indent.to_s)
end
File.write(File.join($SRCDIR, 'splashlines.asm'), splash)

# Boot file name handling

file_name = File.read(File.join($SRCDIR, 'file-name.tpl'))
file_name.sub!("@fn@", $file_name)
File.write(File.join($SRCDIR, 'file-name.asm'), file_name)

# Set $no_sector_preload if we can be almost certain it won't be needed anyway
if $target != 'c128' and limit_preload_vmem_blocks == false
	loader_kb = $loader_pic_file ? 5 : 0
	story_kb = ($story_size - $dynmem_blocks * $VMEM_BLOCKSIZE) / 1024
	bootfile_kb = 46
	used_kb = bootfile_kb + story_kb + loader_kb 
	case mode
	when MODE_S1
		$no_sector_preload = true if 170 - used_kb > 3
	when MODE_S2, MODE_D3, MODE_81
		$no_sector_preload = true
	when MODE_D2, MODE_71
		$no_sector_preload = true if 340 - used_kb > 3
	end
end


build_interpreter()

$dynmem_and_vmem_size_bank_0 = $memory_end_address - $storystart - 
	($scrollback_ram_pages ? 256 * $scrollback_ram_pages : 0)

$dynmem_and_vmem_size_bank_0_max = $dynmem_and_vmem_size_bank_0
if $target == 'c128'
	$dynmem_and_vmem_size_bank_0_max = $memory_end_address - $storystart
	if $scrollback_ram_pages != nil and $dynmem_blocks < $scrollback_ram_pages / 2
		$dynmem_and_vmem_size_bank_0_max = $memory_end_address - $storystart - 
			$scrollback_ram_pages * 256 + $dynmem_blocks * $VMEM_BLOCKSIZE
	end
end

if $target != 'mega65' and 
		$storystart + $dynmem_blocks * $VMEM_BLOCKSIZE > $normal_ram_end_address then
	puts "ERROR: Dynamic memory is too big (#{$dynmem_blocks * $VMEM_BLOCKSIZE} bytes), would pass end of normal RAM. Maximum dynmem size is #{$normal_ram_end_address - $storystart} bytes." 
	exit 1
end
puts "Dynamic memory: #{$dynmem_blocks * $VMEM_BLOCKSIZE} bytes" if $verbose 

$vmem_blocks_in_ram = ($memory_end_address - ($scrollback_ram_pages ? 256 * $scrollback_ram_pages : 0) -
		$storystart) / $VMEM_BLOCKSIZE - $dynmem_blocks

$unbanked_vmem_blocks = ($unbanked_ram_end_address - $storystart) / $VMEM_BLOCKSIZE - $dynmem_blocks

if $target == 'c128' then
	$vmem_blocks_in_ram += ($memory_end_address - 0x1200 - 256 * $stack_pages) / $VMEM_BLOCKSIZE 
	$unbanked_vmem_blocks += $dynmem_blocks
end
if $target != 'mega65'
	puts "VMEM blocks in RAM is #{$vmem_blocks_in_ram}" if $verbose
	puts "Unbanked VMEM blocks in RAM is #{$unbanked_vmem_blocks}" if $verbose 
	if	$unbanked_vmem_blocks < 1 and $story_size != $dynmem_blocks * $VMEM_BLOCKSIZE then
		puts "ERROR: Dynamic memory is too big (#{$dynmem_blocks * $VMEM_BLOCKSIZE} bytes), there would be no unbanked RAM for VMEM." 
		exit 1
	end
end

if reu_boost == 1 and $target == 'c64' and $unbanked_vmem_blocks * $VMEM_BLOCKSIZE / 256 < 12
	puts "ERROR: REU Boost requires at least 3 KB of unbanked RAM. Dynamic memory is #{$dynmem_blocks * $VMEM_BLOCKSIZE / 1024} KB, leaving only #{$unbanked_vmem_blocks * $VMEM_BLOCKSIZE / 1024} KB of unbanked RAM for REU Boost." 
	exit 1		
end

############################# End of moved block

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
total_storyfile_blocks = $story_size / $VMEM_BLOCKSIZE
mapped_vmem_blocks = 0 #all_vmem_blocks - $dynmem_blocks
unless $DEBUGFLAGS.include?('PREOPT') then
	if mode == MODE_P 
		mapped_vmem_blocks = total_storyfile_blocks - $dynmem_blocks
	else
#		puts "### #{$vmem_blocks_in_ram}, #{total_storyfile_blocks} - #{$dynmem_blocks}"
		mapped_vmem_blocks = [$vmem_blocks_in_ram, total_storyfile_blocks - $dynmem_blocks].min()
#		mapped_vmem_blocks = [$max_vmem_kb * 1024 / $VMEM_BLOCKSIZE - $dynmem_blocks,
#			total_storyfile_blocks - $dynmem_blocks].min()
	end
end
if preload_data then

	# Add extra blocks if there is room
	cursor = $dynmem_blocks
	added = 0
	if fill_preload == true and mapped_vmem_blocks > preload_data.length then
		used_block = Hash.new
		mask = $zcode_version > 5 ? 0b0000001111111111 :
			$zcode_version < 4 ? 0b0000000011111111 : 0b0000000111111111
		preload_data.each do |preload_value|
			block_address = preload_value.to_i(16) & mask
			used_block[block_address] = 1
		end
		while mapped_vmem_blocks > preload_data.length do
			cursor += 1 while cursor < total_storyfile_blocks and used_block.has_key?(cursor)
			break if cursor >= total_storyfile_blocks
			preload_data.push(cursor.to_s(16).rjust(4,'0'))
			used_block[cursor] = 1
			added += 1
		end
	end
	puts "Added #{added} best-guess vmem blocks to optimized preload." if added > 0
	
	total_length = 4 + 2 * preload_data.length
	vmem_data = [
		total_length / 256,
		total_length % 256,
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
	total_length = 4 + 2 * mapped_vmem_blocks # Size of vmem data
#	puts "total_length is #{total_length}"
	vmem_data = [
		total_length / 256,
		total_length % 256,
		mapped_vmem_blocks, # Number of suggested blocks
		mapped_vmem_blocks, # Number of preloaded blocks (May change later due to lack of space on disk)
		]
	lowbytes = []
	mapped_vmem_blocks.times do |i|
		vmem_data.push(256 - 8 * (i / 4) - 32 ) # The later the block, the higher its age
		lowbytes.push(($dynmem_blocks + i) * $VMEM_BLOCKSIZE / 256 / 2)
	end
	vmem_data += lowbytes;
end

if $target == 'mega65'
	vmem_contents = '';
else
	vmem_contents = $story_file_data[0 .. $dynmem_blocks * $VMEM_BLOCKSIZE - 1]
	vmem_data[2].times do |i|
		start_address = (vmem_data[4 + i] & $vmem_highbyte_mask) * 512 * 256 + vmem_data[4 + vmem_data[2] + i] * 512
		# puts start_address
		# puts $story_file_data.length
		vmem_contents += $story_file_data[start_address .. start_address + $VMEM_BLOCKSIZE - 1]
	end
end

############################# End of moved block

limit_vmem_data_preload(vmem_data)

if $VMEM and preload_max_vmem_blocks and preload_max_vmem_blocks > vmem_data[3] then
	puts "Max preload blocks adjusted to total vmem size, from #{preload_max_vmem_blocks} to #{vmem_data[3]}."
	preload_max_vmem_blocks = vmem_data[3]
end

# if $VMEM 
	# if mode == MODE_P
		# puts "ERROR: Tried to use build mode -P with VMEM."
		# exit 1
	# end
# elsif mode != MODE_P
	# puts "ERROR: Tried to use build mode other than -P with VMEM disabled."
	# exit 1
# end

case mode
when MODE_P
	diskimage_filename = File.join($TEMPDIR, "temp1.d64")
	error = build_P(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks)
when MODE_S1
	diskimage_filename = File.join($TEMPDIR, "temp1.d64")
	error = build_S1(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks, reserve_dir_track)
when MODE_S2
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	error = build_S2(storyname, d64_filename_1, d64_filename_2, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks, reserve_dir_track)
when MODE_D2
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	error = build_D2(storyname, d64_filename_1, d64_filename_2, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks, reserve_dir_track)
when MODE_D3
	d64_filename_1 = File.join($TEMPDIR, "temp1.d64")
	d64_filename_2 = File.join($TEMPDIR, "temp2.d64")
	d64_filename_3 = File.join($TEMPDIR, "temp3.d64")
	error = build_D3(storyname, d64_filename_1, d64_filename_2, d64_filename_3, 
		config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, extended_tracks, reserve_dir_track)
when MODE_71
	diskimage_filename = File.join($TEMPDIR, "temp1.d71")
	error = build_71(storyname, diskimage_filename, config_data.dup, vmem_data.dup, vmem_contents, preload_max_vmem_blocks, reserve_dir_track)
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
