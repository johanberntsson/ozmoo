# $is_windows = (ENV['OS'] == 'Windows_NT')

require 'fileutils'

$passed = 0
$not_passed = 0
$files_before_build = 0;

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

def finalize_test(build_result, problem, outfiles)
	is_ok = true
	if problem then
		puts build_result
		is_ok = false
	else
		if outfiles then
			outfiles.keys.each { |filename|
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
	build_result = run_command('(EXPECT SUCCESS) ', storyfile, target, params)
	problem = false
	problem = true if build_result =~ /^ERROR:/
	problem = true if build_result =~ /^WARNING:/
	problem = true if build_result !~ /^Successfully built game /
	finalize_test(build_result, problem, outfiles)
end

def expect_failure(storyfile, target, params, message, allow_successful_build, outfiles)
	build_result = run_command('(EXPECT FAILURE) ', storyfile, target, params)
	problem = false
	problem = true if build_result !~ /#{message}/
	problem = true if allow_successful_build != true and build_result =~ /^Successfully built game /
	finalize_test(build_result, problem, outfiles)
end

minizork = '../examples/minizork.z3'
dragontroll = '../examples/dragontroll.z5'

expect_failure(dragontroll, 'c64', '-P -u', 'ERROR: Undo is not supported for build mode P', false, {})
expect_failure(dragontroll, 'c128', '-u', 'need to implement undo functionality in the game', true, {'c128_dragontroll.d71' => 1})
expect_failure(dragontroll, 'c128', '-u', 'need to implement undo functionality in the game', true, {'c128_dragontroll.d71' => 1})

expect_success(dragontroll, 'c64', '-81 -p:0 -b -sp:6 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -if ../examples/eka.kla -ch:255 -sb:6 -rb -rc:4=5,6=11 -dc:2:4 -bc:5 -dm:1 -smooth -cb:30 -cc:5 -cs:u -dt:"monkey" -rd -sw:30 -ss1:"Good game"', {'c64_dragontroll.d81' => 1})
expect_success(dragontroll, 'c64', '-P -ss1:"This is the greatest game ever made"', {'c64_dragontroll.d64' => 1})
expect_success(dragontroll, 'c64', '-S2', {'c64_dragontroll_boot.d64' => 1, 'c64_dragontroll_story.d64' => 1})

expect_success(minizork, 'plus4', '-81 -p:1 -b -sp:6 -re -sl -fn:hello -f ../fonts/sv/PXLfont-rf-SV.fnt -cm:sv -in:3 -i ../examples/scifi.mbo -ch:255 -sb:6 -rc:4=5,6=11 -dc:2:4 -bc:5 -sc:5 -ic:5 -dm:0 -cb:99 -cc:5 -cs:l -dt:"monkey 2" -rd -sw:30 -ss1:"Good game"', {'plus4_minizork.d81' => 1})
expect_success(minizork, 'c64', '-P -sw:0 -rb:0', {'c64_minizork.d64' => 1})
expect_success(minizork, 'c64', '-D2 -sw:0 -sb -u', {'c64_minizork_boot_story_1.d64' => 1, 'c64_minizork_story_2.d64' => 1})
expect_success(minizork, 'plus4', '-S1 -sb:6', {'plus4_minizork.d64' => 1})
expect_success(minizork, 'c128', '-sb:12 -rb:0', {'c128_minizork.d71' => 1})
expect_success(minizork, 'mega65', '-u:0', {'mega65_minizork.d81' => 1})

puts "\nTests passed: #{$passed}"
puts "\nTests not passed: #{$not_passed}"
