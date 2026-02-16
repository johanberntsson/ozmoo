require 'fileutils'

if ARGV.length != 3
	puts "Usage: ruby memcheck.rb storyfile labels c64_ram_image"
	exit 1
end

$story_data = File.binread ARGV[0]
$zcode_version = $story_data[0].ord
$statmem_start = 256 * $story_data[0xe].ord + $story_data[0xf].ord

if $story_data.length > 512*1024 or $zcode_version < 1 or $zcode_version > 8
	"Argument 1 doesn't seem to be a valid Z-code file."
	exit 1
end

$labels = {}

File.foreach ARGV[1] do |line|
	if line =~ /^\s*([^\t ]+)\s*=\s*\$([0-9a-f]{1,7})/
		$labels[$1] = $2.to_i(16)
	end
end

if $labels.length < 600
	print "Label count < 600. This can't be an ACME label file for an Ozmoo build."
	exit 1
end

$ram_data = File.binread ARGV[2]

if $ram_data.length == 65538
	$ram_data = $ram_data[2 ..]
elsif $ram_data.length != 65536
	"RAM dump file has the wrong length (should be 64 KB)."
	exit 1
end

$vmap_z_l = $labels['vmap_z_l']
$vmap_z_h = $labels['vmap_z_h']
$vmap_first_ram_page = $labels['vmap_first_ram_page']
$vmap_max_entries = $labels['vmap_max_entries']
$vmap_used_entries = $labels['vmap_used_entries']
$vmem_highbyte_mask = $labels['vmem_highbyte_mask']
$vmem_cache_start = $labels['vmem_cache_start']
$vmem_cache_count = $labels['vmem_cache_count']
$vmem_cache_page_index = $labels['vmem_cache_page_index']

#$vmap_mask = 0x03ff
#$vmap_mask = 0x01ff if $zcode_version < 4
#$vmap_mask = 0x07ff if $zcode_version > 5

puts "Static memory starts at #{$statmem_start}"

$ram_data[$vmap_used_entries].ord.times do |i|
	zcode_address = 2 * 256 * 
		(256 * ($ram_data[$vmap_z_h + i].ord & $vmem_highbyte_mask) +
			$ram_data[$vmap_z_l + i].ord)
	zcode_contents = $story_data[zcode_address .. (zcode_address + 511)]
	ram_address = 256 * ($ram_data[$vmap_first_ram_page].ord + 2 * i)
	ram_contents = $ram_data[ram_address .. (ram_address + 511)]
	if ram_contents.length != 512 or
			zcode_contents.length != 512 or
			ram_contents != zcode_contents then
		puts "VMAP block #{i}, RAM address #{ram_address}, Z-code address #{zcode_address}: Incorrect contents"
	end
end

puts "\n#{$ram_data[$vmap_used_entries].ord} VMAP blocks checked."

print "\n"

$vmem_cache_count.times do |i|
	cache_page_address = $vmem_cache_start + 256 * i
	ram_address = 256 * $ram_data[$vmem_cache_page_index + i].ord
	if ram_address > 0
		puts "Cache page #{i} contains page $#{(ram_address / 256).to_s(16)}"
		cache_contents = $ram_data[cache_page_address .. (cache_page_address + 255)]
		ram_contents = $ram_data[ram_address .. (ram_address + 255)]
		if cache_contents.length != 256 or
				ram_contents.length != 256 or
				cache_contents != ram_contents then
			puts "VMEM cache page #{i}, RAM address #{ram_address}, cache address #{cache_page_address}: Incorrect contents"
		end
	else
		puts "Cache page #{i} is empty"
	end
end

#puts "#{$vmem_cache_count} cache pages checked."
