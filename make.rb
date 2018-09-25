# specialised make for Ozmoo

require 'fileutils'

$is_windows = (ENV['OS'] == 'Windows_NT')

if $is_windows then
	# Paths on Windows
    $X64 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\x64.exe -autostart-warp" # -autostart-delay-random"
    $C1541 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\c1541.exe"
    $EXOMIZER = "C:\\ProgramsWoInstall\\Exomizer-3.0.0\\win32\\exomizer.exe"
    $ACME = "acme.exe"
else
	# Paths on Linux
    $X64 = "/usr/bin/x64 -autostart-delay-random"
    $C1541 = "/usr/bin/c1541"
    $EXOMIZER = "exomizer/src/exomizer"
    $ACME = "acme"
end

$PRINT_DISK_MAP = false # Set to true to print which blocks are allocated

# Typically, none of these flags should be enabled.
$GENERALFLAGS = [
#	'OLD_MORE_PROMPT',
#	'OLDANDWORKING',
#	'SWEDISH_CHARS',
]

# For a production build, none of these flags should be enabled.
# Note: PREOPT is not part of this list, since it is controlled by the -o commandline switch
$DEBUGFLAGS = [
#	'DEBUG', # If this is commented out, the other debug flags are ignored.
#	'BENCHMARK',
#	'TRACE_FLOPPY',
#	'TRACE_VM'
#	'PRINT_SWAPS',
#	'TRACE',
#	'TRACE_ATTR',
#	'TRACE_FLOPPY_VERBOSE',
#	'TRACE_FROTZ_ATTR',
#	'TRACE_FROTZ_OBJ',
#	'TRACE_FROTZ_PROP',
#	'TRACE_FROTZ_TREE',
#	'TRACE_OBJ',
#	'TRACE_PRINT_ARRAYS',
#	'TRACE_PROP',
#	'TRACE_READTEXT',
#	'TRACE_SHOW_DICT_ENTRIES',
#	'TRACE_TOKENISE',
#	'TRACE_TREE',
#	'TRACE_VM_PC',
#	'TRACE_WINDOW',
]

# Typically, all of these flags should be enabled.
$VMFLAGS = [
	'USEVM', # If this is commented out, the other virtual memory flags are ignored.
	'ALLRAM',
	'SMALLBLOCK',
	'VMEM_CLOCK',
]

MODE_S1 = 1
MODE_S2 = 2
MODE_D2 = 3
MODE_D3 = 4

mode = MODE_S1

$VMEM_BLOCKSIZE = $VMFLAGS.include?('SMALLBLOCK') ? 512 : 1024
$ZEROBYTE = 0.chr

$ALLRAM = $VMFLAGS.include?('ALLRAM')

$TEMPDIR = File.join(__dir__, 'temp')
Dir.mkdir($TEMPDIR) unless Dir.exist?($TEMPDIR)

$labels_file = File.join($TEMPDIR, 'acme_labels.txt')
$ozmoo_file = File.join($TEMPDIR, 'ozmoo')
$zip_file = File.join($TEMPDIR, 'ozmoo_zip')
$compmem_filename = File.join($TEMPDIR, 'compmem.tmp')

################################## create_d64.rb
# copies zmachine story data (*.z3, *.z5 etc.) to a Commodore 64 floppy (*.d64)

