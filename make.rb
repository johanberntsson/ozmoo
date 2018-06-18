# specialised make for Ozmoo
$is_windows = (ENV['OS'] == 'Windows_NT')

$DEBUGFLAGS = "-DDEBUG=1"
$VMFLAGS = "-DUSEVM=1"

if $is_windows then
    puts "TODO: customize for Windows"
    exit 0
else
    $X64 = "/usr/bin/x64 -cartcrt final_cartridge.crt -autostart-delay-random"
    $C1541 = "/usr/bin/c1541"
    $EXOMIZER = "exomizer/src/exomizer"
end

def play(game, filename, path, ztype, use_compression, d64_file, dynmem_file)
    if use_compression then
        compression = "-DDYNMEM_ALREADY_LOADED=1"
    else
        compression = ""
    end
    system("acme #{compression} -D#{ztype}=1 #{$DEBUGFLAGS} #{$VMFLAGS} --cpu 6510 --format cbm -l acme_labels.txt --outfile ozmoo ozmoo.asm")
    system("cp #{d64_file} #{game}.d64")
    if use_compression then
        storystart = `grep story_start acme_labels.txt | sed 's/[^0-9]//g' | sed 's/^/ibase=16;/' | bc`.strip
        system("#{$EXOMIZER} sfx basic ozmoo #{dynmem_file},#{storystart} -o ozmoo_zip")
        system("#{$C1541} -attach #{game}.d64 -write ozmoo_zip ozmoo")
    else
        system("#{$C1541} -attach #{game}.d64 -write ozmoo ozmoo")
    end
    system("#{$X64} #{game}.d64")
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


