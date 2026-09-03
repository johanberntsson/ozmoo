#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Measure the Apple II software clock, and say what A2_POLLS_PER_JIFFY should
# be.
#
#   ruby tools/apple2-clock.rb            # measure both loops, and the verdict
#   ruby tools/apple2-clock.rb -v         # ...printing the screens it measured
#   ruby tools/apple2-clock.rb --story examples/dejavu.z3   # another z3/z5 game
#   ruby tools/apple2-clock.rb --no-build # measure what is already built
#
# The II+ has no timer and no readable vertical blank, so the input poll *is*
# the clock (asm/apple2-kernal.asm): every pass through kernal_getchar counts
# down a2_jiffy_sub, and a jiffy is declared every A2_POLLS_PER_JIFFY passes.
# The constant is therefore a property of the loop those polls are made from -
# something to measure rather than to reason about, which is what MAME is for.
#
# It is measured in two places, because they are not the same loop:
#
#   a timed read     read_char (text.asm) with a timer running: the interpreter
#                    checks the clock on every pass, which costs ~40 cycles on
#                    top of the poll.  **This is what the constant is set
#                    from**: a game can only observe the clock's rate through
#                    timed input, and every build that has timed input at all
#                    (Z4PLUS) runs this same loop.  Measured against
#                    test/etude.z5, whose timed-single-key test prints an
#                    asterisk a second - so the interval between two of them is
#                    the thing that must come out at 1.000 s.
#   a plain read     the same loop with no timer: ~40 cycles a pass lighter, so
#                    the clock runs fast there.  Nothing reads it in that state,
#                    so nothing can tell.
#   a blinking cursor a build made with -cb reads the clock on every pass to
#                     decide when to blink, and that costs about what the timer
#                     check costs - so the constant set from the timed loop is
#                     nearly right here too, and the blink is measured to show
#                     it.  Between them the two cover every loop that reads the
#                     clock at all.
#
# The [More] prompt is a third loop and is reported too: it puts a wait_a_jiffy
# (17 calls to kernal_delay_1ms) between its polls, so it polls ~58 times a
# second and the clock all but stops - which is also a check on
# kernal_delay_1ms, the other hand-timed routine on this target.
#
# The exact number of polls made so far is recoverable, which is why a rate can
# be had in seconds rather than minutes: polls = jiffy * N + (N - sub).
# ---------------------------------------------------------------------------

require_relative 'apple2-emu'

ROOT     = Apple2Emu::ROOT
LABELS   = File.join(Apple2Emu::TEMP, 'acme_labels.txt')
CPU_HZ   = 1_020_484.0            # 14.31818 MHz / 14, the II+'s 6502

story   = 'examples/dejavu.z3'
build   = true
verbose = false

args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--story'    then story = args.shift.to_s
  when '--no-build' then build = false
  when '-v', '--verbose' then verbose = true
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..8].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else abort "unknown option #{arg}"
  end
end

# A build writes temp/acme_labels.txt, whatever the target, so the labels have
# to be re-read after each one: an address from the wrong build is still
# plausible enough to read as data rather than as a mistake.
def build_story(story, build, extra = [])
  if build
    cmd = ['ruby', 'make.rb', '-t:apple2', *extra, story]
    puts cmd.join(' ')
    abort "build of #{story} failed" unless system(*cmd, chdir: ROOT, out: File::NULL)
  end
  image = File.join(ROOT, "apple2_#{File.basename(story).sub(/\.z\d$/, '')}.dsk")
  abort "no image at #{image} - build it first" unless File.exist?(image)
  [image, Apple2Emu.read_labels(LABELS)]
end

# Polls made so far.  Only meaningful once a2_init has seeded the counter: RAM
# comes up holding whatever it holds and the splash screen polls before init,
# so the early samples are a garbage value being decremented.  The seeded state
# is jiffy 0 with the counter at its full value.
def poll_count(sample, n)
  sample['a2_jiffy'] * n + (n - sample['a2_jiffy_sub'])
end

def after_init(samples, n, label)
  start = samples.index { |_, v| v['a2_jiffy'].zero? && v['a2_jiffy_sub'] == n }
  abort "#{label}: the clock never reached its initial state - did the game boot?" unless start
  start
end

SAMPLES = { 'a2_jiffy' => 3, 'a2_jiffy_sub' => 2, 'zp_screencolumn' => 1 }.freeze

# --- the two loops with no timer in them: the read prompt, and [More] --------

