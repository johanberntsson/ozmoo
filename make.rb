# specialised make for Ozmoo

require 'FileUtils'

$PRINT_DISK_MAP = false # Set to true to print which blocks are allocated
$DEBUGFLAGS = "-DDEBUG=1 -DBENCHMARK=1 -DVMEM_OPTIMIZE_x=1 -DTRACE_FLOPPY_x=1 -DTRACE_VM_x=1"
$VMFLAGS = "-DALLRAM=1 -DUSEVM=1 -DSMALLBLOCK=1 -DVMEM_CLOCK=1"

MODE_S1 = 1
MODE_S2 = 2
MODE_D2 = 3
MODE_D3 = 4

mode = MODE_S1

$vmem_blocksize = ($VMFLAGS =~ /\s-DSMALLBLOCK=\d+/ ? 512 : 1024)
$ZEROBYTE = 0.chr

$is_windows = (ENV['OS'] == 'Windows_NT')

if $is_windows then
#    $X64 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\x64.exe -cartcrt final_cartridge.crt -autostart-delay-random"
    $X64 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\x64.exe -autostart-warp -autostart-delay-random"
    $C1541 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\c1541.exe"
    $EXOMIZER = "C:\\ProgramsWoInstall\\Exomizer-3.0.0\\win32\\exomizer.exe"
else
    $X64 = "/usr/bin/x64 -cartcrt final_cartridge.crt -autostart-delay-random"
    $C1541 = "/usr/bin/c1541"
    $EXOMIZER = "exomizer/src/exomizer"
end



################################## create_d64.rb
# copies zmachine story data (*.z3, *.z5 etc.) to a Commodore 64 floppy (*.d64)

class D64_image
	def initialize(disk_title, d64_filename, is_boot_disk)
		@disk_title = disk_title
		@d64_filename = d64_filename
		@is_boot_disk = is_boot_disk

		@tracks = 40 # 35 or 40 are useful options
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
		
		# preallocate sectors
		story_data_length = $story_file_data.length - $story_file_cursor
		num_sectors = [($story_file_data.length.to_f / 256).ceil, max_story_blocks].min
		for track in 1 .. @tracks do
			print "#{track}:" if $PRINT_DISK_MAP
			first_story_sector = 0 + 
				(track == 18 ? @skip_blocks_on_18 : 0) + 
				(track == @config_track ? @skip_blocks_on_config_track : 0)
			last_story_sector = -1
			for sector in 0 .. get_track_length(track) - 1 do
				print " #{sector}" if $PRINT_DISK_MAP
				if @is_boot_disk && track == @config_track && sector < 2 then
					allocate_sector(track, sector)
				elsif (track != 18 || sector >= @skip_blocks_on_18) &&
						(!@is_boot_disk || track != @config_track || sector >= @skip_blocks_on_config_track) &&
						num_sectors > 0 then
					allocate_sector(track, sector)
					add_story_block(track, sector)
					last_story_sector = sector
					@free_blocks -= 1
					num_sectors -= 1
				end
			end
			if last_story_sector >= first_story_sector then
				@config_track_map.push 32 * first_story_sector + last_story_sector - first_story_sector + 1
			else
				@config_track_map.push 0
			end
			puts if $PRINT_DISK_MAP
		end
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



def get_story_start(label_file_name)
	File.open(label_file_name).each do |line|
		return $1.to_i(16) if line =~ /\tstory_start\t=\s*\$(\w{3,4})\b/;
	end
	return 0
end

def build(game, filename, path, ztype, use_compression, d64_file, dynmem_file)
    if use_compression then
        $COMPRESSIONFLAGS = "-DDYNMEM_ALREADY_LOADED=1"
    else
        $COMPRESSIONFLAGS = ""
    end
    cmd = "acme #{$COMPRESSIONFLAGS} -D#{ztype}=1 #{$DEBUGFLAGS} #{$VMFLAGS} --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm"
	puts cmd
    ret = system(cmd)
    exit 0 if !ret
	ret = FileUtils.cp("#{d64_file}", "#{game}.d64")
#    cmd = "cp #{d64_file} #{game}.d64"
#    ret = system(cmd)
#    exit 0 if !ret
    if use_compression then
        storystart = get_story_start('acme_labels.txt');
		exomizer_cmd = "#{$EXOMIZER} sfx basic -B -X \"lda $0400,x sta $d020\" ozmoo #{dynmem_file},#{storystart} -o ozmoo_zip"
		puts exomizer_cmd
        system(exomizer_cmd)
        system("#{$C1541} -attach #{game}.d64 -write ozmoo_zip ozmoo")
    else
        system("#{$C1541} -attach #{game}.d64 -write ozmoo ozmoo")
    end
end

def play(filename)
	puts "#{$X64} #{filename}"
    system("#{$X64} #{filename}")
end

def print_usage_and_exit
    puts "Usage: make.rb [z3|z4|z5|z8] [-S1] [-c] [-i <ifile>] [-p] <file>"
    puts "       -z3|-z4|-z5|-z8: zmachine version, if not clear from filename"
    puts "       -S1: specify build mode. Defaults to S1. Read about build modes in documentation folder."
    puts "       -c: use compression with exomizer"
    puts "       -i: read initial caching data from ifile"
    puts "       -p: play game if build succeeds"
    puts "       filename: path optional (e.g. infocom/zork1.z3)"
    exit 0
