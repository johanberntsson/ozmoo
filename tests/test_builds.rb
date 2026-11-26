$is_linux = !(ENV['OS'] == 'Windows_NT')

require 'fileutils'

$passed = 0
$not_passed = 0
$files_before_build = 0;
$C1541 = nil
$dirfile = '_disc_dir.txt'

def unescape(s)
	"\"#{s}\"".undump
end

# Figure out path to c1541 from make.rb
paths_have_begun = false
paths_else_have_begun = false
File.readlines('../make.rb', chomp: true).each do |line|
	paths_have_begun = true if line =~ /^\s*if \$is_windows then/
	paths_else_have_begun = true if line =~ /^\s*else/
	if paths_have_begun and line =~ /\'C1541'\s*=>\s*"(.*)"\s*,\s*$/
		$C1541 = unescape($1) if paths_else_have_begun == $is_linux
	end
	break if paths_have_begun and line == 'end'
#	puts(line)
end

#puts $C1541

def run_command(prefix, storyfile, target, params)
	targetstr = target.length > 0 ? " -t:#{target}" : ''
#	modestr = mode.length > 0 ? " -#{mode}" : ''
	paramsstr = params.length > 0 ? " #{params}" : ''
#	cmd = "ruby ../make.rb #{storyfile}#{targetstr}#{modestr}#{paramsstr}"
	cmd = "ruby ../make.rb #{storyfile}#{targetstr}#{paramsstr}"
	puts "#{prefix}BUILD: #{cmd}"
	$files_before_build = Dir.entries('.').length
	build_result = `#{cmd}`
	return build_result
end

def compare_to_spec(actual, spec)
	return -1 if not spec
	if spec.is_a?(Integer) then
		if actual == spec then
			return 0
		end
	else
		if actual >= spec[0] and actual <= spec[1] then
			return 0
		end
	end
	return 1 # Not within specification
end

def finalize_test(build_result, problem, outfiles)
	is_ok = true
	if problem then
		puts build_result
		is_ok = false
	else
		if outfiles then
			outfiles.keys.each { |filename|
				sizes = outfiles[filename]
				if sizes.is_a?(Hash) then
					sizes = sizes.clone
					cmd = "#{$C1541} -a #{filename} -l > #{$dirfile}"
					`#{cmd}`
					show_lines = false
					if sizes.has_key?('*SHOW')
						show_lines = true
						sizes.delete('*SHOW')
					end
					File.readlines($dirfile, chomp: true).each do |line|
						puts "DIR: #{line}" if show_lines
						next if line =~ /^0 .* [0-9a-f]{2} (2a|3d)$/ or line =~ /^Empty image$/
						if line =~ /^(\d+) blocks free/ then
							bf = $1.to_i
							diff = compare_to_spec(bf, sizes['*FREE'])
							next if diff == -1 # No spec found
							if diff > 0 then 
								puts "Disk #{filename}: Free blocks #{bf} is outside expected range."
								is_ok = false
							end
							sizes.delete('*FREE')
						elsif line =~ /^(\d+)\s*"(.*)"\s*[a-z]+\s*$/ then
							actual_blocks = $1.to_i
							fname = $2
							diff = compare_to_spec(actual_blocks, sizes[fname])
							if diff == -1 then
								# No spec found
								puts "Disk #{filename}: Unexpected file #{fname} (#{actual_blocks} blocks) found."
								is_ok = false
							elsif diff > 0
								puts "Disk #{filename}: File size for file #{filename} (#{actual_blocks}) is outside expected range."
								sizes.delete(fname)
								is_ok = false
							else
								sizes.delete(fname)
								next
							end
						else 
							puts "Disk #{filename}: Unknown directory entry: >#{line}<"
							is_ok = false
						end
					end
					if not sizes.empty? then
						puts "Disk #{filename}: Expected file(s) that were not on disk:\n #{sizes.to_s}"
						is_ok = false
					end
					File.delete($dirfile)
				end

				if File.exist?(filename) then
					if File.directory?(filename) then
						Dir.delete(filename)
					else
						File.delete(filename)
					end
				else
					puts "EXPECTED FILE MISSING: #{filename}"
					is_ok = false
				end
			}
		end
	end
	extra_files = Dir.entries('.').length - $files_before_build
	if extra_files > 0 then
		puts "Extra files(s) found: #{extra_files}"
		is_ok = false
	end
	if is_ok then
		$passed += 1
	else
		puts "-----------------------------------------"
		$not_passed += 1
	end
