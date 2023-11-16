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
	if paths_have_begun and line =~ /\$C1541\s*=\s*"(.*)"\s*$/
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

				if File.exists?(filename) then
					File.delete(filename)
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

minizork = '../examples/minizork.z3'
dragontroll = '../examples/dragontroll.z5'

show_dir = {'*SHOW' => 1}

expect_failure(dragontroll, 'c64', '-P -u', 'ERROR: Undo is not supported for build mode P', false, nil)

expect_failure(dragontroll, 'c128', '-u', 'need to implement undo functionality in the game', true, 
	{'c128_dragontroll.d71' => {'story' => [58, 66], '*FREE' => [1238, 1246]}})

expect_success(dragontroll, 'c64', '-81 -p:255 -re -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch -sb:12 -rb:1 -smooth -cb:30 -cs:b -dt:"monkey monkey 12" -sw:30 -ss1:"123456789 123456789 123456789 123456789" -ss2:"123456789 123456789 123456789 123456789" -ss4:"123456789 123456789 123456789 123456789" -ss3:"123456789 123456789 123456789 123456789"', 
	{'c64_dragontroll.d81' => {'loader' => [32,34], 'data' => 40, 'hello' => [63, 71], '*FREE' => [3016, 3024] }})

expect_success(minizork, 'c64', '-81 -p:255 -re -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch -sb:12 -rb:1 -smooth -cb:30 -cs:b -dt:"monkey monkey 12" -sw:30 -ss1:"123456789 123456789 123456789 123456789" -ss2:"123456789 123456789 123456789 123456789" -ss4:"123456789 123456789 123456789 123456789" -ss3:"123456789 123456789 123456789 123456789" -u', 
	{'c64_minizork.d81' => {'loader' => [32,34], 'data' => 200, 'hello' => [137, 145], '*FREE' => [2782, 2790] }})

expect_success(dragontroll, 'c64', '-81 -p:0 -b -sp:4 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch:255 -sb:6 -rb -rc:4=5,6=11 -dc:2:4 -bc:5 -dm:1 -smooth -cb:30 -cc:5 -cs:u -dt:"monkey" -rd -sw:30 -ss1:"Good game"', 
	{'c64_dragontroll.d81' => {'loader' => [32,34], 'data' => 40, 'hello' => [51, 59], '*FREE' => [3028, 3036] }})

expect_success(dragontroll, 'c64', '-P -sp:10 -ss1:"This is the greatest game ever made"', 
	{'c64_dragontroll.d64' => {'story' => [44, 52], '*FREE' => [612,620]}})

expect_success(dragontroll, 'c64', '-S2 -sp:8 -sl', 
	{'c64_dragontroll_boot.d64' => {'story' => [51, 59], '*FREE' => [603,611]}, 
	'c64_dragontroll_story.d64' => {'*FREE' => [638,646]}})

expect_success(minizork, 'plus4', '-81 -p:1 -b -sp:4 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -i ../examples/scifi.mbo -ch:255 -sb:6 -rc:4=5,6=11 -dc:2:4 -bc:5 -sc:5 -ic:5 -dm:0 -cb:99 -cc:5 -cs:l -dt:"monkey 2" -rd -sw:30 -ss1:"Good game"', {
	'plus4_minizork.d81' => {'loader' => [19,21], 'data' => 200, 'hello' => [62, 70], '*FREE' => [2870, 2878]}})

expect_success(minizork, 'c64', '-P -sw:0 -rb:0', {
	'c64_minizork.d64' => {'story' => [175, 183], '*FREE' => [481, 489]}})

expect_success(minizork, 'c64', '-D2 -dmdc:2:3 -dmbc:4 -dmsc:5 -dmic:2 -dmcc:4 -sw:0 -sb -u', {
	'c64_minizork_boot_story_1.d64' => {'story' => [176, 184], '*FREE' => [394, 402]}, 
	'c64_minizork_story_2.d64' => {'*FREE' => [574, 582]}})

expect_success(minizork, 'plus4', '-S1 -sb:6', {
	'plus4_minizork.d64' => {'story' => [150, 158], '*FREE' => [334, 342]}})

expect_success(minizork, 'c128', '-sb:12 -rb:0', {
	'c128_minizork.d71' => {'story' => [159, 167], '*FREE' => [989, 997]}})

expect_success(minizork, 'mega65', '-u:0', {
	'mega65_minizork.d81' => {'autoboot.c65' => [35, 43], 'zcode' => 206, '*FREE' => [2911, 2919]}})

puts "\nTests passed: #{$passed}"
puts "\nTests not passed: #{$not_passed}"
