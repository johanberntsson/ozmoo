#!/usr/bin/ruby
# converts zmachine file (*.z3, *.z5 etc.) to Commodore 64 floppy (*.d64)

# This is ugly. Ruby isn't good at handling binary data
$zerobyte = [0].pack("C")
$ffbyte = [255].pack("C")
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
    0x05,0xff,0xff,0x1f, # 16538, track 14
    0x05,0xff,0xff,0x1f, # 1653c, track 15
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
    0x44,0x45,0x4a,0x41,0x56,0x55,0xa0,0xa0,
    0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0,0xa0, # label (DEJAVU)
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
    print "*"
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
    d64_file.write $track1801.pack("CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC")
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

def add_story_data(story_file, d64_file)
    story_data_added = false
    256.times do
        if story_file.eof? then
            d64_file.write $zerobyte
        else
            story_data_added = true
            byte = story_file.read(1)
            d64_file.write byte
        end
    end
    story_data_added
end

def create_d64(story_filename, d64_filename, dynmem_filename)
    begin
        story_file = File.open(story_filename, "rb")
    rescue
        puts "ERROR: Can't open #{story_filename} for reading"
        exit 0
    end
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

    puts "Creating..."

    # preallocate sectors
    story_file_length = File.size?(story_filename)
    num_sectors = (story_file_length / 256)
    num_sectors = num_sectors + 1 if (story_file_length % 256) > 0
    for track in 1..35 do
        print "#{track}:"
        for sector in 1.. get_track_length(track) do
            print " #{sector}"
            if track != 18 && sector <= 16 && num_sectors > 0 then
                allocate_sector(track, sector)
                num_sectors = num_sectors - 1
            end
        end
        puts
    end

    # check header.high_mem_start (size of dynmem + statmem)
    # minform: $1768 = 5992 (23, 104)
    story_file.read(4) # skip version and flags1
    high_mem_start = story_file.read(2).unpack("n")[0]
    
    # check header.static_mem_start (size of dynmem)
    story_file.read(8) # skip until this entry
    static_mem_start = story_file.read(2).unpack("n")[0]

    # get dynmem size (in 1kb blocks)
    #dynmem_size = 1024 * ((static_mem_start + 512)/1024)
    dynmem_size = 1024 * ((high_mem_start + 512)/1024)

    # save dynmem as separate file
    story_file.rewind
    dynmem = story_file.read(dynmem_size)
    if !dynmem_filename.nil? then
        # Assume memory starts at $3800
        dynmem_file.write([0x00,0x38].pack("CC"))
        dynmem_file.write(dynmem)
        dynmem_file.close
    end

    # now save the sectors
    story_file.rewind
    for track in 1..35 do
        for sector in 1.. get_track_length(track) do
            if track == 18 && sector == 1 then
                add_1801(d64_file)
            elsif track == 18 && sector == 2 then
                add_1802(d64_file)
            elsif track == 18 then
                add_zeros(d64_file)
            elsif sector <= 16 then
                add_story_data(story_file, d64_file)
            else
                add_zeros(d64_file)
            end
        end
    end
    story_file.close
    d64_file.close

end

if ARGV.length < 2 then
    puts "Usage: create_d64.rb <zmachine file> <d64 file> [<dynmem file>]"
    exit 0
end
story_filename = ARGV[0]
d64_filename = ARGV[1]
dynmem_filename = ARGV[2] # nil if not given

create_d64(story_filename, d64_filename, dynmem_filename)
puts "Done!"
exit 0

