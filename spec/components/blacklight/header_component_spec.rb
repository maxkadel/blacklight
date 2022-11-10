# frozen_string_literal: true

RSpec.describe Blacklight::HeaderComponent, type: :component do
  before do
    with_controller_class(CatalogController) do
      allow(controller).to receive(:current_user).and_return(nil)
      allow(controller).to receive(:search_action_url).and_return('/search')
      render
    end
  end

  context 'with no slots' do
    let(:render) { render_inline(described_class.new(blacklight_config: CatalogController.blacklight_config)) }

    it 'draws the topbar' do
      expect(page).to have_css 'nav.topbar'
      expect(page).to have_link 'Blacklight', href: '/'
    end
  end

  context 'with_top_bar slot' do
    let(:render) do
      render_inline(described_class.new(blacklight_config: CatalogController.blacklight_config)) do |c|
        c.with_top_bar(logo_link_text: 'Arclight')
      end
    end

    it 'draws the topbar' do
      expect(page).to have_css 'nav.topbar'
      expect(page).to have_link 'Arclight', href: '/'
    end
  end
end