class D64_image
	def initialize(disk_title, d64_filename, is_boot_disk, forty_tracks)
		@disk_title = disk_title
		@d64_filename = d64_filename
		@is_boot_disk = is_boot_disk

		@tracks = forty_tracks ? 40 : 35 # 35 or 40 are useful options
		@skip_blocks_on_18 = 2 # 1: Just skip BAM, 2: Skip BAM and 1 directory block, 19: Skip entire track
		@config_track = 19
		@skip_blocks_on_config_track = (@is_boot_disk ? 2 : 0)
		@free_blocks = 664 + 19 - @skip_blocks_on_18 + 
			(@tracks > 35 ? 17 * @tracks - 35 : 0) -
			@skip_blocks_on_config_track
		@d64_file = nil
		
		@config_track_map = []
		@contents = Array.new(@tracks > 35 ? 196608 : 174848, 0)
		@track_offset = [0,
			0,21,42,63,84,
			105,126,147,168,189,
			210,231,252,273,294,
			315,336,357,376,395,
			414,433,452,471,490,
			508,526,544,562,580,
			598,615,632,649,666,
			683,700,717,734,751,
			768]
			
		# BAM
		@track1800 = [
			# $16500 = 91392 = 357 (18,0)
			0x12,0x01, # track/sector
			0x41, # DOS version
			0x00, # unused
			# mark track 1-16, sector 1-16 as reserved for story files
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
		
		puts "Creating disk image..."

		# Set disk title
		@track1800[0x90 .. 0x9f] = Array.new(0x10, 0xa0)
		[disk_title.length, 0x10].min.times do |charno|
			code = disk_title[charno].ord
			code &= 0xdf if code >= 0x61 and code <= 0x7a
			@track1800[0x90 + charno] = code 
		end
		

	end # initialize

	def free_blocks
		@free_blocks
	end
	
	def add_story_data(max_story_blocks)
		$INTERLEAVE = 4
	
		# preallocate sectors
		story_data_length = $story_file_data.length - $story_file_cursor
		num_sectors = [number_of_sectors($story_file_data), max_story_blocks].min
		if @is_boot_disk then
			allocate_sector(@config_track, 0)
			allocate_sector(@config_track, 1)
		end
		for track in 1 .. @tracks do
			print "#{track}:" if $PRINT_DISK_MAP
			if num_sectors > 0 then
				first_story_sector = 0 + 
					(track == 18 ? @skip_blocks_on_18 : 0) + 
					(track == @config_track ? @skip_blocks_on_config_track : 0)
				reserved_sectors = (@is_boot_disk && track == @config_track) ? 2 : (track == 18 ? @skip_blocks_on_18 : 0)
				sector_count = get_track_length(track)
				if sector_count - reserved_sectors > num_sectors
					sector_count = num_sectors + reserved_sectors
				end
				track_map = Array.new(sector_count, 0)
				reserved_sectors.times do |i|
					track_map[i] = 1
				end
				free_sectors_in_track = sector_count - reserved_sectors
				last_story_sector = sector_count - 1
	#	Find right sector.
	#		1. Start at 0
	#		2. Find next free sector
	#		3. Decrease blocks to go. If < 0, we are done
	#		4. Mark sector as used.
	#		5. Add interleave, go back to 2	
				sector = 0
				free_sectors_in_track.times do
					while track_map[sector] != 0
						sector = (sector + 1) % sector_count
					end
					track_map[sector] = 1
					allocate_sector(track, sector)
					add_story_block(track, sector)
					@free_blocks -= 1
					num_sectors -= 1
					sector = (sector + $INTERLEAVE) % sector_count
				end
			
				# for sector in 0 .. get_track_length(track) - 1 do
					# print " #{sector}" if $PRINT_DISK_MAP
					# if @is_boot_disk && track == @config_track && sector < 2 then
						# allocate_sector(track, sector)
					# elsif (track != 18 || sector >= @skip_blocks_on_18) &&
							# (!@is_boot_disk || track != @config_track || sector >= @skip_blocks_on_config_track) &&
							# num_sectors > 0 then
						# allocate_sector(track, sector)
						# add_story_block(track, sector)
						# last_story_sector = sector
						# @free_blocks -= 1
						# num_sectors -= 1
					# end
				# end
				@config_track_map.push 32 * first_story_sector + last_story_sector - first_story_sector + 1
#				end
			else
				@config_track_map.push 0
			end # if num_sectors > 0
			puts if $PRINT_DISK_MAP
		end # for track
#		puts num_sectors.to_s
		add_1800()
		add_1801()

		@config_track_map = @config_track_map.reverse.drop_while{|i| i==0}.reverse # Drop trailing zero elements

		@free_blocks
	end

	def config_track_map
		@config_track_map
	end
	
	def set_config_data(data)
		if !@is_boot_disk then
			puts "ERROR: Tried to save config data on a non-boot disk."
			exit 0
		elsif !(data.is_a?(Array)) or data.length > 512 then
			puts "ERROR: Tried to save config data on a non-boot disk."
			exit 0
		end
		@contents[@track_offset[@config_track] * 256 .. @track_offset[@config_track] * 256 + data.length - 1] = data
		
	end
	
	def save
		begin
			d64_file = File.open(@d64_filename, "wb")
		rescue
			puts "ERROR: Can't open #{@d64_filename} for writing"
			exit 0
		end
		d64_file.write @contents.pack("C*")
		d64_file.close
	end

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

	def get_track_length(track)
		@track_offset[track + 1] - @track_offset[track]
	end

	def add_1800()
		@contents[@track_offset[18] * 256 .. @track_offset[18] * 256 + 255] = @track1800
	end

	def add_1801()
		@contents[@track_offset[18] * 256 + 256] = 0 
		@contents[@track_offset[18] * 256 + 257] = 0xff 
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
end # class D64_image

################################## END create_d64.rb

def build_interpreter(preload_vm_blocks)
	generalflags = $GENERALFLAGS.empty? ? '' : " -D#{$GENERALFLAGS.join('=1 -D')}=1"
	debugflags = $DEBUGFLAGS.empty? ? '' : " -D#{$DEBUGFLAGS.join('=1 -D')}=1"
	vmflags = $VMFLAGS.empty? ? '' : " -D#{$VMFLAGS.join('=1 -D')}=1"
    compressionflags = preload_vm_blocks ? ' -DDYNMEM_ALREADY_LOADED=1' : ''

    cmd = "#{$ACME} -D#{$ztype}=1#{generalflags}#{vmflags}#{debugflags}#{compressionflags} --cpu 6510 --format cbm -l \"#{$labels_file}\" --outfile \"#{$ozmoo_file}\" ozmoo.asm"
	puts cmd
    ret = system(cmd)
    exit 0 unless ret
	set_story_start($labels_file);
end

def number_of_sectors(array)
	(array.length.to_f / 256).ceil
end

def set_story_start(label_file_name)
	$storystart = 0
	File.open(label_file_name).each do |line|
		$storystart = $1.to_i(16) if line =~ /\tstory_start\t=\s*\$(\w{3,4})\b/;
	end
end

def build_specific_boot_file(vmem_preload_blocks, vmem_contents)
	compmem_clause = (vmem_preload_blocks > 0) ? " \"#{$compmem_filename}\"@#{$storystart},0,#{vmem_preload_blocks * $VMEM_BLOCKSIZE}" : ''

#	exomizer_cmd = "#{$EXOMIZER} sfx basic -B -X \'LDA $D012 STA $D020 STA $D418\' ozmoo #{$compmem_filename},#{$storystart} -o ozmoo_zip"
	exomizer_cmd = "#{$EXOMIZER} sfx basic -B -x1 \"#{$ozmoo_file}\"#{compmem_clause} -o \"#{$zip_file}\""
	puts exomizer_cmd
	system(exomizer_cmd)
#	puts "Building with #{vmem_preload_blocks} blocks gives file size #{File.size($zip_file)}."
	File.size($zip_file)
end

def build_boot_file(vmem_preload_blocks, vmem_contents, free_blocks)
	if vmem_preload_blocks > 0 then
		begin
			compmem_filehandle = File.open($compmem_filename, "wb")
		rescue
			puts "ERROR: Can't open #{$compmem_filename} for writing"
			exit 0
		end
#		compmem_filehandle.write([$storystart].pack("v"))
		compmem_filehandle.write(vmem_contents[0 .. vmem_preload_blocks * $VMEM_BLOCKSIZE - 1])
		compmem_filehandle.close
	end

	max_file_size = free_blocks * 254
	puts "Max file size is #{max_file_size}."
	return vmem_preload_blocks if build_specific_boot_file(vmem_preload_blocks, vmem_contents) <= max_file_size
	return -1 if build_specific_boot_file(0, vmem_contents) > max_file_size
	
	done = false
	max_ok_blocks = 0 # Signal that we don't know if even 0 blocks is possible
	min_failed_blocks = vmem_preload_blocks
	actual_blocks = -1
	last_build = -2
	until done
		if min_failed_blocks - max_ok_blocks < 2
			actual_blocks = max_ok_blocks
			done = true
		else
			mid = (min_failed_blocks + max_ok_blocks) / 2
#			puts "Trying #{mid} blocks..."
			size = build_specific_boot_file(mid, vmem_contents)
			last_build = mid
			if size > max_file_size then
				puts "Built #{mid} blocks, too big."
				min_failed_blocks = mid
			else
				puts "Built #{mid} blocks, ok."
				max_ok_blocks = mid
			end
		end
	end
	build_specific_boot_file(actual_blocks, vmem_contents) unless last_build == actual_blocks
	puts "Picked #{actual_blocks} blocks."
	actual_blocks
end

def add_boot_file(game, d64_file)
	ret = FileUtils.cp("#{d64_file}", "#{game}.d64")
	system("#{$C1541} -attach \"#{game}.d64\" -write \"#{$zip_file}\" story")
end

def play(filename)
	command = "#{$X64} #{filename}"
	puts command
    system(command)
end

def limit_vmem_data(vmem_data)
	vmemsize = ($ALLRAM ? 0x10000 : 0xd000) - $storystart
	if vmemsize < vmem_data[2] * $VMEM_BLOCKSIZE
		vmem_data[2] = vmemsize / $VMEM_BLOCKSIZE
	end
end

def build_S1(game, d64_file, config_data, vmem_data, vmem_contents, extended_tracks)
	max_story_blocks = 9999
	disk = D64_image.new(game, d64_file, true, extended_tracks) # game file to read from, d64 file to create, is boot disk?, forty_tracks?
	free_blocks = disk.add_story_data(max_story_blocks)
	puts "#{free_blocks} blocks free."
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 1
	end

	# Build loader + terp + preloaded vmem blocks as a file
	vmem_preload_blocks = build_boot_file(vmem_data[2], vmem_contents, free_blocks)
	if vmem_preload_blocks < 0
		puts "ERROR: The story fits on the disk, but not the loader/interpreter. Please try another build mode."
		exit 1
	end
	vmem_data[2] = vmem_preload_blocks
	
	# Add config data about boot / story disk
	disk_info_size = 11 + disk.config_track_map.length
	last_block_plus_1 = 0
	disk.config_track_map.each{|i| last_block_plus_1 += (i & 0x1f)}
	config_data += [disk_info_size, 8, last_block_plus_1 / 256, last_block_plus_1 % 256, 
		disk.config_track_map.length] + disk.config_track_map
	config_data += [128, "/".ord, " ".ord, 129, 131, 0]  # Name: "Boot / Story disk"
	config_data[4] += disk_info_size
	
	config_data += vmem_data

	#	puts config_data
	disk.set_config_data(config_data)
	disk.save()
	
	# Add loader + terp + preloaded vmem blocks file to disk
	if add_boot_file(game, d64_file) != true
		puts "ERROR: Failed to write loader/interpreter to disk."
		exit 1
	end

	puts "Successfully built game as #{game}.d64"
	nil # Signal success
end

def print_usage_and_exit
    puts "Usage: make.rb [z3|z4|z5|z8] [-S1] [-c] [-i <preloadfile>] [-o] [-p] <file>"
    puts "       -z3|-z4|-z5|-z8: zmachine version, if not clear from filename"
    puts "       -S1: specify build mode. Defaults to S1. Read about build modes in documentation folder."
    puts "       -p: preload story data into virtual memory cache to make game faster at start"
    puts "       -c: read preload config from preloadfile, previously created with -o (-c also implies -p)"
    puts "       -o: build interpreter in PREOPT (preload optimization) mode. See docs for details."
    puts "       -s: start game in Vice if build succeeds"
    puts "       -x: Use extended tracks (40 instead of 35) on 1541 disk"
    puts "       filename: path optional (e.g. infocom/zork1.z3)"
    exit 0
end

i = 0
preload_vm_blocks = false
$ztype = ""
await_initcachefile = false
initcachefile = nil
auto_play = false
optimize = false
extended_tracks = false

begin
	while i < ARGV.length
		if await_initcachefile then
			await_initcachefile = false
			initcachefile = ARGV[i]
		elsif ARGV[i] =~ /^-x$/i then
			extended_tracks = true
		elsif ARGV[i] =~ /^-o$/i then
			optimize = true
		elsif ARGV[i] =~ /^-s$/i then
			auto_play = true
		elsif ARGV[i] =~ /^-p$/i then
			preload_vm_blocks = true
		elsif ARGV[i] =~ /^-S1$/i then
			mode = MODE_S1
		elsif ARGV[i] =~ /^-c$/i then
			preload_vm_blocks = true
			await_initcachefile = true
		elsif ARGV[i] =~ /^-z[3-8]$/i then
			$ztype = ARGV[i].upcase[1..-1]
			puts $ztype
		elsif ARGV[i] =~ /^-/i then
			puts "Unknown option: " + ARGV[i]
			raise "error"
		else 
			file = ARGV[i]
		end
		i = i + 1
	end
	if !file
		raise "error"
		exit 1
	end
rescue
	print_usage_and_exit()
end

if optimize then
	if preload_vm_blocks then
		puts "-p (preload story data) can not be used with -o."
		exit 0
	end
	$DEBUGFLAGS.push('DEBUG') unless $DEBUGFLAGS.include?('DEBUG')
	$DEBUGFLAGS.push('PREOPT')
end


print_usage_and_exit() if await_initcachefile

initcache_data = nil
if initcachefile then
	initcache_raw_data = File.read(initcachefile)
	vmem_type = $VMFLAGS.include?('VMEM_CLOCK') ? "clock" : "queue"
	if initcache_raw_data =~ /\$\$\$#{vmem_type}\n(([0-9a-f]{4}:\n?)+)\$\$\$/
		initcache_data = $1.gsub(/\n/, '').gsub(/:$/,'').split(':')
		puts "#{initcache_data.length} blocks found for initial caching."
	else
		puts "No preload config data found (for vmem type \"#{vmem_type}\")."
		exit 1
	end
end

# divide file into path, filename, extension (if possible)
path = File.dirname(file)
extension = File.extname(file)
filename = File.basename(file)
game = File.basename(file, extension)
if $ztype.empty?
	if !extension.empty?
	    $ztype = extension[1..-1].upcase
	end
end
if extension.empty? then
    puts "ERROR: cannot figure out zmachine version. Please specify"
    exit 1
end

# if path.empty? || path.length == 1 then
	# puts "ERROR: empty path"
	# exit 0
# end

d64_file = File.join($TEMPDIR, "temp1.d64")
dynmem_file = "temp.dynmem"

begin
	puts "Reading file #{file}..."
	$story_file_data = IO.binread(file)
	$story_file_data += $ZEROBYTE * (1024 - ($story_file_data.length % 1024))   
	$story_file_cursor = 0
rescue
	puts "ERROR: Can't open #{file} for reading"
	exit 0
end


# check header.high_mem_start (size of dynmem + statmem)
high_mem_start = $story_file_data[4 .. 5].unpack("n")[0]

# check header.static_mem_start (size of dynmem)
static_mem_start = $story_file_data[14 .. 15].unpack("n")[0]

# get dynmem size (in 1kb blocks)
$dynmem_size = 1024 * ((high_mem_start + 512)/1024)

$story_size = $story_file_data.length

# dynmem = $story_file_data[0 .. $dynmem_size - 1]
# # Assume memory starts at $3800
# dynmem_filehandle.write([0x00,0x38].pack("CC"))
# dynmem_filehandle.write(dynmem)
# dynmem_filehandle.close



config_data = [
0, 0, 0, 0, # Game ID
10, # Number of bytes used for disk information, including this byte
2, # Number of disks, change later if wrong
# Data for save disk: 8 bytes used, device# = 8, Last story data sector + 1 = 0 tracks used for story data, name = "Save disk"
8, 8, 0, 0, 0, 130, 131, 0 
]

# Create config data for vmem
if initcache_data then
	vmem_data = [
		3 + 2 * initcache_data.length, # Size of vmem data
		initcache_data.length, # Number of suggested blocks
		preload_vm_blocks ? initcache_data.length : 0, # Number of preloaded blocks
		]
	lowbytes = []
	initcache_data.each do |block|
		vmem_data.push(block[0 .. 1].to_i(16))
		lowbytes.push(block[2 .. 3].to_i(16))
	end
	vmem_data += lowbytes;
else # No initcache data available
	dynmem_vmem_blocks = $dynmem_size / $VMEM_BLOCKSIZE
	total_vmem_blocks = $story_size / $VMEM_BLOCKSIZE
	if $DEBUGFLAGS.include?('PREOPT') then
		all_vmem_blocks = dynmem_vmem_blocks
	else
		all_vmem_blocks = [52 * 1024 / $VMEM_BLOCKSIZE, total_vmem_blocks].min()
	end
	vmem_data = [
		3 + 2 * all_vmem_blocks, # Size of vmem data
		all_vmem_blocks, # Number of suggested blocks
		preload_vm_blocks ? all_vmem_blocks : 0, # Number of preloaded blocks
		]
	lowbytes = []
	all_vmem_blocks.times do |i|
		vmem_data.push(i <= dynmem_vmem_blocks ? 0xc0 : 0x80)
		lowbytes.push(i * $VMEM_BLOCKSIZE / 256)
	end
	vmem_data += lowbytes;
end

vmem_contents = ""
vmem_data[1].times do |i|
	start_address = (vmem_data[3 + i] & 0x07) * 256 * 256 + vmem_data[3 + vmem_data[1] + i] * 256
#	puts start_address
	vmem_contents += $story_file_data[start_address .. start_address + $VMEM_BLOCKSIZE - 1]
end

build_interpreter(preload_vm_blocks)
limit_vmem_data(vmem_data)

#puts vmem_contents.length

case mode
when MODE_S1
	error = build_S1(game, d64_file, config_data.dup, vmem_data.dup, vmem_contents, extended_tracks)
	if !error and auto_play then 
		play("#{game}.d64")
	end
else
	puts "Unsupported build mode. Currently supported modes: S1."
end

exit 0


