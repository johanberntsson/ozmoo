#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Run the conformance games on the Apple II and compare them with dfrotz.
#
#   ruby tools/apple2/apple2-conformance.rb           # czech, praxix and the
#                                                     # delete key, with a verdict
#   ruby tools/apple2/apple2-conformance.rb czech     # just one of them
#   ruby tools/apple2/apple2-conformance.rb delete    # just the delete key
#   ruby tools/apple2/apple2-conformance.rb -v        # ...and print both transcripts
#   ruby tools/apple2/apple2-conformance.rb --no-build
#   ruby tools/apple2/apple2-conformance.rb -t:apple2e            # the IIe build
#   ruby tools/apple2/apple2-conformance.rb -t:apple2e --driver apple2e   # unenhanced
#
# Both games print their own verdict - czech counts its 425 tests and praxix
# says "All tests passed." - and that is the primary check.  The second check is
# the transcript: everything the game printed, taken out of the running machine
# and compared against the same game under dfrotz.
#
# How the transcript is captured: MAME's read tap on `printchar_buffered` fires
# on the opcode fetch at its first byte, where the accumulator holds the
# character about to be printed.  That is the choke point every character
# reaches on its way to the screen, and it is on the far side of
# translate_zscii_to_petscii - so the capture also proves the translation, and
# characters the game sends to a memory stream (praxix prints the whole ZSCII
# set into one) correctly do not appear.  The characters are PETSCII, which is
# what Ozmoo's screen layer speaks on every target; this decodes them back.
#
# Comparing with dfrotz needs care in two places.  dfrotz wraps to its own
# screen width and will break a word to do it, so the texts are compared with
# ALL whitespace removed - line breaks are dfrotz's business, not the game's.
# And some differences are real and expected on this machine (no undo, no
# vertical bar in a 64 glyph character set, no standard revision claimed);
# those are listed below, each with its reason, removed from both sides before
# the comparison, and printed in the report.  Anything else is a failure.
# ---------------------------------------------------------------------------

require_relative 'apple2-emu'

ROOT   = Apple2Emu::ROOT
LABELS = File.join(Apple2Emu::TEMP, 'acme_labels.txt')

# A difference that is expected: the reason, the text dfrotz prints, and the
# text the Apple prints in its place (nil = prints nothing).  Both are removed
# before the comparison, and each one has to actually be there - an expectation
# that stops matching is itself a failure, so this list cannot rot quietly.
Expected = Struct.new(:why, :ref, :a2)

