# specialised make for Ozmoo

require 'FileUtils'

$is_windows = (ENV['OS'] == 'Windows_NT')

$DEBUGFLAGS = "-DDEBUG=1"
$VMFLAGS = "-DUSEVM=1"

if $is_windows then
    $X64 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\x64.exe -cartcrt final_cartridge.crt -autostart-delay-random"
    $C1541 = "C:\\ProgramsWoInstall\\WinVICE-3.1-x64\\c1541.exe"
    $EXOMIZER = "C:\\ProgramsWoInstall\\Exomizer-3.0.0\\win32\\exomizer.exe"
else
    $X64 = "/usr/bin/x64 -cartcrt final_cartridge.crt -autostart-delay-random"
    $C1541 = "/usr/bin/c1541"
    $EXOMIZER = "exomizer/src/exomizer"
end

def get_story_start(label_file_name)
	File.open(label_file_name).each do |line|
		next unless $_ =~ /story_start\s*=\s*\$([0-9a-f]{4})/i;
		return $1.to_i(16)
	end
end

def play(game, filename, path, ztype, use_compression, d64_file, dynmem_file)
    if use_compression then
        $COMPRESSIONFLAGS = "-DDYNMEM_ALREADY_LOADED=1"
    else
        $COMPRESSIONFLAGS = ""
    end
    cmd = "acme #{$COMPRESSIONFLAGS} -D#{ztype}=1 #{$DEBUGFLAGS} #{$VMFLAGS} --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm"
    ret = system(cmd)
    exit 0 if !ret
	ret = FileUtils.copy_file("#{d64_file}", "#{game}.d64")
#    cmd = "cp #{d64_file} #{game}.d64"
#    ret = system(cmd)
#    exit 0 if !ret
    if use_compression then
        storystart = get_story_start('acme_labels.txt');
        system("#{$EXOMIZER} sfx basic ozmoo #{dynmem_file},#{storystart} -o ozmoo_zip")
        system("#{$C1541} -attach #{game}.d64 -write ozmoo_zip ozmoo")
    else
        system("#{$C1541} -attach #{game}.d64 -write ozmoo ozmoo")
    end
    system("#{$X64} #{game}.d64")
		puts "Hllx"
		puts $is_windows
		puts "#{$X64} #{game}.d64"

end

i = 0
use_compression = false
ztype = ""
begin
    if ARGV[i] == "-c" then
        use_compression = true
        i = i + 1
    end
    raise "error" if i >= ARGV.length
    file = ARGV[i]
    i = i + 1
    if i < ARGV.length then
        ztype = ARGV[i]
        i = i + 1
    end
rescue
    puts "Usage: make.rb [-c] <file> [z3|z5]"
    puts "       -c: use compression with exomizer"
    puts "       file: path optional (e.g. infocom/zork1.z3)"
    puts "       z3|z5: zmachine version, if not clear from file"
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

d64_file = "#{path}#{File::SEPARATOR}#{game}.d64"
dynmem_file = "#{path}#{File::SEPARATOR}#{game}.dynmem"
if !File.exists? d64_file then
    puts "#{d64_file} not found"
    exit 0
end
if !File.exists?(dynmem_file) && use_compression == true then
    use_compression = false
    puts "#{dynmem_file} not found, compression disabled (push enter)"
    STDIN.getc
end

play(game, filename, path, ztype.upcase, use_compression, d64_file, dynmem_file)

exit 0


