# specialised make for Ozmoo

require 'FileUtils'

$print_disk_map = false # Set to true to print which blocks are allocated
$DEBUGFLAGS = "-DDEBUG=1 -DVMEM_OPTIMIZE=1"
$VMFLAGS = "-DALLRAM=1 -DUSEVM=1 -DSMALLBLOCK=1 -DVMEM_CLOCK=1"

MODE_S1 = 1
MODE_S2 = 2
MODE_D2 = 3
MODE_D3 = 4

mode = MODE_S1

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

$zerobyte = 0.chr
$ffbyte = 255.chr

# Hard coded BAM, to be replaced with proper allocation
$track1801 = [
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
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
]

def allocate_sector(track, sector)
    print "*" if $print_disk_map
    index1 = 4 * track
    index2 = 4 * track + 1 + ((sector - 1) / 8)
    # adjust number of free sectors
    $track1801[index1] = $track1801[index1] - 1
    # allocate sector
    index3 = 255 - 2**(7 - ((sector - 1) % 8))
    $track1801[index2] = $track1801[index2] & index3
end

def get_track_length(track)
    if track <= 17 then
        sectors = 21
    elsif track <= 24 then
        sectors = 19
    elsif track <= 30 then
        sectors = 18
    else
        sectors = 17
    end
    sectors
end

def add_1801(d64_file)
    d64_file.write $track1801.pack("C*")
end

def add_1802(d64_file)
    d64_file.write $zerobyte 
    d64_file.write $ffbyte 
    254.times do
        d64_file.write $zerobyte 
    end
end

def add_zeros(d64_file)
    256.times do
        d64_file.write $zerobyte 
    end
end

def add_story_data(d64_file)
    story_data_added = false
	if $story_file_data.length > $story_file_cursor + 1
		d64_file.write $story_file_data[$story_file_cursor .. $story_file_cursor + 255]
		$story_file_cursor += 256
        story_data_added = true
	else
		add_zeros(d64_file)
	end
    story_data_added
end

def create_d64(disk_title, d64_filename, dynmem_filename, max_story_blocks)
    begin
        d64_file = File.open(d64_filename, "wb")
    rescue
        puts "ERROR: Can't open #{d64_filename} for writing"
        story_file.close
        exit 0
    end
    if !dynmem_filename.nil? then
        begin
            dynmem_file = File.open(dynmem_filename, "wb")
        rescue
            puts "ERROR: Can't open #{dynmem_filename} for writing"
            story_file.close
            d64_file.close
            exit 0
        end
    end

    puts "Creating disk image..."

	# Set disk title
	$track1801[0x90 .. 0x9f] = Array.new(0x10, 0xa0)
	[disk_title.length, 0x10].min.times do |charno|
		code = disk_title[charno].ord
		code &= 0xdf if code >= 0x61 and code <= 0x7a
		$track1801[0x90 + charno] = code 
	end
	
    # preallocate sectors
    story_data_length = $story_file_data.length - $story_file_cursor
    num_sectors = [($story_file_data.length.to_f / 256).ceil, max_story_blocks].min
    for track in 1..35 do
        print "#{track}:" if $print_disk_map
        for sector in 1.. get_track_length(track) do
            print " #{sector}" if $print_disk_map
            if track != 18 && sector <= 16 && num_sectors > 0 then
                allocate_sector(track, sector)
                num_sectors = num_sectors - 1
            end
        end
        puts if $print_disk_map
    end

    # check header.high_mem_start (size of dynmem + statmem)
    # minform: $1768 = 5992 (23, 104)
    high_mem_start = $story_file_data[4 .. 5].unpack("n")[0]
    
    # check header.static_mem_start (size of dynmem)
    static_mem_start = $story_file_data[14 .. 15].unpack("n")[0]

    if !dynmem_filename.nil? then
		# save dynmem as separate file

		# get dynmem size (in 1kb blocks)
		dynmem_size = 1024 * ((high_mem_start + 512)/1024)

		dynmem = $story_file_data[0 .. dynmem_size - 1]
        # Assume memory starts at $3800
        dynmem_file.write([0x00,0x38].pack("CC"))
        dynmem_file.write(dynmem)
        dynmem_file.close
    end

    # now save the sectors
    for track in 1..35 do
        for sector in 1.. get_track_length(track) do
            if track == 18 && sector == 1 then
                add_1801(d64_file)
            elsif track == 18 && sector == 2 then
                add_1802(d64_file)
            elsif track == 18 then
                add_zeros(d64_file)
            elsif sector <= 16 then
                add_story_data(d64_file)
            else
                add_zeros(d64_file)
            end
        end
    end
    d64_file.close

end

################################## END create_d64.rb



def get_story_start(label_file_name)
	File.open(label_file_name).each do |line|
		return $1.to_i(16) if line =~ /\tstory_start\t=\s*\$(\w{3,4})\b/;
	end
	return 0
end

def play(game, filename, path, ztype, use_compression, d64_file, dynmem_file)
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
	puts "#{$X64} #{game}.d64"
    system("#{$X64} #{game}.d64")
end

i = 0
use_compression = false
ztype = ""
begin
	while i < ARGV.length
		if ARGV[i] == "-c" then
			use_compression = true
		elsif ARGV[i] =~ /^-S1$/i then
			mode = MODE_S1
		elsif ARGV[i] =~ /^-Z\d$/i then
			ztype = ARGV[i].downcase
		elsif ARGV[i] =~ /^-/i then
			puts "Unknown option: " + ARGV[i]
			raise "error"
		else 
			file = ARGV[i]
		end
		i = i + 1
	end
rescue
    puts "Usage: make.rb [-S1] [-c] <file> [z3|z5]"
    puts "       -S1: specify build mode. Defaults to S1. Read about build modes in documentation folder."
    puts "       -c: use compression with exomizer"
    puts "       filename: path optional (e.g. infocom/zork1.z3)"
    puts "       -z3|-z5: zmachine version, if not clear from filename"
    exit 0
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

if path.empty? || path.length == 1 then
    file = `dir *#{File::SEPARATOR}#{filename}`
    if path.empty? then
        puts "ERROR: empty path"
        exit 0
    end
    path = File.dirname(file)
end

d64_file = "temp1.d64"
dynmem_file = "temp.dynmem"

begin
	$story_file_data = IO.binread(file)
	$story_file_data += $zerobyte * (1024 - ($story_file_data.length % 1024))   
	$story_file_cursor = 0
rescue
	puts "ERROR: Can't open #{file} for reading"
	exit 0
end

case mode
when MODE_S1
	max_story_blocks = 9999
	create_d64(game, d64_file, dynmem_file, max_story_blocks)
	play(game, filename, path, ztype.upcase, use_compression, d64_file, dynmem_file)
else
	puts "Unsupported build mode. Currently supported modes: S1."
end

# if !File.exists? d64_file then
    # puts "#{d64_file} not found"
    # exit 0
# end
# if !File.exists?(dynmem_file) && use_compression == true then
    # use_compression = false
    # puts "#{dynmem_file} not found, compression disabled (push enter)"
    # STDIN.getc
# end


exit 0


