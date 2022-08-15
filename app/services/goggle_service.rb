class GoggleService
  attr_accessor :instructions

  def initialize(url, text: nil, file_name: nil)
    @url = url
    if text.present?
      instuction_strs = text.split("\n")
      self.instructions = instuction_strs.map { |str| GoggleInstruction.new(str) }
    elsif file_name.present?
      self.instructions = File.foreach(file_name).map do |line|
        GoggleInstruction.new(line)
      end
    end
  end

  def result
    test_results = instructions.map { |inst| inst.test(@url) }
    test_results.reject! { |r| r.nil? }
    if test_results.empty?
      return 0
    else
      return test_results.sort.last[1]
    end
  end

  class GoggleInstruction
    attr_accessor :options, :pattern, :action
    def initialize(instruction_str)
      parse(instruction_str)
    end

    def parse(instruction_str)
      # split on $ to get options
      pattern_str, options_str = instruction_str.split("$")
      parse_pattern(pattern_str)
      parse_options(options_str) if options_str.present?
    end

    # tests the instruction against a url and returns the action if the instruction applies
    # the action is a positive integer for boost, negative for downrank and 0 for discard.
    # Returns nil if it doesn't apply
    def test(url_str, title: nil, description:nil, content: nil)
      uri = URI.parse(url_str)
      if options.present? && options[:site].present? && uri.host != options[:site]
        return nil
      end
      if options[:inurl]
        if pattern.present? && pattern.match(url_str).present?
          action
        end
      elsif options[:intitle]
        if pattern.present? && pattern.match(title).present?
          action
        end
      elsif options[:indescription]
        if pattern.present? && pattern.match(description).present?
          action
        end
      elsif options[:incontent]
        if pattern.present? && pattern.match(content).present?
          action
        end
      end
    end

    def parse_options(options_str)
      # split options on , to get list of options
      options_arr = options_str.split(",")
      options = options_arr.map do |str|
        # split an option on = to get key value
        key, value = str.split("=")
        key.strip!
        key = key.to_sym
        if value.present?
          value.strip!
        else
          if [:inurl, :intitle, :indescription, :incontent, :discard].include?(key)
            value = true
          end
        end
        [key.to_sym, value]
      end.to_h
      actions = options.slice(:boost, :downrank, :discard)
      self.options = options.slice(:site, :inurl, :intitle, :indescription, :incontent)
      setup_action(options)
      self.options[:inurl] = true if options.slice(:inurl, :intitle, :indescription, :incontent).blank?
    end

    def setup_action(options)
      actions = options.slice(:boost, :downrank, :discard)
      if actions.length > 0
        case actions.first[0]
        when :boost
          if actions[:boost].present?
            self.action = ["o", actions[:boost].to_i]
          else
            self.action = ["o", 1]
          end
        when :downrank
          if actions[:downrank].present?
            self.action = ["d", -actions[:downrank].to_i]
          else
            self.action = ["d", -1]
          end
        when :discard
          if self.options.empty? && self.pattern == //
            self.action = ["X"]
          else
            self.action = ["x"]
          end
        end
      end
    end

    def parse_pattern(pattern_str)
      # escape the patter_str
      pattern_esc = Regexp.escape pattern_str
      pattern_esc = pattern_esc.gsub(/^\\\|/, "^")
      pattern_esc = pattern_esc.gsub(/\\\|$/, "$")
      pattern_esc = pattern_esc.gsub(/\\\*/, ".*")
      pattern_esc = pattern_esc.gsub(/\\\^/, "([^\\w\\d._%-]|$)")
      self.pattern = Regexp.new pattern_esc
    end
  end
end