end

def expect_success(storyfile, target, params, outfiles)
	build_result = run_command("\n(EXPECT SUCCESS) ", storyfile, target, params)
	problem = false
	problem = true if build_result =~ /^ERROR:/
	problem = true if build_result =~ /^WARNING:/
	problem = true if build_result !~ /^Successfully built game /
	finalize_test(build_result, problem, outfiles)
end

def expect_failure(storyfile, target, params, message, allow_successful_build, outfiles)
	build_result = run_command("\n(EXPECT FAILURE) ", storyfile, target, params)
	problem = false
	problem = true if build_result !~ /#{message}/
	problem = true if allow_successful_build != true and build_result =~ /^Successfully built game /
	finalize_test(build_result, problem, outfiles)
end

# Neo release packages live in ../dist/<game>, with the zip beside the folder.
# Keep the 8.3 file naming in step with neo_8_3_basename in make.rb.
def neo_release_paths(storyfile)
	storyname = File.basename(storyfile, File.extname(storyfile))
	game = storyname.upcase.gsub(/[^A-Z0-9]/, '')[0, 8]
	game = 'STORY' if game.nil? or game.empty?
	dir = File.join('..', 'dist', storyname)
	{
		dir: dir,
		zip: File.join('..', 'dist', storyname + '.zip'),
		neo: File.join(dir, game + '.NEO'),
		story: File.join(dir, game + '.STORY'),
		cfg: File.join(dir, game + '.CFG')
	}
end

# Clear the release package before every Neo build so stale files can never be
# mistaken for fresh ones.
def clear_neo_release(storyfile)
	paths = neo_release_paths(storyfile)
	FileUtils.rm_rf(paths[:dir])
	FileUtils.rm_f(paths[:zip])
end

def neo_vmem_config_ok?(path)
	return false, "missing #{path}" unless File.exist?(path)

	data = File.binread(path)
	return false, "#{path} is #{data.length} bytes; expected at least 512" if data.length < 512
	return false, "#{path} is not padded to a 256-byte boundary" unless (data.length % 256) == 0
	disk_info_length = data.getbyte(4)
	return false, "invalid disk-info length #{disk_info_length}" unless disk_info_length == 12

	vmem_offset = 4 + disk_info_length
	return false, "VMEM header offset #{vmem_offset} is outside #{path}" if vmem_offset + 4 > data.length

	total = data.getbyte(vmem_offset) * 256 + data.getbyte(vmem_offset + 1)
	entries = data.getbyte(vmem_offset + 2)
	preload = data.getbyte(vmem_offset + 3)
	return false, "VMEM entries must be non-zero" if entries == 0
	return false, "VMEM header length #{total} != 4 + 2 * #{entries}" unless total == 4 + 2 * entries
	return false, "preloaded blocks #{preload} exceed map entries #{entries}" if preload > entries
	return false, "VMEM data (#{total} bytes) does not fit in #{path}" if vmem_offset + total > data.length

	return true, nil
end

def neo_story_load_address
	File.foreach('../temp/acme_labels.txt') do |line|
		match = line.match(/^\s*story_start\s*=\s*\$([0-9A-Fa-f]+)/)
		return match[1].to_i(16) if match
	end
	nil
end

def neo_executable_ok?(path, expected_story_load)
	data = File.binread(path)
	return false, "#{path} has a bad header" unless data.bytesize >= 8 and data.byteslice(0, 4) == "\x03NEO"

	blocks = []
	position = 8
	loop do
		return false, "#{path} has a truncated block" if position + 5 > data.bytesize
		control = data.getbyte(position)
		load = data.getbyte(position + 1) | (data.getbyte(position + 2) << 8)
		size = data.getbyte(position + 3) | (data.getbyte(position + 4) << 8)
		nul = data.index("\x00", position + 5)
		return false, "#{path} has a block without a comment" unless nul
		comment = data.byteslice(position + 5, nul - (position + 5))
		data_start = nul + 1
		return false, "#{path} has a truncated payload" if data_start + size > data.bytesize
		blocks << {load: load, size: size, comment: comment}
		position = data_start + size
		break if (control & 0x80) == 0
	end
	return false, "#{path} has trailing bytes" unless position == data.bytesize
	return false, "#{path} does not have two load blocks" unless blocks.length == 2
	return false, "#{path} is missing the interpreter block" unless blocks[0][:size] > 0 and blocks[0][:comment] =~ /interpreter/
	return false, "#{path} is missing the story block" unless blocks[1][:size] > 0 and blocks[1][:comment] =~ /story/
	return false, "#{path} loads story data at #{blocks[1][:load]}, expected #{expected_story_load}" unless blocks[1][:load] == expected_story_load

	return true, nil
