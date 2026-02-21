# Utility to examine a memory image of Ozmoo running on C64, to see if:
# * virtual memory holds exactly what the vmem map says
# * vmem buffer holds what the buffer index says it holds
# * PC points to static Z-code memory, and a reasonable location in RAM
#
# A typical call looks like this:
# ruby memcheck_c128.rb ..\examples\minizork.z3 ..\temp\acme_labels.txt b0.bin b1.bin
#
# To create the memory snapshots, press Ctrl-H in Vice to enter monitor, then type:
# bank ram00
# s "b0.bin" 0 0000 ffff
# bank ram01
# s "b1.bin" 0 0000 ffff

require 'fileutils'

if ARGV.length != 4
	puts "Usage: ruby memcheck_c128.rb storyfile labels ram00_image ram01_image"
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

$ram0_data = File.binread ARGV[2]

if $ram0_data.length == 65538
	$ram0_data = $ram0_data[2 ..]
elsif $ram0_data.length != 65536
	"RAM00 dump file has the wrong length (should be 64 KB)."
	exit 1
end

$ram1_data = File.binread ARGV[3]

if $ram1_data.length == 65538
	$ram1_data = $ram1_data[2 ..]
elsif $ram1_data.length != 65536
	"RAM01 dump file has the wrong length (should be 64 KB)."
	exit 1
end

$story_start = $labels['story_start']
$z_pc = $labels['z_pc']
$z_pc_mempointer = $labels['z_pc_mempointer']
$vmap_z_l = $labels['vmap_z_l']
$vmap_z_h = $labels['vmap_z_h']
$stack_start = $labels['stack_start']
$stack_pages = $labels['STACK_PAGES']
$first_banked_memory_page = $labels['first_banked_memory_page']
$first_vmap_entry_in_bank_1 = $labels['first_vmap_entry_in_bank_1']
$vmap_first_ram_page = $labels['vmap_first_ram_page']
$vmap_first_ram_page_in_bank_1 = $labels['vmap_first_ram_page_in_bank_1']
$vmap_max_entries = $labels['vmap_max_entries']
$vmap_used_entries = $labels['vmap_used_entries']
$vmem_highbyte_mask = $labels['vmem_highbyte_mask']
$vmem_cache_start = $labels['vmem_cache_start']
$vmem_cache_count = $labels['vmem_cache_count']
$vmem_cache_page_index = $labels['vmem_cache_page_index']
$vmem_cache_bank_index = $labels['vmem_cache_bank_index']
$story_start_far_ram = $labels['story_start_far_ram']

puts "Static memory starts at Z-code address $#{$statmem_start.to_s(16)}"
print "\n"
puts "VMEM buffer is at RAM address $#{$vmem_cache_start.to_s(16)}-$#{($vmem_cache_start + 256 * $vmem_cache_count - 1).to_s(16)}"
puts "Stack is at RAM address $#{$stack_start.to_s(16)}-$#{($stack_start + 256 * $stack_pages - 1).to_s(16)}"
puts "Dynamic memory starts at RAM address $#{$story_start_far_ram.to_s(16)}"
puts "VMEM starts at RAM address $#{(256*$ram0_data[$vmap_first_ram_page].ord).to_s(16)}"

print "\n"
$z_pc_value = $ram0_data[($z_pc - 1) .. ($z_pc + 2)].unpack("N*")[0] % (256*256*256)
$z_pc_mempointer_value = $ram0_data[$z_pc_mempointer .. ($z_pc_mempointer + 1)].unpack("S<*")[0]

puts "z_pc points to Z-code address $#{$z_pc_value.to_s(16)}"
puts "z_pc_mempointer points to RAM address $#{$z_pc_mempointer_value.to_s(16)}"

if $z_pc_value < $statmem_start
	puts "Z_PC points to dynamic memory!"
end

if $z_pc_value >= $story_data.length
	puts "Z_PC points beyond the end of the Z-code file!"
end

if $z_pc_mempointer_value > 256 * $first_banked_memory_page or
	( $z_pc_mempointer_value < $story_start + $statmem_start and
		($z_pc_mempointer_value < $vmem_cache_start or
			$z_pc_mempointer_value > $vmem_cache_start + 256 * $vmem_cache_count))
	puts "Z_PC_MEMPOINTER points to weird memory!"
end

$vmap_entry_count = $ram0_data[$vmap_used_entries].ord
$first_vmap_entry_in_bank_1_value = $ram0_data[$first_vmap_entry_in_bank_1].ord
print "\n"
puts "First vmap entry in bank 1 is $#{$first_vmap_entry_in_bank_1_value.to_s(16)}"

$vmap_entry_count.times do |i|
	zcode_address = 2 * 256 * 
		(256 * ($ram0_data[$vmap_z_h + i].ord & $vmem_highbyte_mask) +
			$ram0_data[$vmap_z_l + i].ord)
	zcode_contents = $story_data[zcode_address .. (zcode_address + 511)]
	ram_address = i < $first_vmap_entry_in_bank_1_value ?
		256 * ($ram0_data[$vmap_first_ram_page].ord + 2 * i) :
		256 * ($ram0_data[$vmap_first_ram_page_in_bank_1].ord + 
			2 * (i - $first_vmap_entry_in_bank_1_value))
	
	ram_contents =  i < $first_vmap_entry_in_bank_1_value ?
		$ram0_data[ram_address .. (ram_address + 511)] :
		$ram1_data[ram_address .. (ram_address + 511)]
	if zcode_address >= $story_data.length then
		puts "VMAP block $#{i.to_s(16)}, RAM address $#{ram_address.to_s(16)}, Z-code address $#{zcode_address.to_s(16)}: Z-code address out of range"
	elsif zcode_contents == nil or ram_contents == nil or 
			ram_contents.length != 512 or
			zcode_contents.length != 512 or
			ram_contents != zcode_contents then
		puts "VMAP block #{i.to_s(16)}, RAM address $#{ram_address.to_s(16)}, Z-code address $#{zcode_address.to_s(16)}: Incorrect contents"
	end
end

puts "\n#{$vmap_entry_count} VMAP blocks checked."

print "\n"

$vmem_cache_count.times do |i|
	cache_page_address = $vmem_cache_start + 256 * i
	bank = $ram0_data[$vmem_cache_bank_index + i].ord
	ram_address = 256 * $ram0_data[$vmem_cache_page_index + i].ord
	if ram_address > 0
		puts "Cache page #{i} contains page $#{(ram_address / 256).to_s(16)} in bank #{bank}"
		cache_contents = $ram0_data[cache_page_address .. (cache_page_address + 255)]
		ram_contents = bank == 0 ?
			$ram0_data[ram_address .. (ram_address + 255)] :
			$ram1_data[ram_address .. (ram_address + 255)]
		if cache_contents.length != 256 or
				ram_contents.length != 256 or
				cache_contents != ram_contents then
			puts "VMEM cache page #{i}, RAM address $#{ram_address.to_s(16)} in bank #{bank}, cache page address $#{cache_page_address.to_s(16)}: Incorrect contents"
		end
	else
		puts "Cache page #{i} is empty"
	end
end

#puts "#{$vmem_cache_count} cache pages checked."
