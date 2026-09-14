#!/usr/bin/env ruby
# Drive Ozmoo on a real Ultimate 64 over its REST API.
# Same screen decoding as the VICE harness (screens.rb); only the transport differs.
require "net/http"
require "json"
require_relative "screens"
require_relative "d64"

HOST = ENV["U64"] || "192.168.1.148"
SCREEN, MORE_CELL, MORE_MARK = 0x0400, 999, 0xaa  # show_more_prompt writes 128+$2a there

def http = Net::HTTP.start(HOST, 80, open_timeout: 5, read_timeout: 15)
def req(m, path, body = nil, ctype = nil)
  r = m.new(path)
  if body then r.body = body; r["Content-Type"] = ctype || "application/octet-stream" end
  http.request(r)
end
def screen = req(Net::HTTP::Get, "/v1/machine:readmem?address=0400&length=1000").body.bytes.first(1000)
def peek(addr, len = 1)
  req(Net::HTTP::Get, "/v1/machine:readmem?address=%04x&length=%d" % [addr, len]).body.bytes.first(len)
end
def poke(addr, bytes)
  req(Net::HTTP::Put, "/v1/machine:writemem?address=%04x&data=%s" % [addr, bytes.map { |b| "%02x" % b }.join])
end

# The REST keyboard endpoint delivers with noticeable latency; poking the
# kernal keyboard buffer ($0277, count in $c6) is immediate and deterministic.
KEYBUF, NDX = 0x0277, 0x00c6
def poke_keys(str)
  # One character at a time: batching into the 10-byte buffer loses the
  # trailing CR, and the CR is the character that actually does anything.
  str.upcase.each_byte do |b|
    poke(KEYBUF, [b])
    poke(NDX, [1])
    40.times { break if peek(NDX).first.to_i.zero?; sleep 0.05 }
  end
end
def reset  = req(Net::HTTP::Put, "/v1/machine:reset")
def mount(path, mode = "readonly")
  req(Net::HTTP::Post, "/v1/drives/a:mount?type=d64&mode=#{mode}", File.binread(path))
end
# A single "tap" is too short to survive a keyboard scan - the first one after
# any idle period is silently dropped. Press, hold across a scan, then release.
def hold(key, ms = 60)
  ev = ->(t) { req(Net::HTTP::Post, "/v1/machine:input",
      { events: [{ kind: "keyboard", inputs: [key.to_s], transition: t }] }.to_json,
      "application/json") }
  ev.("press"); sleep ms / 1000.0; ev.("release"); sleep 0.08
end

KEYNAME = { " " => "space", "\r" => "return", "," => "comma", "*" => "star", ":" => "colon" }
def type_keys(str)
  str.each_char { |c| hold(KEYNAME[c] || c) }
end

# The cursor blinks in reverse video, so raw screens never compare equal.
# Mask bit 7 for idle detection; the MORE marker is checked on the raw byte.
def steady(s) = s.map { |b| b & 0x7f }

def type_and_verify(word, tries = 3)
  tries.times do
    type_keys(word)
    sleep 0.6
    return true if rows(screen).any? { |r| r.include?(word) }
    hold("return"); sleep 0.6
  end
  false
end

def tap(*keys)
  events = keys.map { |k| { kind: "keyboard", inputs: [k.to_s], transition: "tap" } }
  req(Net::HTTP::Post, "/v1/machine:input", { events: events }.to_json, "application/json")
end
# Map the characters we need to U64 key names; '"' is shift+2 on a C64.
KEYMAP = { '"' => %w[left_shift 2], "," => %w[comma], "*" => %w[star],
           ":" => %w[colon], "$" => %w[left_shift 4] }
def type_text(str)
  events = str.chars.map do |c|
    { kind: "keyboard", inputs: KEYMAP[c] || [c], transition: "tap" }
  end
  events << { kind: "keyboard", inputs: ["return"], transition: "tap" }
  req(Net::HTTP::Post, "/v1/machine:input", { events: events }.to_json, "application/json")
end

def wait_for(text, timeout = 30)
  deadline = Time.now + timeout
  while Time.now < deadline
    return true if rows(screen).any? { |r| r.include?(text) }
    sleep 0.2
  end
  false
end

# Boot by DMA-loading the disk's PRG and running it. Typing LOAD/RUN into BASIC
# races against the reset banner's own "ready." and drops the trailing CR.
def boot_disk(img, mode = "readonly")
  mount(img, mode)
  sleep 1
  req(Net::HTTP::Post, "/v1/runners:run_prg", d64_first_prg(img))
end

def wait_for(text, timeout = 30)
  deadline = Time.now + timeout
  while Time.now < deadline
    return true if rows(screen).any? { |r| r.include?(text) }
    sleep 0.2
  end
  false
end

if __FILE__ == $0
  cmd = ARGV[0]
  case cmd
  when "mount" then puts mount(ARGV[1]).code
  when "reset" then puts reset.code
  when "screen"
    s = screen
    rows(s).each_with_index { |r, i| puts "r%02d |%s|" % [i, r.rstrip] }
  when "run"
    # run <d64> <outfile> [seconds] [word-to-type-at-first-prompt] [reu Y/N]
    img, out, secs, word = ARGV[1], ARGV[2], (ARGV[3] || 180).to_i, ARGV[4]
    reu = ARGV[5] || "Y"
    boot_disk(img)
    if wait_for("Use REU", 30)
      poke_keys(reu)
      sleep 2
    end
    dumps, prev, idle, typed = [], nil, 0, false
    deadline = Time.now + secs
    while Time.now < deadline
      s = screen
      if s[MORE_CELL] == MORE_MARK
        dumps << s.dup; hold("space"); prev, idle = nil, 0
      elsif steady(s) == prev
        idle += 1
        if idle == 6
          dumps << s.dup
          if word && !typed
            type_and_verify(word); hold("return"); typed = true
          else
            break if rows(s).any? { |r| r.include?("press any key") }
            hold("space")
          end
          idle = 0
        end
      else
        idle = 0
      end
      prev = steady(s)
      sleep 0.05
    end
    dumps << screen
    File.open(out, "wb") { |f| dumps.each { |d| f.write(d.pack("C*")) } }
    puts "captured #{dumps.size} screens -> #{out}"
  end
end
