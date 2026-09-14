# Minimal d64 reader: pull the first PRG off a disk image as a runnable file.
def d64_track_offset(track, sector)
  base = if track <= 17 then (track - 1) * 21
         elsif track <= 24 then 17 * 21 + (track - 18) * 19
         elsif track <= 30 then 17 * 21 + 7 * 19 + (track - 25) * 18
         else 17 * 21 + 7 * 19 + 6 * 18 + (track - 31) * 17 end
  (base + sector) * 256
end

def d64_first_prg(path)
  d = File.binread(path)
  off = d64_track_offset(18, 1)
  track = sector = nil
  8.times do |i|
    e = d[off + 2 + i * 32, 32]
    next unless (e[0].ord & 0x0f) == 2      # PRG
    track, sector = e[1].ord, e[2].ord
    break
  end
  raise "no PRG on #{path}" unless track
  out = +"".b
  while track != 0
    s = d[d64_track_offset(track, sector), 256]
    nt, ns = s[0].ord, s[1].ord
    out << (nt.zero? ? s[2, ns - 1] : s[2, 254])
    track, sector = nt, ns
  end
  out
end

if __FILE__ == $0
  prg = d64_first_prg(ARGV[0])
  File.binwrite(ARGV[1], prg)
  puts "#{ARGV[1]}: #{prg.size} bytes, load address $%04x" % (prg[0].ord | (prg[1].ord << 8))
end