def measure_idle(image, labels, n, keys:, settle:, window:, label:)
  result = Apple2Emu.mame_run(image, labels: labels, samples: SAMPLES, keys: keys,
                              seconds: 12 + settle + window + 2)
  samples = result[:samples]
  t0 = samples[after_init(samples, n, label)][0] + settle
  inside = samples.select { |t, _| t >= t0 && t <= t0 + window }
  abort "#{label}: no samples in the measurement window" if inside.length < 5
  rate = lambda do |from, to|
    a, b = inside[from], inside[to]
    (poll_count(b[1], n) - poll_count(a[1], n)) / (b[0] - a[0])
  end
  q = inside.length / 4
  { rate: rate.call(0, inside.length - 1),
    # In quarters as well as whole, because an average of two different loops
    # is exactly what this must not report as one number.
    quarters: (0...4).map { |i| rate.call(i * q, (i + 1) * q) },
    screen: result[:screen] }
end

# --- the loop that matters: a read with a timer running ---------------------

# TerpEtude's menu, then its "Timed single-key input" test.  The Returns walk
# the intro's [More] prompts; the last one is the keypress that starts the
# test, after which anything typed would stop it, so the run goes quiet.
def measure_timed(labels, build)
  image, labels = build_story('test/etude.z5', build)
  n = labels['A2_POLLS_PER_JIFFY']
  keys = []
  t = 8.0
  16.times { keys << [t, "\n"]; t += 1.0 }
  keys << [t += 2.0, "10\n"]
  keys << [t += 1.0, "\n"]
  result = Apple2Emu.mame_run(image, labels: labels, samples: SAMPLES, keys: keys,
                              seconds: t + 60)
  samples = result[:samples].select { |tt, _| tt > t + 2 }
  abort 'the timed test never started' if samples.length < 100

  # Each interrupt prints "* ", so the cursor column moves: that timestamps the
  # firings without having to read the screen, and it separates the passes that
  # were only polling from the ones that ran the game's routine.
  events = []
  samples.each_cons(2) do |(_, a), (t1, b)|
    events << t1 if a['zp_screencolumn'] != b['zp_screencolumn']
  end
  groups = []
  events.each { |e| groups.last && e - groups.last.last < 0.2 ? groups.last << e : groups << [e] }
  intervals = groups.map(&:first).each_cons(2).map { |a, b| b - a }
  if intervals.length < 5
    abort 'the timed test fired fewer than six interrupts - it was probably ' \
          'stopped by a stray key.  Run with -v and look at the screen.'
  end

  # The polling rate on its own: only the stretches with no interrupt in them,
  # so the game's own printing is not averaged into the loop's cost - and only
  # between the first firing and the last, because outside that the game is at
  # an ordinary read prompt, whose loop is 40 cycles a pass lighter. Measuring
  # across the two gives a number that is neither.
  first_fire, last_fire = groups.first.first, groups.last.first
  rates = []
  samples.select { |t, _| t >= first_fire && t <= last_fire }.each_cons(2) do |(t0, a), (t1, b)|
    next if a['zp_screencolumn'] != b['zp_screencolumn']
    rates << (poll_count(b, n) - poll_count(a, n)) / (t1 - t0)
  end
  rates.sort!
  { n: n, rate: rates[rates.length / 2], interval: intervals.sum / intervals.length,
    firings: groups.length, screen: result[:screen] }
end

# --- the cursor blink, which is the other thing that reads the clock ---------

BLINK_JIFFIES = 20

# A -cb build blinks the input cursor every -cb jiffies, and counts the blinks
# in s_cursormode, so the toggles can be timed the same way the interrupt
# firings are.  It is built on purpose here: the flag is off by default, and
# with it off nothing reads the clock outside a timed read.
def measure_blink(story, build)
  image, labels = build_story(story, build, ["-cb:#{BLINK_JIFFIES}"])
  n = labels['A2_POLLS_PER_JIFFY']
  result = Apple2Emu.mame_run(image, labels: labels, seconds: 45,
                              samples: SAMPLES.merge('s_cursormode' => 1),
                              keys: [[10, "\n"], [12, "\n"], [14, "\n"]])
  samples = result[:samples].select { |t, _| t > 20 }
  toggles = []
  samples.each_cons(2) { |(_, a), (t1, b)| toggles << t1 if a['s_cursormode'] != b['s_cursormode'] }
  intervals = toggles.each_cons(2).map { |a, b| b - a }
  abort 'the cursor never blinked - is the build a -cb one?' if intervals.length < 5
  first = samples[0][1]
  last = samples[-1][1]
  { n: n, rate: (poll_count(last, n) - poll_count(first, n)) / (samples[-1][0] - samples[0][0]),
    interval: intervals.sum / intervals.length, blinks: toggles.length,
    screen: result[:screen] }
