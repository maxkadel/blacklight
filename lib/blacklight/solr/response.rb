# frozen_string_literal: true

class Blacklight::Solr::Response < ActiveSupport::HashWithIndifferentAccess
  include PaginationMethods
  include Spelling
  include Facets
  include Response
  include MoreLikeThis
  include Params

  attr_reader :request_params, :search_builder
  attr_accessor :blacklight_config, :options

  delegate :document_factory, to: :blacklight_config

  # @param [Hash] data
  # @param [Hash, Blacklight::SearchBuilder] request_params a SearchBuilder or a Hash of parameters
  def initialize(data, request_params, options = {})
    @search_builder = request_params if request_params.is_a?(Blacklight::SearchBuilder)

    super(force_to_utf8(ActiveSupport::HashWithIndifferentAccess.new(data)))
    @request_params = ActiveSupport::HashWithIndifferentAccess.new(request_params)
    self.blacklight_config = options[:blacklight_config]
    self.options = options
  end

  def header
    self['responseHeader'] || {}
  end

  def documents
    @documents ||= (response['docs'] || []).collect { |doc| document_factory.build(doc, self, options) }
  end
  alias_method :docs, :documents

  def grouped
    @groups ||= self["grouped"].map do |field, group|
      # grouped responses can either be grouped by:
      #   - field, where this key is the field name, and there will be a list
      #        of documents grouped by field value, or:
      #   - function, where the key is the function, and the documents will be
      #        further grouped by function value, or:
      #   - query, where the key is the query, and the matching documents will be
      #        in the doclist on THIS object
      if group["groups"] # field or function
        GroupResponse.new field, group, self
      else # query
        Group.new field, group, self
      end
    end
  end

  def group key
    grouped.find { |x| x.key == key }
  end

  def grouped?
    key? "grouped"
  end

  def export_formats
    documents.map { |x| x.export_formats.keys }.flatten.uniq
  end

  private

  def force_to_utf8(value)
    case value
    when Hash
      value.each { |k, v| value[k] = force_to_utf8(v) }
    when Array
      value.each { |v| force_to_utf8(v) }
    when String
      if value.encoding == Encoding::UTF_8
        value
      else
        Blacklight.logger&.warn "Found a non utf-8 value in Blacklight::Solr::Response. \"#{value}\" Encoding is #{value.encoding}"
        value.dup.force_encoding('UTF-8')
      end
    end
    value
  end
end
