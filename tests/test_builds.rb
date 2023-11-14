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
	if problem then
		puts out
		print "-----------------------------------------\n"
	else
		outfiles.keys.each { |filename|
			File.delete(filename)
		}
	end
	
end

minizork = '../examples/minizork.z3'

test_build(minizork, 'c64', 'P', '', {'c64_minizork.d64' => 1})
test_build(minizork, 'plus4', 'S1', '', {'plus4_minizork.d64' => 1})
test_build(minizork, 'c128', '', '', {'c128_minizork.d71' => 1})
test_build(minizork, 'mega65', '', '', {'mega65_minizork.d81' => 1})
