# $is_windows = (ENV['OS'] == 'Windows_NT')

require 'fileutils'

def test_build(storyfile, target, mode, params, outfiles)
	targetstr = target.length > 0 ? " -t:#{target}" : ''
	modestr = mode.length > 0 ? " -#{mode}" : ''
	paramsstr = params.length > 0 ? " #{params}" : ''
	cmd = "ruby ../make.rb #{storyfile}#{targetstr}#{modestr}#{paramsstr}"
	puts "BUILD: #{cmd}"
	out = `#{cmd}`
	problem = false
	problem = true if out =~ /^ERROR:/
	problem = true if out =~ /^WARNING:/
	problem = true if out !~ /^Successfully built game /
	if problem then
		puts out
		print "-----------------------------------------\n"
	else
		outfiles.keys.each { |filename|
			if File.exists?(filename) then
				File.delete(filename)
			else
				puts "EXPECTED FILE MISSING: #{filename}"
				print "-----------------------------------------\n"
			end
		}
	end
	
end

minizork = '../examples/minizork.z3'
dragontroll = '../examples/dragontroll.z5'

test_build(dragontroll, 'c64', 'P', '-ss1:"This is the greatest game ever made"', {'c64_dragontroll.d64' => 1})
test_build(dragontroll, 'c64', 'S2', '', {'c64_dragontroll_boot.d64' => 1, 'c64_dragontroll_story.d64' => 1})

test_build(minizork, 'c64', 'P', '-sw:0', {'c64_minizork.d64' => 1})
test_build(minizork, 'c64', 'D2', '-sw:0 -sb -u', {'c64_minizork_boot_story_1.d64' => 1, 'c64_minizork_story_2.d64' => 1})
test_build(minizork, 'plus4', 'S1', '-sb:6', {'plus4_minizork.d64' => 1})
test_build(minizork, 'c128', '', '-sb:12', {'c128_minizork.d71' => 1})
test_build(minizork, 'mega65', '', '-u:0', {'mega65_minizork.d81' => 1})