GAMES = {
  'czech' => {
    story: 'test/czech.z5',
    commands: [],
    # czech's own verdict.
    verdict: [/Passed: (\d+), Failed: 0,/, /Didn't crash: hooray!/],
    end_marker: 'Last test: quit!',
    expected: [
      Expected.new(
        'the header block: this is the interpreter describing itself, and every ' \
        'line of it is meant to differ',
        /standard 1\.1.*?Default color: current on current/m,
        /interpreter 2 P \(Apple IIe\).*?User: \d+/m
      )
    ]
  },
  'praxix' => {
    story: 'test/praxix.z5',
    commands: ['all'],
    verdict: [/All tests passed\./],
    end_marker: 'All tests passed.',
    expected: [
      Expected.new(
        'undo is compiled out of this target - 48K has no room for the buffer, ' \
        'and praxix passes the test anyway',
        /Interpreter claims to support undo\.\s*Using a local variable.*?glob2=-999\s*guard=9/m,
        /Interpreter claims to not support undo\..*?Using a local variable.*?Undo is not available on this interpreter\./m
      ),
      Expected.new(
        'the same for the multiple-undo test',
        /Interpreter claims to support undo\.\s*Undo 1 saved.*?loc=99 glob=999/m,
        /Interpreter claims to not support undo\.[^U]*Undo is not available on this interpreter\./m
      ),
      Expected.new(
        'Ozmoo claims no standard revision on any target, so the 1.1 tests stop ' \
        'here rather than run',
        /Ok, interpreter is version 1\.1\..*?Stopping, interpreter is only version 1\.1\./m,
        /Stopping, interpreter is only version 0\.0\..*?Stopping, interpreter is only version 0\.0\./m
      )
    ],
    # A global substitution instead of a block: the character appears all over
    # the bitwise test.
    subs: [['|', '!', 'the II+ has no vertical bar in its 64 glyphs, so Ozmoo ' \
                       'prints ! (asm/streams.asm)']]
  }
}

# PETSCII, as Ozmoo's screen layer speaks it: $41-$5a is the unshifted range,
# which the shifted charset draws as lower case, and $c1-$da the upper case.
def from_petscii(bytes)
  bytes.each_byte.map do |c|
    case c
    when 0x41..0x5a then (c + 32).chr
    when 0xc1..0xda then (c - 0x80).chr
    when 0x0d, 0x0a then "\n"
    when 0x20...0x7f then c.chr
    else format('\\x%02x', c)   # anything else is a bug, and shows as one
    end
  end.join
end

def build(target, story, want_build, extra = [])
  if want_build
    cmd = ['ruby', 'make.rb', "-t:#{target}", *extra, story]
    puts cmd.join(' ')
    abort "build of #{story} failed" unless system(*cmd, chdir: ROOT, out: File::NULL)
  end
  image = File.join(ROOT, "#{target}_#{File.basename(story).sub(/\.z\d$/, '')}.dsk")
  abort "no image at #{image}" unless File.exist?(image)
  [image, Apple2Emu.read_labels(LABELS)]
end

def run_apple(image, driver, labels, commands)
  result = Apple2Emu.mame_run(image, driver: driver, labels: labels, tap: 'printchar_buffered',
                              auto_more: true, idle_exit: 12, idle_after: 25,
                              ready_flag: 's_cursorswitch', echo_flag: 'zp_screencolumn',
                              commands: commands.map { |c| c + "\n" }, seconds: 400)
  [from_petscii(result[:tap]), result]
end

# dfrotz, answering its own [More] prompts.  ***MORE*** is printed where the
# game's text was interrupted and the text then continues on the same line, so
# it becomes a line break; whitespace is thrown away later anyway.
def run_dfrotz(story, commands)
  input = (commands + [''] * 60 + ['quit', 'y']).join("\n") + "\n"
  out = IO.popen(['timeout', '90', 'dfrotz', '-h', '24', '-w', '200', story],
                 'r+', err: File::NULL) do |io|
    io.write(input) rescue nil
    io.close_write rescue nil
    io.read
  end
  abort "dfrotz produced nothing for #{story} - is it installed?" if out.nil? || out.empty?
  out.force_encoding('binary').lines.drop(2).join.gsub('***MORE***', "\n")
end

def squeeze(text)
  text.gsub(/\s+/, '')
end

def compare(name, game, a2_text, ref_text)
  problems = []
  notes = []

  # Cut both sides off at the game's last word: after that comes our [More] and
  # the emulator idling, and dfrotz's own prompt noise.
  cut = lambda do |text|
    i = text.rindex(game[:end_marker])
    i ? text[0, i + game[:end_marker].length] : text
  end
  a2 = cut.call(a2_text)
  ref = cut.call(ref_text)

  (game[:subs] || []).each do |from, to, why|
    next unless ref.include?(from)
    notes << "#{why}: '#{from}' -> '#{to}' (#{ref.count(from)} times)"
    ref = ref.gsub(from, to)
  end

  game[:expected].each do |exp|
    unless ref =~ exp.ref
      problems << "expected difference no longer present in dfrotz's output (#{exp.why})"
      next
    end
    unless a2 =~ exp.a2
      problems << "expected difference no longer present on the Apple (#{exp.why})"
      next
    end
    notes << exp.why
    ref = ref.sub(exp.ref, '')
    a2 = a2.sub(exp.a2, '')
  end

  if squeeze(a2) != squeeze(ref)
    sa, sr = squeeze(a2), squeeze(ref)
    i = (0...[sa.length, sr.length].min).find { |j| sa[j] != sr[j] } || [sa.length, sr.length].min
    problems << "transcripts differ at character #{i} of #{sr.length}:\n" \
                "  dfrotz: ...#{sr[[i - 40, 0].max, 90].inspect}\n" \
                "  apple2: ...#{sa[[i - 40, 0].max, 90].inspect}"
  end

  game[:verdict].each do |re|
    problems << "the game's own verdict is missing: #{re.inspect}" unless a2_text =~ re
  end
  [problems, notes]
end

# --- the delete key ---------------------------------------------------------
#
# Not a conformance game, and not compared against dfrotz: it is a keyboard
# translation, and it is the one part of input that no conformance game
# exercises - czech and praxix never correct a typing mistake - so it broke
# without anything here noticing.
#
# There is no one delete key across the family. A II+ has no DEL at all and its
# LEFT ARROW sends $08, which is also what a host Backspace produces under both
# emulators; a IIe's DELETE sends $7f. Both have to reach the interpreter as
# PETSCII $14, which is what read_text, .input_alphanum and s_printchar all
# understand.
#
# **Both halves are checked, because they fail apart.** The reply to a corrected
# command proves the input BUFFER was fixed; the input line left on screen by a
# second command with no Return proves the SCREEN was. When this last broke,
# $08 did the first and not the second - the game answered the corrected
# command perfectly while the screen still showed the mistake, which to a
# player is the key doing nothing.
DELETE_KEYS  = { 8 => 'left arrow, and a host Backspace', 127 => "a IIe's DELETE" }
DELETE_STORY = 'examples/dejavu.z3'
DELETE_REPLY = 'featureless white cube'   # from the room `look` reprints

def check_delete_key(target, driver, want_build, extra)
  image, labels = build(target, DELETE_STORY, want_build, extra)
  problems = []
  notes = []
  DELETE_KEYS.each do |code, what|
    # "lookx", back over the x, Return - then the same again without Return, so
    # the corrected line is still on the screen at the end of the run.
    result = Apple2Emu.mame_run(image, driver: driver, labels: labels,
      tap: 'printchar_buffered', auto_more: true, idle_after: 25, idle_exit: 15,
      command_idle: 3.0, ready_flag: 's_cursorswitch', echo_flag: 'zp_screencolumn',
      commands: ["lookx#{code.chr}\n", "lookx#{code.chr}"], seconds: 400)
    reply = from_petscii(result[:tap]).downcase
    line  = (result[:screen].reverse.find { |l| l.start_with?('>') } || '').rstrip
    where = format('$%02x (%s)', code, what)
    if line == '>LOOK'
      notes << "#{where}: the input line reads #{line.inspect}"
    else
      problems << "#{where}: the input line reads #{line.inspect}, not \">LOOK\" - " \
                  'the character was taken out of the buffer but not off the screen'
    end
    unless reply.include?(DELETE_REPLY)
      problems << "#{where}: the game did not answer the corrected command"
    end
  end
  [problems, notes]
end

# --- go ---------------------------------------------------------------------

want_build = true
verbose = false
wanted = []
extra = []
target = 'apple2'
driver = nil
args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--no-build' then want_build = false
  when /^-a2c/ then extra << arg    # build the games crunched, and check that too
  when /^-t:(\S+)$/ then target = $1
  when '--driver' then driver = args.shift
  when '-v', '--verbose' then verbose = true
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..12].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else
    unless GAMES.key?(arg) or arg == 'delete'
      abort "unknown check #{arg} (have: #{(GAMES.keys + ['delete']).join(', ')})"
    end
    wanted << arg
  end
