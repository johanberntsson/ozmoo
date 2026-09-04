#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Save and restore on the Apple II, end to end and across a reboot.
#
#   ruby tools/apple2-save.rb            # build dejavu, save, reboot, restore
#   ruby tools/apple2-save.rb --no-build # ...against the disk as it stands
#   ruby tools/apple2-save.rb -v         # ...printing every screen it saw
#
# Three runs of the machine, because that is the only way to prove a save is on
# the disk rather than in memory:
#
#   1. drop the sword, save it into slot 0 with a comment, and stop.
#   2. boot the disk again from cold. The slot listing must show the comment,
#      which means the directory sector survived; restore it, and the sword
#      must be gone from the inventory, which means the slot's sectors did.
#   3. boot again and look at the listing alone, to be sure the restore did not
#      quietly rewrite anything.
#
# The image is then read here on the host, where the directory sector must say
# the same thing - the same three-way check the rest of this target uses:
# make.rb writes the layout, the interpreter writes the save, and the host
# reads it back without either of them helping.
#
# Typing is the fiddly part and the reason for the ready flag: this machine
# latches one key, so anything typed while the game is printing, saving or
# paging from disk is lost. mame_run types a character at a time and only while
# Ozmoo's cursor is on (s_cursorswitch), which is precisely when it is waiting.
# ---------------------------------------------------------------------------

require_relative 'apple2-emu'

ROOT   = Apple2Emu::ROOT
LABELS = File.join(Apple2Emu::TEMP, 'acme_labels.txt')
STORY  = 'examples/dejavu.z3'
IMAGE  = File.join(ROOT, 'apple2_dejavu.dsk')
COMMENT = 'sword dropped'

build   = true
verbose = false
extra   = []
ARGV.each do |arg|
  case arg
  when '--no-build' then build = false
  when /^-a2c/ then extra << arg    # build crunched, and check saving works there too
  when '-v', '--verbose' then verbose = true
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..8].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end

if build
  cmd = ['ruby', 'make.rb', '-t:apple2', *extra, STORY]
  puts cmd.join(' ')
  abort 'build failed' unless system(*cmd, chdir: ROOT, out: File::NULL)
end
abort "no image at #{IMAGE}" unless File.exist?(IMAGE)
labels = Apple2Emu.read_labels(LABELS)

def play(labels, commands, seconds: 900)
  Apple2Emu.mame_run(IMAGE, labels: labels, tap: 'printchar_buffered',
                     auto_more: true, idle_after: 25, idle_exit: 90,
                     command_idle: 3.0, ready_flag: 's_cursorswitch', echo_flag: 'zp_screencolumn',
                     commands: commands.map { |c| c + "\n" }, seconds: seconds)
end

problems = []
check = lambda do |ok, what|
  problems << what unless ok
  puts format('  %-4s %s', ok ? 'ok' : 'FAIL', what)
end

puts "\n1. drop the sword and save it into slot 0"
r1 = play(labels, ['drop sword', 'save', '0', COMMENT])
screen1 = r1[:screen].join("\n")
puts r1[:screen].map { |l| "  |#{l}|" } if verbose
check.call(screen1.include?('OK.'), 'the save reported Ok.')

puts "\n2. boot the disk again, and restore it"
r2 = play(labels, ['inventory', 'restore', '0', 'inventory'])
screen2 = r2[:screen].join("\n")
puts r2[:screen].map { |l| "  |#{l}|" } if verbose
check.call(screen2.include?('OK.'), 'the restore reported Ok.')
check.call(screen2 =~ /INVENTORY.*CUBE/m && screen2 !~ /INVENTORY.*SWORD/m,
           'the restored inventory has lost the sword again')

puts "\n3. boot again, and look at the slot listing"
r3 = play(labels, ['restore'])
listing = r3[:screen].find { |l| l.start_with?('0:') } || ''
puts r3[:screen].map { |l| "  |#{l}|" } if verbose
check.call(listing.downcase.include?(COMMENT[0, 14]), "slot 0 is listed as #{COMMENT.inspect}")
check.call(r3[:screen].any? { |l| l =~ /^1: *$/ }, 'the other slots are still empty')

puts "\n4. read the disk here on the host"
# The config block's last four bytes are the save area; the directory is its
# first sector, laid out as ten fourteen-character comments and a flag each.
image = File.binread(IMAGE).bytes
dos33 = [0, 7, 14, 6, 13, 5, 12, 4, 11, 3, 10, 2, 9, 1, 8, 15]
sector = lambda { |track, sec| image[(track * 16 + dos33[sec]) * 256, 256] }
config = sector.call(1, 0) + sector.call(1, 1)
save_track, slot_sectors, slots = config[508], config[509], config[6]
puts format('  save area: track %d, %d slots of %d sectors', save_track, slots, slot_sectors)
dir = sector.call(save_track, 0)
name = dir[0, 14].take_while { |c| c != 0 }.map(&:chr).join
check.call(dir[140] == 0xa2, 'slot 0 is marked in use in the directory sector')
check.call(name.downcase == COMMENT[0, 14], "the comment on the disk is #{name.inspect}")
check.call(dir[141, 9].all?(&:zero?), 'no other slot is marked in use')

puts
if problems.empty?
  puts 'PASS: a save survives a reboot, and the disk says what the game says'
  exit 0
else
  puts "FAIL: #{problems.length} of the checks above"
  exit 1
end