end

# --- go ---------------------------------------------------------------------

image, labels = build_story(story, build)
n = labels['A2_POLLS_PER_JIFFY'] or abort 'no A2_POLLS_PER_JIFFY in the labels'

# The read prompt.  A game opens with a [More] prompt, so a couple of Returns
# are needed to reach the loop a player types in; press nothing at all and it
# waits at [More] for ever, which is the other measurement.
read = measure_idle(image, labels, n, label: 'read prompt', settle: 8, window: 20,
                    keys: [[10, "\n"], [12, "\n"], [14, "\n"]])
more = measure_idle(image, labels, n, label: '[More] prompt', settle: 8, window: 20, keys: [])
timed = measure_timed(labels, build)
blink = measure_blink(story, build)

if verbose
  [['read prompt', read], ['[More] prompt', more], ['timed read', timed],
   ['blinking cursor', blink]].each do |name, m|
    puts "\n#{name}:"
    m[:screen].each_with_index { |line, row| puts format('%2d | %s |', row, line) }
  end
end

prompt_row = read[:screen].reverse.find { |l| l.strip != '' }
unless prompt_row.to_s.start_with?('>')
  puts "WARNING: the last line of the screen is #{prompt_row.inspect}, not a '>' prompt -"
  puts '         the read-prompt measurement may not be the loop it claims.  Try -v.'
end

puts
puts "A2_POLLS_PER_JIFFY in this build: #{n}"
puts
puts "a timed read (test/etude.z5, timed single-key input) - what the constant is set from:"
puts format('  %.0f polls/s while polling, %.1f cycles a poll at %.4f MHz',
            timed[:rate], CPU_HZ / timed[:rate], CPU_HZ / 1e6)
puts format('  %d interrupt firings, one every %.3f s where the game asked for 1.000',
            timed[:firings], timed[:interval])
puts format('  the clock runs at %.2f jiffies/s here, %+.1f%% against 60',
            timed[:rate] / timed[:n], (timed[:rate] / timed[:n] / 60.0 - 1) * 100)
puts
puts "a plain read (#{File.basename(story)}, no timer) - nothing reads the clock in this state:"
puts format('  %.0f polls/s (quarters: %s), %.1f cycles a poll',
            read[:rate], read[:quarters].map { |r| format('%.0f', r) }.join(' '),
            CPU_HZ / read[:rate])
puts format('  the clock runs at %.2f jiffies/s here, %+.1f%% against 60',
            read[:rate] / n, (read[:rate] / n / 60.0 - 1) * 100)
puts
puts "a blinking cursor (#{File.basename(story)} built with -cb:#{BLINK_JIFFIES}) - the other reader of the clock:"
puts format('  %.0f polls/s, %.1f cycles a poll, clock %.2f jiffies/s',
            blink[:rate], CPU_HZ / blink[:rate], blink[:rate] / blink[:n])
puts format('  %d blinks, one every %.3f s where the build asked for %d jiffies = %.3f s (%+.1f%%)',
            blink[:blinks], blink[:interval], BLINK_JIFFIES, BLINK_JIFFIES / 60.0,
            (blink[:interval] / (BLINK_JIFFIES / 60.0) - 1) * 100)
puts
puts '[More] prompt (show_more_prompt, screen.asm) - a wait_a_jiffy per poll:'
puts format('  %.0f polls/s, so a pass takes %.2f ms against the 17 ms wait_a_jiffy asks for',
            more[:rate], 1000 / more[:rate])
puts format('  the clock runs at %.2f jiffies/s here: time all but stops at a [More] prompt',
            more[:rate] / n)
puts

# The last thing built was the -cb image, and it is also what temp/acme_labels.txt
# now describes.  Put the ordinary build back so neither is a surprise later.
build_story(story, build)

suggested = (timed[:rate] / 60.0).round
error = (timed[:interval] - 1.0) * 100
puts "A2_POLLS_PER_JIFFY = #{suggested}   <- asm/apple2-kernal.asm"
if error.abs <= 2.0
  puts format('PASS: a timed read is %+.2f%% off, i.e. the clock is calibrated.', error)
  exit 0
else
  puts format('A timed read runs %+.1f%% off; set the constant above and rebuild.', error)
  exit 1
end
