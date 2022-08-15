# frozen_string_literal: true

module Blacklight
  module Rendering
    class Join < AbstractStep
      def render
        options = config.separator_options || {}
        if !html?
          next_step(values.join("\n"))
        else
          next_step(values.map { |x| html_escape(x) }.to_sentence(options).html_safe)
        end
      end

      private

      def html_escape(*args)
        ERB::Util.html_escape(*args)
      end
    end
  end
end
