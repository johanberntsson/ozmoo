#!/usr/bin/env ruby
# ---------------------------------------------------------------------------
# Run the conformance games on the Apple II and compare them with dfrotz.
#
#   ruby tools/apple2-conformance.rb           # czech and praxix, with a verdict
#   ruby tools/apple2-conformance.rb czech     # just one of them
#   ruby tools/apple2-conformance.rb -v        # ...and print both transcripts
#   ruby tools/apple2-conformance.rb --no-build
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

def build(story, want_build)
  if want_build
    cmd = ['ruby', 'make.rb', '-t:apple2', story]
    puts cmd.join(' ')
    abort "build of #{story} failed" unless system(*cmd, chdir: ROOT, out: File::NULL)
  end
  image = File.join(ROOT, "apple2_#{File.basename(story).sub(/\.z\d$/, '')}.dsk")
  abort "no image at #{image}" unless File.exist?(image)
  [image, Apple2Emu.read_labels(LABELS)]
end

def run_apple(image, labels, commands)
  result = Apple2Emu.mame_run(image, labels: labels, tap: 'printchar_buffered',
                              auto_more: true, idle_exit: 12, idle_after: 25,
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

# --- go ---------------------------------------------------------------------

want_build = true
verbose = false
wanted = []
args = ARGV.dup
until args.empty?
  case (arg = args.shift)
  when '--no-build' then want_build = false
  when '-v', '--verbose' then verbose = true
  when '-h', '--help'
    puts File.read(__FILE__).lines[2..8].map { |l| l.sub(/^# ?/, '') }
    exit 0
  else
    abort "unknown game #{arg} (have: #{GAMES.keys.join(', ')})" unless GAMES.key?(arg)
    wanted << arg
  end
end
wanted = GAMES.keys if wanted.empty?

failed = false
wanted.each do |name|
  game = GAMES[name]
  image, labels = build(game[:story], want_build)
  a2_text, result = run_apple(image, labels, game[:commands])
  ref_text = run_dfrotz(game[:story], game[:commands])
  problems, notes = compare(name, game, a2_text, ref_text)

  puts
  puts "#{name} (#{game[:story]}): #{a2_text.length} characters printed, " \
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
