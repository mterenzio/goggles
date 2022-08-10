require 'test_helper'

class GoggleServiceTest < ActiveSupport::TestCase



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

  test "parsing boost action" do
    inst = GoggleService::GoggleInstruction.new("$boost=1")
    assert_equal 1, inst.action
  end
  
  test "parsing boost action with no value" do
    inst = GoggleService::GoggleInstruction.new("$boost")
    assert_equal 1, inst.action
  end
  
  test "parsing downrank action" do
    inst = GoggleService::GoggleInstruction.new("$downrank=1")
    assert_equal -1, inst.action
  end

  test "parsing downrank action with no value" do
    inst = GoggleService::GoggleInstruction.new("$downrank")
    assert_equal -1, inst.action
  end

  test "parsing discard action" do
    inst = GoggleService::GoggleInstruction.new("$discard")
    assert_equal 0, inst.action
  end

  test "parsing multiple options with whitespace" do
    inst = GoggleService::GoggleInstruction.new("$discard, site=example.com")
    assert_equal 0, inst.action
    assert_equal inst.options[:site], "example.com"
  end

  test "no pattern site and boost boosts any url from site" do
    inst = GoggleService::GoggleInstruction.new("$boost=1, site=example.com")
    result = inst.test("https://example.com/any/path")
    assert_equal 1, result
    result = inst.test("https://en.example.com/any/path")
    assert_nil result
  end

  test "no pattern discard discards any url" do
    inst = GoggleService::GoggleInstruction.new("$discard")
    result = inst.test("https://example.com")
    assert_equal 0, result
  end

  test "basic pattern parsing" do
    inst = GoggleService::GoggleInstruction.new("/any/path")
    assert_equal Regexp.new("\/any\/path"), inst.pattern
  end

  test "match basic pattern and boost" do
    inst = GoggleService::GoggleInstruction.new("/any/path$boost")
    result = inst.test("https://example.com/any/path")
    assert_equal 1, result
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
    assert_equal 1, result
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
    assert_equal 1, result
    result = inst.test("https://example.org/foo.js?param=42")
    assert_equal 1, result
    result = inst.test("https://example.org/foo.js/")
    assert_equal 1, result
    result = inst.test("https://example.org/foo.jsx")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("^cis198-2016s^$boost=3")
    result = inst.test("https://example.org/cis198-2016s/")
    assert_equal 3, result
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
    assert_equal 1, result
    result = inst.test("https://de.wikipedia.org")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("/some/path.html|$boost")
    result = inst.test("https://de.wikipedia.org/some/path.html")
    assert_equal 1, result
    result = inst.test("https://de.wikipedia.org/some/path.html?nope=1")
    assert_nil result
    inst = GoggleService::GoggleInstruction.new("|https://brave.com|$boost")
    result = inst.test("https://brave.com")
    assert_equal 1, result
    result = inst.test("https://brave.com/some_path")
    assert_nil result
    result = inst.test("https://en.brave.com")
    assert_nil result
  end

  test "intitle option and boost" do
    inst = GoggleService::GoggleInstruction.new("good title$intitle, boost")
    result = inst.test("https://en.brave.com", title: "this is a good title")
    assert_equal 1, result
    result = inst.test("https://en.brave.com", title: "this is a bad title")
    assert_nil result
  end

  test "indescription option and boost" do
    inst = GoggleService::GoggleInstruction.new("good description$indescription, boost")
    result = inst.test("https://en.brave.com", description: "this is a good description")
    assert_equal 1, result
    result = inst.test("https://en.brave.com", description: "this is a bad description")
    assert_nil result
  end

  test "incontent option and boost" do
    inst = GoggleService::GoggleInstruction.new("good content$incontent, boost")
    result = inst.test("https://en.brave.com", content: "this is a good content")
    assert_equal 1, result
    result = inst.test("https://en.brave.com", content: "this is a bad content")
    assert_nil result
  end
end

