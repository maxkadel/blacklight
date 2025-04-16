# frozen_string_literal: true

RSpec.describe 'catalog/facet.html.erb' do
  let(:display_facet) { double }
  let(:blacklight_config) { Blacklight::Configuration.new }
  let(:component) { instance_double(Blacklight::FacetComponent) }
  let(:facet_suggest_input) { instance_double(Blacklight::Search::FacetSuggestInput) }

  before do
    allow(Blacklight::FacetComponent).to receive(:new).and_return(component)
    allow(Blacklight::Search::FacetSuggestInput).to receive(:new).and_return(facet_suggest_input)
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with(component)
    allow(view).to receive(:render).with(facet_suggest_input)

    blacklight_config.add_facet_field 'xyz', label: "Facet title"
    allow(view).to receive(:blacklight_config).and_return(blacklight_config)
    stub_template 'catalog/_facet_pagination.html.erb' => 'pagination'
    assign :facet, blacklight_config.facet_fields['xyz']
    assign :display_facet, display_facet
  end

  it "has the facet title" do
    render
    expect(rendered).to have_css 'h1', text: "Facet title"
  end

  it "renders the facet suggest input" do
    render
    expect(view).to have_received(:render).with(facet_suggest_input)
  end

  it "renders facet pagination" do
    render
    expect(rendered).to have_content 'pagination'
  end

  it "renders the facet limit" do
    render
    expect(view).to have_received(:render).with(component)
  end
end