end

i = 0
use_compression = false
ztype = ""
await_initcachefile = false
initcachefile = nil
auto_play = false
begin
	while i < ARGV.length
		if await_initcachefile then
			await_initcachefile = false
			initcachefile = ARGV[i]
		elsif ARGV[i] == "-p" then
			auto_play = true
		elsif ARGV[i] == "-c" then
			use_compression = true
		elsif ARGV[i] =~ /^-S1$/i then
			mode = MODE_S1
		elsif ARGV[i] =~ /^-i$/i then
			await_initcachefile = true
		elsif ARGV[i] =~ /^-Z[3-5]$/i then
			ztype = ARGV[i].downcase
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
		exit 0
	end
rescue
	print_usage_and_exit()
end

print_usage_and_exit() if await_initcachefile

initcache_data = nil
if initcachefile then
	initcache_raw_data = File.read(initcachefile)
	vmem_type = $VMFLAGS =~ /-DVMEM_CLOCK=\d/ ? "clock" : "queue"
	if initcache_raw_data =~ /\$\$\$#{vmem_type}\n(([0-9a-f]{4}:\n?)+)\$\$\$/
		initcache_data = $1.gsub(/\n/, '').gsub(/:$/,'').split(':')
		puts "#{initcache_data.length} blocks found for initial caching."
	else
		puts "No data found for initial caching (for vmem type \"#{vmem_type}\")."
		exit 0
	end
end

# divide file into path, filename, extension (if possible)
path = File.dirname(file)
extension = File.extname(file)
filename = File.basename(file)
game = File.basename(file, extension)
if !extension.empty?
    ztype = extension[1..-1]
end

if extension.empty? then
    puts "ERROR: cannot figure ut zmachine version. Please specify"
    exit 0
end

# if path.empty? || path.length == 1 then
	# puts "ERROR: empty path"
	# exit 0
# end

d64_file = "temp1.d64"
dynmem_file = "temp.dynmem"

begin
	$story_file_data = IO.binread(file)
	$story_file_data += $ZEROBYTE * (1024 - ($story_file_data.length % 1024))   
	$story_file_cursor = 0
rescue
	puts "ERROR: Can't open #{file} for reading"
	exit 0
end


# save dynmem as separate file
begin
	dynmem_filehandle = File.open(dynmem_file, "wb")
rescue
	puts "ERROR: Can't open #{dynmem_file} for writing"
	exit 0
end

# check header.high_mem_start (size of dynmem + statmem)
high_mem_start = $story_file_data[4 .. 5].unpack("n")[0]

# check header.static_mem_start (size of dynmem)
static_mem_start = $story_file_data[14 .. 15].unpack("n")[0]

# get dynmem size (in 1kb blocks)
$dynmem_size = 1024 * ((high_mem_start + 512)/1024)

dynmem = $story_file_data[0 .. $dynmem_size - 1]
# Assume memory starts at $3800
dynmem_filehandle.write([0x00,0x38].pack("CC"))
dynmem_filehandle.write(dynmem)
dynmem_filehandle.close



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
		use_compression ? initcache_data.length : 0, # Number of preloaded blocks
		]
	lowbytes = []
	initcache_data.each do |block|
		vmem_data.push(block[0 .. 1].to_i(16))
		lowbytes.push(block[2 .. 3].to_i(16))
	end
	vmem_data += lowbytes;
else # No initcache data available
	dynmem_vmem_blocks = $dynmem_size / $vmem_blocksize
	if $DEBUGFLAGS =~ /-DBENCHMARK=\d/ then
		all_vmem_blocks = dynmem_vmem_blocks
	else
		all_vmem_blocks = 52 * 1024 / $vmem_blocksize
	end
	vmem_data = [
		3 + 2 * all_vmem_blocks, # Size of vmem data
		all_vmem_blocks, # Number of suggested blocks
		use_compression ? dynmem_vmem_blocks : 0, # Number of preloaded blocks
		]
	lowbytes = []
	all_vmem_blocks.times do |i|
		vmem_data.push(i <= dynmem_vmem_blocks ? 0xc0 : 0x80)
		lowbytes.push(i * $vmem_blocksize / 256)
	end
	vmem_data += lowbytes;
end

case mode
when MODE_S1
	max_story_blocks = 9999
	disk = D64_image.new(game, d64_file, true) # game file to read from, d64 file to create, is boot disk?
	disk.add_story_data(max_story_blocks)
	if $story_file_cursor < $story_file_data.length
		puts "ERROR: The whole story doesn't fit on the disk. Please try another build mode."
		exit 0
	end
	
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
	# Add loader and terp to boot / play disk
	build(game, filename, path, ztype.upcase, use_compression, d64_file, dynmem_file)
	puts "Successfully built game as #{game}.d64"
	if auto_play then 
		play("#{game}.d64")
	end
else
	puts "Unsupported build mode. Currently supported modes: S1."
end

exit 0


