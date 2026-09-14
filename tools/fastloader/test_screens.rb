require "minitest/autorun"
require "tempfile"
require_relative "screens"

class TestScreens < Minitest::Test
  # A VICE dump line ends with an ASCII gutter whose first token can look like
  # a hex byte ("ad "). Parsing must not mistake it for a 17th byte.
  def test_ascii_gutter_is_not_parsed_as_data
    log = Tempfile.new("log")
    16.times { |i| log.puts ">C:%04x  %s   ad be" % [0x0400 + i * 16, (["41"] * 16).join(" ")] }
    log.close
    assert_equal [0x41] * 256, parse_screens(log.path).first[0, 256],
                 "ASCII gutter token leaked into screen data"
  end

  # Ozmoo prints '|' as screen code $5d, a vertical-bar graphic (releasenotes.txt).
  def test_pipe_glyph_decodes_to_pipe
    assert_equal "|", sc(0x5d)
  end

  # The game may print the same block twice running; locating a screen must not
  # be confused by the repeat (this is what the old overlap-stitcher got wrong).
  def test_underscore_glyph_decodes_to_underscore
    assert_equal "_", sc(0x6f)
  end

  def test_repeated_block_does_not_shift_the_window
    ref = ["a", "dup", "end", "dup", "end", "b", "c"]
    assert_equal 1, find_window(ref, ["dup", "end", "dup", "end", "b", ""])
  end

  def test_screen_not_in_reference_is_reported
    assert_nil find_window(%w[a b c], ["x", "y"])
  end
end
