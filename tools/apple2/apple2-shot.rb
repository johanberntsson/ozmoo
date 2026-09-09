#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# A picture of the Apple II screen, as the video hardware draws it.
#
#   ruby tools/apple2/apple2-shot.rb                  # -t:apple2, dejavu, temp/
#   ruby tools/apple2/apple2-shot.rb -t:apple2e       # the IIe's 80 columns
#   ruby tools/apple2/apple2-shot.rb -t:apple2e -o shot.png --driver apple2e
#   ruby tools/apple2/apple2-shot.rb --no-build -c look -c "open mailbox"
#
# Every other check on this target reads memory, and memory cannot show a wrong
# CHARACTER SET or a wrong VIDEO MODE: a screen-code dump reports the byte in
# the cell, never the glyph fetched for it, which is how phase 1's blinking
# capitals hid for a month and how the MEGA65's FCM_CHARSET bug hid for longer.
# So the check for anything that touches the charset is a picture with capital
# letters in it - and MAME renders one even under -video none, which is the
# thing AppleWin's headless front end cannot do.
# ---------------------------------------------------------------------------

require_relative 'apple2-emu'

ROOT   = Apple2Emu::ROOT
LABELS = File.join(Apple2Emu::TEMP, 'acme_labels.txt')

target   = 'apple2'
driver   = nil
story    = 'examples/dejavu.z3'
out      = nil
build    = true
extra    = []
commands = []
seconds  = 120
at       = 25

args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--no-build'  then build = false
  when /^-a2c/       then extra << arg
  when /^-a2hw/      then extra << arg  # the boot-time hardware report
  when /^-t:(\S+)$/  then target = $1
  when /^-a2d:(35|525)$/ then extra << arg  # 3.5" over SmartPort, or 5.25"
  when '--driver'    then driver = args.shift
  when '-o'          then out = args.shift
  when '-c'          then commands << args.shift
  when '--at'        then at = args.shift.to_f
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..8].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else story = arg
  end
end

driver ||= case target
           when 'apple2'   then 'apple2p'
           when 'apple2gs' then 'apple2gs'
           else 'apple2ee'
           end
screen = target == 'apple2' ? { cols: 40, altchar: false } : { cols: 80, altchar: true }
out ||= File.join(Apple2Emu::TEMP, "#{target}_#{File.basename(story).sub(/\.z\d$/, '')}.png")

if build
  cmd = ['ruby', 'make.rb', "-t:#{target}", *extra, story]
  puts cmd.join(' ')
  abort 'build failed' unless system(*cmd, chdir: ROOT, out: File::NULL)
end
ext, flop3 = Apple2Emu.disk_kind(target, extra)
image = File.join(ROOT, "#{target}_#{File.basename(story).sub(/\.z\d$/, '')}#{ext}")
abort "no image at #{image}" unless File.exist?(image)

# idle_exit ends the run where the game stops printing, which for a story with
# no commands is its opening screen; --at is the backstop for a game that never
# falls silent.
result = Apple2Emu.mame_run(image, driver: driver, flop3: flop3,
                            labels: Apple2Emu.read_labels(LABELS),
                            tap: 'printchar_buffered', auto_more: true,
                            idle_after: at, idle_exit: 8, command_idle: 3.0,
                            ready_flag: 's_cursorswitch', echo_flag: 'zp_screencolumn',
                            commands: commands.map { |c| c + "\n" },
                            snapshot: out, seconds: seconds, **screen)
result[:screen].each { |l| puts "|#{l}|" }
puts "wrote #{out} (#{target}/#{driver}, #{screen[:cols]} columns)"