rescue => e
	return false, e.message
end

def validate_neo_release(original_story_size, storyfile)
	paths = neo_release_paths(storyfile)
	[paths[:zip], paths[:dir], paths[:neo], paths[:story], paths[:cfg]].each do |path|
		unless File.exist?(path)
			puts "EXPECTED FILE MISSING: #{path}"
			return false
		end
	end

	story_size = File.size(paths[:story])
	story_ok = story_size >= original_story_size
	puts "Neo story sidecar is #{story_size} bytes, smaller than source #{original_story_size}." unless story_ok

	block_ok = (story_size % 512) == 0
	puts "Neo story sidecar size #{story_size} is not a multiple of 512." unless block_ok

	cfg_ok, cfg_problem = neo_vmem_config_ok?(paths[:cfg])
	puts "SIDECAR CHECK FAILED: #{cfg_problem}" unless cfg_ok

	story_load = neo_story_load_address
	unless story_load
		puts "EXECUTABLE CHECK FAILED: story_start was not found in temp/acme_labels.txt"
		return false
	end
	neo_ok, neo_problem = neo_executable_ok?(paths[:neo], story_load)
	puts "EXECUTABLE CHECK FAILED: #{neo_problem}" unless neo_ok

	story_ok && block_ok && cfg_ok && neo_ok
rescue => e
	puts "RELEASE CHECK FAILED: #{e.message}"
	false
end

def expect_neo_vmem_success(storyfile, params)
	clear_neo_release(storyfile)

	build_result = run_command("\n(EXPECT NEO VMEM SUCCESS) ", storyfile, 'neo6502', "-v #{params}".strip)
	problem = false
	problem = true if build_result =~ /^ERROR:/
	problem = true if build_result =~ /^WARNING:/
	problem = true if build_result !~ /^Successfully built game /

	if build_result =~ /ERROR: The whole story doesn't fit in memory\./
		puts "Mode-P whole-story rejection occurred."
		problem = true
	end

	unless build_result =~ /Neo6502 VMEM: total story bytes/
		puts "Neo VMEM diagnostics were not printed."
		problem = true
	end

	problem = true unless validate_neo_release(File.size(storyfile), storyfile)
	clear_neo_release(storyfile)

	finalize_test(build_result, problem, nil)
end

# Neo emulator runtime checks are intentionally kept out of this build-only
# suite; they belong in a separately configured job with NEO_EMULATOR set.

minizork = '../examples/minizork.z3'
dragontroll = '../examples/dragontroll.z5'

show_dir = {'*SHOW' => 1}

dir = 'x16_minizork'
expect_success(minizork, 'x16', '-ZIP -re -fn:hello -bordercol:bg -bgcol:blk -fgcol:red -inputcol:green -statuscol:green -dmbgcol:red -dmfgcol:black -dminputcol:green -dmstatuscol:green -df:0 -dt:goodbye -u -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -ch -cb:30 -cs:b -sw:30 -ss1:"123456789 123456789 123456789 123456789" -ss2:"123456789 123456789 123456789 123456789" -ss4:"123456789 123456789 123456789 123456789" -ss3:"123456789 123456789 123456789 123456789"', 
	{"#{dir}.zip" => 1, "#{dir}/HELLO.PRG" => 1, "#{dir}/[ZCODE]" => 1, "#{dir}/[FONT]" => 1, "#{dir}" => 1})

expect_failure(dragontroll, 'c64', '-P -u', 'ERROR: Undo is not supported for build mode P', false, nil)

