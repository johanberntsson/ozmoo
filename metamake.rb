# meta-make for Ozmoo

require 'fileutils'
require 'rbconfig'

puts "metamake.rb is not ready for use yet."
exit 1

$ruby_exe = File.join(
	RbConfig::CONFIG['bindir'],
	RbConfig::CONFIG['ruby_install_name'])
	
$make_script = File.join(__dir__,'make.rb')

$out_args = []

#Constant LEVEL_DM



$features = [
	'dark_mode',
	'command_line_history',
	'undo',
	'splash_screen',
	'fast_mode',
	'reu_boost',
	'scrollback',
	'smooth_scroll',
	'x_for_examine',
	'cursor_blink',
	'unicode_map',
	'scrollback_ram',
	'runtime_errors',
]

def add_features(add)
	new = []
	# if feature_present?(add, 'dark_mode') # and !(base.any? |x| x =~ /^-dm:0$/}
		# nil # On by default
	
end

	# {'name' => 'Dark Mode', 'on' => '-dm', 'off' => '-dm:0', 'onbydefault' => 'c64,c128,plus4,mega65,x16'},
	# {'name' => 'Command Line History', 'on' => '-ch', 'off' => '-ch:0', 'onbydefault' => 'mega65,x16'},
	# {'name' => 'Undo', 'on' => '-u', 'off' => '-u:0', 'onbydefault' => 'mega65', 'notsupported' => 'plus4'},
	# {'name' => 'Undo', 'on' => '-u', 'off' => '-u:0', 'onbydefault' => 'mega65', 'notsupported' => 'plus4'},

def print_usage_and_exit
	print_usage
	exit 1
end

def print_usage
	puts "Usage: metamake.rb [-mau[:0|1]] [-maf[:0|1]]"
	puts "         [make.rb options] <storyfile>"
	puts "  -mau: auto-upgrade build type (S1 to S2, D2 to D3) as necessary, on by default"
	puts "  -maf: add features that make sense, on by default"
	puts "\nExample: metamake.rb -mau:0 -t:plus4 mygame.z5"
end

if ARGV.length == 0
	print_usage_and_exit
end

$target = 'c64'
$upgrade_build = true
$build_type = nil
$add_features = true
#$undo_specified = nil
await_value = nil
$arg_hash = {}

ARGV.length.times do |i|
	arg = ARGV[i]
	if await_value
		$arg_hash[await_value] = arg
		await_value = nil
	elsif arg =~ /^-mau(?::([01]))?$/ then
		if $1 == '0'
			$upgrade_build = false
		else
			$upgrade_build = true
		end
	elsif arg =~ /^-maf(?::([01]))?$/ then
		if $1 == '0'
			$add_features = false
		else
			$add_features = true
		end
	else
		$out_args.push arg
		# if arg =~ /^-t:(c64|c128|mega65|plus4|x16)$/
			# $target = $1
		if arg =~ /^-(S1|S2|D2|D3|71|71D|81|P|ZIP)$/
			$build_type = $1
		# elsif arg =~ /^-u(:[01])?$/
			# if $1 == '0'
				# $undo_specified = false
			# else
				# $undo_specified = true
			# end
		elsif arg =~ /^-(f|c|cf|asa|asw|if|i)$/
			await_value = arg[1..]
		elsif arg =~ /^-(.+?):(.+)$/
			$arg_hash[$1] = $2
		elsif arg =~ /^-(.+?)$/
			$arg_hash[$1] = '1'
		elsif arg !~ /^-/ and arg =~ /\.(dat|z[1-8])$/i
			$story_file = arg
		end
	end
end

puts $arg_hash.to_s
exit

$target = $arg_hash['t'] if $arg_hash.has_key?('t')

if $story_file == nil
	puts "ERROR: No story file was given."
	exit 1
end

unless File.exist?($story_file)
	puts "ERROR: The story file was not found."
	exit 1
end

#puts "Story file is " + $story_file
$header = File.binread($story_file, 256)
$zcode_version = $header[0].ord
puts "Z-code version: #{$zcode_version}"


if $build_type == nil
	case $target
	when 'c128'
		$build_type = '71'
	when 'mega65'
		$build_type = '81'
	when 'x16'
		$build_type = 'ZIP'
	else
		$build_type = 'S1'
	end
end

def attempt_build
	$build_attempt += 1
	puts "******************* BUILD ATTEMPT " + $build_attempt.to_s
	args = $out_args.join(' ')
	cmd = "\"#{$make_script}\" #{args}"
	puts "Command: make.rb #{args}"
	$output = `#{$ruby_exe} #{cmd}`
	$exit_status = $?.exitstatus
	puts $output
	puts "Exit status: " + ($exit_status == 0 ? "Success" : "Fail")
	puts "******************* END BUILD ATTEMPT " + $build_attempt.to_s
	puts ""
end

puts "====="
puts "METAMAKE SUMMARY:"
puts "Drive type: " + $drive_type if $drive_type != nil

# OBS: Dragontroll stödjer inte undo, så den ska byggas utan (kolla headern!)
if $add_features
	if $undo_specified == nil
		puts "Will add UNDO!"
	end
end


puts "====="

$build_attempt = 0

attempt_build

if $exit_status != 0
	if $output =~ /^ERROR: The (whole story doesn't fit|story fits on the disk, but not the bootfile)/
		if $build_type == 'S1' and $upgrade_build
			$out_args.delete '-S1'
			$out_args.push '-S2'
			attempt_build
		elsif $build_type == 'D2' and $upgrade_build
			$out_args.delete '-D2'
			$out_args.push '-D3'
			attempt_build
		end
	end
end
	
