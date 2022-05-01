# frozen_string_literal: true

RSpec.describe "catalog/_document_list", type: :view do
  let(:documents) { [] }
  let(:blacklight_config) { Blacklight::Configuration.new }
  let(:document_offset) { 0 }
  let(:document_index_view_type) { "some-view" }
  let(:document_component) { Blacklight::DocumentComponent }
  let(:view_config) { Blacklight::Configuration::ViewConfig.new(document_component: document_component) }

  before do
    allow(view).to receive_messages(
      document_index_view_type: document_index_view_type,
      documents: documents,
      blacklight_config: blacklight_config
    )
    allow(blacklight_config).to receive(:view_config).with(any_args).and_return(view_config)
    assign(:response, instance_double(Blacklight::Solr::Response, start: document_offset))
  end

  it "includes a class for the current view" do
    render
    expect(rendered).to have_selector(".documents-some-view")
  end

  context 'has a document' do
    let(:document) { SolrDocument.new(id: 'xyz', format: 'a') }
    let(:documents) { [document] }
    let(:document_offset) { 20 }
    let(:document_partials) { %w[a b c] }
    let(:document_presenter) { instance_double(Blacklight::DocumentPresenter) }
    let(:view_config) do
      Blacklight::Configuration::ViewConfig.new(
        key: document_index_view_type, document_component: document_component,
        partials: document_partials, document_actions: []
      )
    end

    before do
      allow(document_presenter).to receive_messages(
        view_config: view_config,
        document: document,
        display_type: document_index_view_type,
        field_presenters: [],
        thumbnail: instance_double(Blacklight::ThumbnailPresenter, exists?: false)
      )
      allow(view).to receive(:link_to_document).with(document, any_args).and_return ""
      allow(view).to receive(:render_index_doc_actions).and_return ""
      allow(view).to receive(:document_presenter).with(document).and_return(document_presenter)
      allow(view).to receive(:search_session).and_return({})
      stub_template "catalog/_a_default.html.erb" => "a_partial"
      stub_template "catalog/_b_default.html.erb" => "b_partial"
      stub_template "catalog/_c_default.html.erb" => "c_partial"
    end

    it "uses the index.partials parameter to determine the partials to render" do
      render
      expect(rendered).to match(/a_partial/)
      expect(rendered).to match(/b_partial/)
      expect(rendered).to match(/c_partial/)
    end
  end
end