expect_failure(dragontroll, 'c128', '-u', 'need to implement undo functionality in the game', true, 
	{'c128_dragontroll.d71' => {'story' => [58, 66], '*FREE' => [1238, 1246]}})

expect_success(dragontroll, 'c64', '-81 -p:255 -re -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch -sb:12 -rb:1 -smooth -cb:30 -cs:b -dt:"monkey monkey 12" -sw:30 -ss1:"123456789 123456789 123456789 123456789" -ss2:"123456789 123456789 123456789 123456789" -ss4:"123456789 123456789 123456789 123456789" -ss3:"123456789 123456789 123456789 123456789"', 
	{'c64_dragontroll.d81' => {'loader' => [32,34], 'data' => 40, 'hello' => [63, 71], '*FREE' => [3016, 3024] }})

expect_success(minizork, 'c64', '-81 -p:255 -re -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch -sb:12 -rb:1 -smooth -cb:30 -cs:b -dt:"monkey monkey 12" -sw:30 -ss1:"123456789 123456789 123456789 123456789" -ss2:"123456789 123456789 123456789 123456789" -ss4:"123456789 123456789 123456789 123456789" -ss3:"123456789 123456789 123456789 123456789" -u', 
	{'c64_minizork.d81' => {'loader' => [32,34], 'data' => 200, 'hello' => [137, 145], '*FREE' => [2782, 2790] }})

expect_success(dragontroll, 'c64', '-81 -p:0 -b -sp:4 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch:255 -sb:6 -rb -bgcol:black -fgcol:green -bordercol:yellow -dm:1 -smooth -cb:30 -cursorcol:yellow -cs:u -dt:"monkey" -rd -sw:30 -ss1:"Good game"', 
	{'c64_dragontroll.d81' => {'loader' => [32,34], 'data' => 40, 'hello' => [51, 59], '*FREE' => [3028, 3036] }})

expect_success(dragontroll, 'c64', '-P -sp:10 -ss1:"This is the greatest game ever made"', 
	{'c64_dragontroll.d64' => {'story' => [44, 52], '*FREE' => [612,620]}})

expect_success(dragontroll, 'c64', '-S2 -sp:8 -sl', 
	{'c64_dragontroll_boot.d64' => {'story' => [51, 59], '*FREE' => [603,611]}, 
	'c64_dragontroll_story.d64' => {'*FREE' => [638,646]}})

expect_success(minizork, 'plus4', '-81 -p:1 -b -sp:4 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -i ../examples/scifi.mbo -ch:255 -sb:6 -bgcol:black -fgcol:green -bordercol:yellow -statuscol:yel -inputcol:yel -dm:0 -cb:99 -cursorcol:yel -cs:l -dt:"monkey 2" -rd -sw:30 -ss1:"Good game"', {
	'plus4_minizork.d81' => {'loader' => [19,21], 'data' => 200, 'hello' => [62, 70], '*FREE' => [2870, 2878]}})

expect_success(minizork, 'c64', '-P -sw:0 -rb:0', {
	'c64_minizork.d64' => {'story' => [175, 183], '*FREE' => [481, 489]}})

expect_success(minizork, 'c64', '-D2 -dmbgcol:black -dmfgcol:ltgrey -dmbordercol:grn -dmstatuscol:yel -dminputcol:white -dmcursorcol:green -sw:0 -sb -u', {
	'c64_minizork_boot_story_1.d64' => {'story' => [176, 184], '*FREE' => [394, 402]}, 
	'c64_minizork_story_2.d64' => {'*FREE' => [574, 582]}})

expect_success(minizork, 'plus4', '-S1 -sb:6', {
	'plus4_minizork.d64' => {'story' => [150, 158], '*FREE' => [334, 342]}})

expect_success(minizork, 'c128', '-sb:12 -rb:0', {
	'c128_minizork.d71' => {'story' => [159, 167], '*FREE' => [989, 997]}})

expect_success(minizork, 'mega65', '-u:0', {
	'mega65_minizork.d81' => {'autoboot.c65' => [35, 43], 'zcode' => 206, '*FREE' => [2911, 2919]}})

expect_neo_vmem_success('../test/praxix.z5', '-P')
expect_neo_vmem_success(minizork, '-P')

puts "\nTests passed: #{$passed}"
puts "\nTests not passed: #{$not_passed}"