end
wanted = GAMES.keys + ['delete'] if wanted.empty?

# The MAME machine that matches the build: a -t:apple2 disk wants the 48K II+,
# and a -t:apple2e one an enhanced IIe unless --driver says otherwise (apple2e
# is the unenhanced machine, apple2c the IIc).
driver ||= target == 'apple2' ? 'apple2p' : 'apple2ee'

failed = false
wanted.each do |name|
  if name == 'delete'
    problems, notes = check_delete_key(target, driver, want_build, extra)
    puts
    puts "the delete key on #{target}/#{driver}: #{DELETE_STORY}, both codes"
    notes.each { |n| puts "  ok: #{n}" }
    if problems.empty?
      puts '  PASS: a typing mistake can be corrected, in the buffer and on the screen'
    else
      failed = true
      problems.each { |p| puts "  FAIL: #{p}" }
    end
    next
  end
  game = GAMES[name]
  image, labels = build(target, game[:story], want_build, extra)
  a2_text, result = run_apple(image, driver, labels, game[:commands])
  ref_text = run_dfrotz(game[:story], game[:commands])
  problems, notes = compare(name, game, a2_text, ref_text)

  puts
  puts "#{name} (#{game[:story]}) on #{target}/#{driver}: " \
       "#{a2_text.length} characters printed, " \
       "#{'%.0f' % result[:seconds]} emulated seconds"
  if verbose
    puts a2_text.lines.map { |l| "  | #{l.chomp}" }
    puts '  last screen:'
    result[:screen].each { |l| puts "  |#{l}|" }
  end
  game[:verdict].each do |re|
    m = a2_text[re]
    puts "  verdict: #{m}" if m
  end
  notes.each { |n| puts "  expected difference: #{n}" }
  if problems.empty?
    puts "  PASS: the transcript matches dfrotz, allowing for the differences above"
  else
    failed = true
    problems.each { |p| puts "  FAIL: #{p}" }
  end
end

exit(failed ? 1 : 0)
