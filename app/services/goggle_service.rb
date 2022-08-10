class GoggleService
  class GoggleInstruction
    attr_accessor :options, :pattern, :action
    def initialize(instruction_str)
      parse(instruction_str)
    end

    def parse(instruction_str)
      # split on $ to get options
      pattern_str, options_str = instruction_str.split("$")
      parse_options(options_str) if options_str.present?
      parse_pattern(pattern_str)
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
      setup_action(options)
      self.options = options.slice(:site, :inurl, :intitle, :indescription, :incontent)
      self.options[:inurl] = true if options.slice(:inurl, :intitle, :indescription, :incontent).blank?
    end

    def setup_action(options)
      actions = options.slice(:boost, :downrank, :discard)
      if actions.length > 0
        case actions.first[0]
        when :boost
          if actions[:boost].present?
            self.action = actions[:boost].to_i
          else
            self.action = 1
          end
        when :downrank
          if actions[:downrank].present?
            self.action = -actions[:downrank].to_i
          else
            self.action = -1
          end
        when :discard
          self.action = 0
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
