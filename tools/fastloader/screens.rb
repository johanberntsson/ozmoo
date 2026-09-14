# Parse VICE "m 0400 07e7" screen dumps out of a monitor log.
# Bytes are placed by ADDRESS, not by concatenation: a VICE dump line ends with
# an ASCII gutter ("A.. .....:") whose leading token can look like a hex byte,
# so counting tokens is not safe. Each screen is 1000 bytes at $0400.
BASE = 0x0400
def parse_screens(path)
  screens, cur = [], nil
  File.foreach(path) do |line|
    next unless line =~ /^>C:(\h{4})\s+(.*)/
    addr = $1.to_i(16)
    bytes = $2.split.take_while { |t| t =~ /\A\h\h\z/ }.first(16).map { |h| h.to_i(16) }
    if addr == BASE
      screens << cur if cur
      cur = Array.new(1000, 0x20)
    end
    next unless cur
    off = addr - BASE
    bytes.each_with_index { |b, i| cur[off + i] = b if off + i < 1000 }
  end
  screens << cur if cur
  screens
end
def sc(b)
  b &= 0x7f
  case b
  when 0x00 then '@'
  when 0x01..0x1a then (b + 96).chr
  when 0x1b then '['
  when 0x1d then ']'
  when 0x5d then '|'
  when 0x6f then '_'   # and '_' as another graphic   # Ozmoo prints '|' as a vertical-bar graphic (see releasenotes.txt)
  when 0x20..0x3f then b.chr
  when 0x41..0x5a then b.chr
  else '~'
  end
end
def rows(screen) = (0...25).map { |r| screen[r * 40, 40].map { |b| sc(b) }.join }

# Locate a dumped screen as a contiguous window into the reference transcript.
# Screens are windows, not a stream to be re-stitched: overlap heuristics break
# whenever the game prints the same block twice.
def find_window(ref, scr)
  rws = scr.map(&:rstrip)
  rws = rws[0, rws.rindex { |r| !r.empty? }.to_i + 1]
  return :empty if rws.empty?
  (0..(ref.size - rws.size)).find { |i| ref[i, rws.size] == rws }
end

# Screens captured from real hardware: a flat file of consecutive 1000-byte dumps.
def parse_binary(path)
  File.binread(path).bytes.each_slice(1000).select { |s| s.size == 1000 }
end
