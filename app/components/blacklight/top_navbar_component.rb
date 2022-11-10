# frozen_string_literal: true

module Blacklight
  class TopNavbarComponent < Blacklight::Component
    def initialize(blacklight_config:, logo_link_text: application_name)
      @blacklight_config = blacklight_config
      @logo_link_text = logo_link_text
    end

    attr_reader :blacklight_config

    def logo_link
      link_to @logo_link_text, blacklight_config.logo_link, class: 'mb-0 navbar-brand navbar-logo'
    end
  end
end
