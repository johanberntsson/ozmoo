# runprg.rb <prg> [d64] [seconds] - mount, reset, run a PRG, read the screen ONCE.
# Deliberately does not poll: every machine:readmem is a DMA that steals C64
# cycles and corrupts the cycle-exact IEC transfer (see fastloader-notes.md).
load File.join(__dir__, "u64.rb")

prg, img, secs = ARGV[0], ARGV[1], (ARGV[2] || 20).to_i
mount(img) if img
reset
sleep 12               # a C64 reset resets the drive too; let its init finish
req(Net::HTTP::Post, "/v1/runners:run_prg", File.binread(prg))
sleep secs
rows(screen).each { |r| puts r.rstrip unless r.strip.empty? }
