require 'test_helper'

class GoggleServiceTest < ActiveSupport::TestCase

  # initialization
  test "parsing a text list of instructions" do
    text = <<~INST
      /any/path$boost     
      $discard
    INST
    srv = GoggleService.new "", text: text
    assert_equal 2, srv.instructions.count
    assert_equal ["o", 1], srv.instructions[0].action
    assert_equal ["X"], srv.instructions[1].action
  end

  test "parsing against a file" do
    file = file_name "basic.goggle"
    srv = GoggleService.new "", file_name: file
    assert_equal 2, srv.instructions.count
    assert_equal ["o", 1], srv.instructions[0].action
    assert_equal ["X"], srv.instructions[1].action
  end

  #test full list against url
  test "full match against full instructions should boost" do
    file = file_name "basic.goggle"
    srv = GoggleService.new "https://example.com/any/path", file_name: file
    assert_equal 1, srv.result
  end

  test "no match against full instructions should discard" do
    file = file_name "basic.goggle"
    srv = GoggleService.new "https://example.com/no/path", file_name: file
    assert_nil srv.result
  end

  test "no match at all should return 0" do
    text = <<~INST
      /any/path$boost     
    INST
    srv = GoggleService.new "https://example.com/no/path", text: text
    assert_equal 0, srv.result
  end

  test "precedence" do
    text = <<~INST
      $boost=3,site=example.com
      $boost=1,site=example.com
    INST
    srv = GoggleService.new "https://example.com/posts/hello.html", text: text
    assert_equal 3, srv.result
    text = <<~INST
      $downrank=3,site=example.com
      /posts/$boost=3
    INST
    srv = GoggleService.new "https://example.com/posts/hello.html", text: text
    assert_equal 3, srv.result
  end

  # Instruction parsing
  test "parsing site option" do
    inst = GoggleService::GoggleInstruction.new("$site=example.com")
    assert_equal "example.com", inst.options[:site]
  end

  test "parsing inurl option" do
    inst = GoggleService::GoggleInstruction.new("$inurl")
    assert inst.options == {inurl: true}
  end

  test "parsing intitle option" do
    inst = GoggleService::GoggleInstruction.new("$intitle")
    assert inst.options == {intitle: true}
  end

  test "parsing indescription option" do
    inst = GoggleService::GoggleInstruction.new("$indescription")
    assert inst.options == {indescription: true}
  end

  test "parsing incontent option" do
    inst = GoggleService::GoggleInstruction.new("$incontent")
    assert inst.options == {incontent: true}
  end

  # Action parsing for precedence, ["action", value]
  # non generic discard -> ["x"]
  # boost with the highest number -> positive integer ["o", 1]
  # downrank with the lowest number -> highest negative integer ["d", -1]
  # generic discard -> ["X"]

  test "parsing boost action" do
    inst = GoggleService::GoggleInstruction.new("$boost=1")
    assert_equal ["o", 1], inst.action
  end
  
  test "parsing boost action with no value" do
    inst = GoggleService::GoggleInstruction.new("$boost")
    assert_equal ["o", 1], inst.action
  end
  
  test "parsing downrank action" do
    inst = GoggleService::GoggleInstruction.new("$downrank=1")
    assert_equal ["d", -1], inst.action
  end

  test "parsing downrank action with no value" do
    inst = GoggleService::GoggleInstruction.new("$downrank")
    assert_equal ["d", -1], inst.action
  end

  test "parsing generic discard action" do
    inst = GoggleService::GoggleInstruction.new("$discard")
    assert_equal ["X"], inst.action
  end

  test "parsing non generic discard action" do
    inst = GoggleService::GoggleInstruction.new("$discard, site=example.com")
    assert_equal ["x"], inst.action
    inst = GoggleService::GoggleInstruction.new("/any/path$discard")
    assert_equal ["x"], inst.action
  end

  test "parsing multiple options with whitespace" do
    inst = GoggleService::GoggleInstruction.new("$discard, site=example.com")
    assert_equal ["x"], inst.action
    assert_equal inst.options[:site], "example.com"
  end

  test "no pattern site and boost boosts any url from site" do
    inst = GoggleService::GoggleInstruction.new("$boost=1, site=example.com")
    result = inst.test("https://example.com/any/path")
    assert_equal ["o", 1], result
    result = inst.test("https://en.example.com/any/path")
    assert_nil result
  end

  test "no pattern discard discards any url" do
    inst = GoggleService::GoggleInstruction.new("$discard")
    result = inst.test("https://example.com")
    assert_equal ["X"], result
  end

  test "basic pattern parsing" do
    inst = GoggleService::GoggleInstruction.new("/any/path")
    assert_equal Regexp.new("\/any\/path"), inst.pattern
  end

  test "match basic pattern and boost" do
    inst = GoggleService::GoggleInstruction.new("/any/path$boost")
    result = inst.test("https://example.com/any/path")
    assert_equal ["o", 1], result
    result = inst.test("https://example.com/any")
    assert_nil result
  end

  test "parsing a globbing pattern" do
    inst = GoggleService::GoggleInstruction.new("/any/*/path")
    assert_equal /\/any\/.*\/path/, inst.pattern
  end

  test "match globbing pattern and boost" do
    inst = GoggleService::GoggleInstruction.new("/any/*/path$boost")
    result = inst.test("https://example.com/any/glob/path")
    assert_equal ["o", 1], result
    result = inst.test("https://example.com/any/path")
    assert_nil result
  end

  test "parsing url delimiter" do
    inst = GoggleService::GoggleInstruction.new("foo.js^")
    assert_equal /foo\.js([^\w\d._%-]|$)/, inst.pattern
  end

  test "match url delimeter and boost" do
    #inst = GoggleService::GoggleInstruction.new("|https://example.org^$boost")
    #result = inst.test("https://example.org")
    #assert_equal 1, result
    #result = inst.test("https://example.org/")
    #assert_equal 1, result
    #result = inst.test("https://example.org/path")
    #assert_equal 1, result
    #result = inst.test("https://example.org.ac")
    #assert_nil result
    inst = GoggleService::GoggleInstruction.new("/foo.js^$boost")
    result = inst.test("https://example.org/foo.js")
    assert_equal ["o", 1], result
    result = inst.test("https://example.org/foo.js?param=42")
    assert_equal ["o", 1], result
    result = inst.test("https://example.org/foo.js/")
    assert_equal ["o", 1], result
    result = inst.test("https://example.org/foo.jsx")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("^cis198-2016s^$boost=3")
    result = inst.test("https://example.org/cis198-2016s/")
    assert_equal ["o", 3], result
    result = inst.test("https://example.org/xcis198-2016s/")
    assert_nil result
  end

  test "parsing anchors" do
    inst = GoggleService::GoggleInstruction.new("|https://en.")
    assert_equal /^https:\/\/en\./, inst.pattern
    inst = GoggleService::GoggleInstruction.new("/some/path.html|")
    assert_equal /\/some\/path\.html$/, inst.pattern
    inst = GoggleService::GoggleInstruction.new("|https://brave.com|")
    assert_equal /^https:\/\/brave\.com$/, inst.pattern
  end

  test "match anchors and boost" do
    inst = GoggleService::GoggleInstruction.new("|https://en.$boost")
    result = inst.test("https://en.wikipedia.org")
    assert_equal ["o", 1], result
    result = inst.test("https://de.wikipedia.org")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("/some/path.html|$boost")
    result = inst.test("https://de.wikipedia.org/some/path.html")
    assert_equal ["o", 1], result
    result = inst.test("https://de.wikipedia.org/some/path.html?nope=1")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("|https://brave.com|$boost")
    result = inst.test("https://brave.com")
    assert_equal ["o", 1], result
    result = inst.test("https://brave.com/some_path")
    assert_nil result
    result = inst.test("https://en.brave.com")
    assert_nil result
  end

  test "intitle option and boost" do
    inst = GoggleService::GoggleInstruction.new("good title$intitle, boost")
    result = inst.test("https://en.brave.com", title: "this is a good title")
    assert_equal ["o", 1], result
    result = inst.test("https://en.brave.com", title: "this is a bad title")
    assert_nil result
  end

  test "indescription option and boost" do
    inst = GoggleService::GoggleInstruction.new("good description$indescription, boost")
    result = inst.test("https://en.brave.com", description: "this is a good description")
    assert_equal ["o", 1], result
    result = inst.test("https://en.brave.com", description: "this is a bad description")
    assert_nil result
  end

  test "incontent option and boost" do
    inst = GoggleService::GoggleInstruction.new("good content$incontent, boost")
    result = inst.test("https://en.brave.com", content: "this is a good content")
    assert_equal ["o", 1], result
    result = inst.test("https://en.brave.com", content: "this is a bad content")
    assert_nil result
  end
end

