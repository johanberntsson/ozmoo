# meta-make for Ozmoo

require 'fileutils'
require 'rbconfig'

$ruby_exe = File.join(
	RbConfig::CONFIG['bindir'],
	RbConfig::CONFIG['ruby_install_name'])
	
#puts $ruby_exe

$make_script = File.join(__dir__,'make.rb')

$out_args = []

def print_usage_and_exit
	print_usage
	exit 1
end

def print_usage
	puts "Usage: metamake.rb [-mau[:0|1]]"
	puts "         [make.rb options] <storyfile>"
	puts "  -mau: auto-upgrade build type (S1 to S2, D2 to D3) as necessary, on by default"
	puts "\nExample: metamake.rb -mau:0 -t:plus4 mygame.z5"
end

if ARGV.length == 0
	print_usage_and_exit
end

$target = 'c64'
$upgrade_build = true
$build_type = nil

ARGV.length.times do |i|
	arg = ARGV[i]
	if arg =~ /^-mau(?::([01]))?$/ then
		if $1 == '0'
			$upgrade_build = false
		else
			$upgrade_build = true
		end
	else
		$out_args.push arg
		if arg =~ /^-t:(c64|c128|mega65|plus4|x16)$/
			$target = $1
		elsif arg =~ /^-(S1|S2|D2|D3|71|71D|81|P|ZIP)$/
			$build_type = $1
		end
	end
end

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
puts "====="

$build_attempt = 0

# if $drive_type == '41'
	# $out_args.push '-S1'
# if $drive_type == '41D'
	# $out_args.push '-D2'
# elsif $drive_type == '71'
	# $out_args.push '-71'
# elsif $drive_type == '71D'
	# $out_args.push '-71D'
# elsif $drive_type == '81'
	# $out_args.push '-81'
# elsif $drive_type == 'ZIP'
	# $out_args.push '-ZIP'
# elsif $drive_type == 'P'
	# $out_args.push '-P'
# end


attempt_build

if $exit_status != 0
	if $output =~ /^ERROR: The (whole story doesn't fit|story fits on the disk, but not the bootfile)/
		if $build_type == 'S1'
			$out_args.delete '-S1'
			$out_args.push '-S2'
			attempt_build
		elsif $build_type == 'D2'
			$out_args.delete '-D2'
			$out_args.push '-D3'
			attempt_build
		end
	end
end
	
