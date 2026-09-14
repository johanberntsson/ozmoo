# measure.rb <prg> [runs] - reset, run a benchmark PRG, parse its result line.
$LOAD_PATH.unshift __dir__
require_relative "screens"
load File.join(__dir__, "u64.rb")

def measure(prg, runs = 3)
  results = []
  runs.times do
    reset
    wait_for("ready.", 30)
    sleep 6          # a C64 reset resets the drive too; let it finish init
    req(Net::HTTP::Post, "/v1/runners:run_prg", File.binread(prg))
    line = nil
    90.times do
      line = rows(screen).map(&:rstrip).find { |r| r.include?("blocks=") }
      break if line
      sleep 1
    end
    results << line.to_s.strip
  end
  results
end

if __FILE__ == $0
  prg = ARGV[0]
  measure(prg, (ARGV[1] || 3).to_i).each_with_index do |r, i|
    if r =~ /blocks=\$(\h+)\s+jiffies=\$(\h+)\s+cksum=\$(\h+)/
      blocks, jif, ck = $1.to_i(16), $2.to_i(16), $3
      secs = jif / 60.0
      printf "run %d: %2d blocks  %6.2f s  %6.1f ms/block  %6.0f B/s  cksum=$%s\n",
             i, blocks, secs, secs * 1000 / blocks, blocks * 256 / secs, ck
    else
      puts "run #{i}: #{r.inspect}"
    end
  end
end
