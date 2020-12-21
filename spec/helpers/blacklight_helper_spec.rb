# frozen_string_literal: true
RSpec.describe BlacklightHelper do
  before do
    allow(helper).to receive(:current_or_guest_user).and_return(User.new)
    allow(helper).to receive(:search_action_path) do |*args|
      search_catalog_url *args
    end
  end

  describe "#application_name" do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::NullStore.new)
    end

    it "defaults to 'Blacklight'" do
      expect(application_name).to eq "Blacklight"
    end

    context "when the language is not english " do
      around do |example|
        I18n.locale = :de
        example.run
        I18n.locale = :en
      end

      context "and no translation exists for that language" do
        it "defaults to 'Blacklight'" do
          expect(application_name).to eq "Blacklight"
        end
      end

      context "and a translation exists for that language" do
        around do |example|
          I18n.backend.store_translations(:de, 'blacklight' => { 'application_name' => 'Schwarzlicht' })
          example.run
          I18n.backend.reload!
        end

        it "uses the provided value" do
          expect(application_name).to eq "Schwarzlicht"
        end
      end
    end
  end

  describe "#render_page_title" do
    it "looks in content_for(:page_title)" do
      helper.content_for(:page_title) { "xyz" }
      expect(helper.render_page_title).to eq "xyz"
    end

    it "looks in the @page_title ivar" do
      assign(:page_title, "xyz")
      expect(helper.render_page_title).to eq "xyz"
    end

    it "defaults to the application name" do
      expect(helper.render_page_title).to eq helper.application_name
    end
  end

  describe "render_link_rel_alternates" do
    let(:document) { instance_double(SolrDocument) }
    let(:result) { double }
    let(:view_context) { double(blacklight_config: blacklight_config, document_index_view_type: 'index') }
    let(:presenter) { Blacklight::IndexPresenter.new(document, view_context) }
    let(:blacklight_config) do
      Blacklight::Configuration.new.configure do |config|
        config.index.title_field = 'title_tsim'
        config.index.display_type_field = 'format'
      end
    end

    before do
      allow(helper).to receive(:presenter).and_return(presenter)
      allow(helper).to receive(:blacklight_config).and_return(blacklight_config)
    end

    it "generates <link rel=alternate> tags" do
      expect(presenter).to receive(:link_rel_alternates).and_return(result)
      expect(helper.render_link_rel_alternates(document)).to eq result
    end

    it "sends parameters" do
      expect(presenter).to receive(:link_rel_alternates).with(unique: true).and_return(result)
      expect(helper.render_link_rel_alternates(document, unique: true)).to eq result
    end
  end

  describe "with a config" do
    let(:config) do
      Blacklight::Configuration.new.configure do |config|
        config.index.title_field = 'title_tsim'
        config.index.display_type_field = 'format'
      end
    end
    let(:document) { SolrDocument.new('title_tsim' => "A Fake Document", 'id' => '8') }

    before do
      config.add_show_tools_partial(:bookmark, partial: 'catalog/bookmark_control')
      config.add_results_document_tool(:bookmark, partial: 'catalog/bookmark_control', if: :render_bookmarks_control?)
      config.add_nav_action(:bookmark, partial: 'blacklight/nav/bookmark')
      allow(helper).to receive(:blacklight_config).and_return(config)
      allow(helper).to receive_messages(current_bookmarks: [])
    end

    describe "render_nav_actions" do
      it "renders partials" do
        buff = String.new
        helper.render_nav_actions { |_config, item| buff << "<foo>#{item}</foo>" }
        expect(buff).to have_selector "foo a#bookmarks_nav[href=\"/bookmarks\"]"
        expect(buff).to have_selector "foo a span[data-role='bookmark-counter']", text: '0'
      end
    end

    describe "render_index_doc_actions" do
      it "renders partials" do
        allow(controller).to receive(:render_bookmarks_control?).and_return(true)
        response = helper.render_index_doc_actions(document)
        expect(response).to have_selector(".bookmark-toggle")
      end

      it "is nil if no partials are renderable" do
        allow(controller).to receive(:render_bookmarks_control?).and_return(false)
        expect(helper.render_index_doc_actions(document)).to be_blank
      end

      it "renders view type specific actions" do
        allow(helper).to receive(:document_index_view_type).and_return(:custom)
        config.view.custom(document_actions: [])
        expect(helper.render_index_doc_actions(document)).to be_blank
      end
    end

    describe "render_show_doc_actions" do
      it "renders partials" do
        response = helper.render_show_doc_actions(document)
        expect(response).to have_selector(".bookmark-toggle")
      end
    end
  end

  describe "#should_render_index_field?" do
    before do
      allow(helper).to receive_messages(should_render_field?: true, document_has_value?: true)
    end

    it "is true" do
      expect(Deprecation).to receive(:warn)
      expect(helper.should_render_index_field?(double, double)).to be true
    end

    it "is false if the document doesn't have a value for the field" do
      expect(Deprecation).to receive(:warn)
      allow(helper).to receive_messages(document_has_value?: false)
      expect(helper.should_render_index_field?(double, double)).to be false
    end

    it "is false if the configuration has the field disabled" do
      expect(Deprecation).to receive(:warn)
      allow(helper).to receive_messages(should_render_field?: false)
      expect(helper.should_render_index_field?(double, double)).to be false
    end
  end

  describe "#should_render_show_field?" do
    before do
      allow(helper).to receive_messages(should_render_field?: true, document_has_value?: true)
    end

    it "is true" do
      expect(Deprecation).to receive(:warn)
      expect(helper.should_render_show_field?(double, double)).to be true
    end

    it "is false if the document doesn't have a value for the field" do
      expect(Deprecation).to receive(:warn)
      allow(helper).to receive_messages(document_has_value?: false)
      expect(helper.should_render_show_field?(double, double)).to be false
    end

    it "is false if the configuration has the field disabled" do
      expect(Deprecation).to receive(:warn)
      allow(helper).to receive_messages(should_render_field?: false)
      expect(helper.should_render_show_field?(double, double)).to be false
    end
  end

  describe "#document_has_value?" do
    let(:doc) { double(SolrDocument) }

    before { allow(Deprecation).to receive(:warn) }

    it "ifs the document has the field value" do
      allow(doc).to receive(:has?).with('asdf').and_return(true)
      field_config = double(field: 'asdf')
      expect(helper.document_has_value?(doc, field_config)).to eq true
    end

    it "ifs the document has a highlight field value" do
      allow(doc).to receive(:has?).with('asdf').and_return(false)
      allow(doc).to receive(:has_highlight_field?).with('asdf').and_return(true)
      field_config = double(field: 'asdf', highlight: true)
      expect(helper.document_has_value?(doc, field_config)).to eq true
    end

    it "ifs the field has a model accessor" do
      allow(doc).to receive(:has?).with('asdf').and_return(false)
      allow(doc).to receive(:has_highlight_field?).with('asdf').and_return(false)
      field_config = double(field: 'asdf', highlight: true, accessor: true)
      expect(helper.document_has_value?(doc, field_config)).to eq true
    end
  end

  describe '#render_index_field_label' do
    around { |test| Deprecation.silence(Blacklight::BlacklightHelperBehavior) { test.call } }

    let(:doc) { SolrDocument.new({}) }

    before do
      allow(helper).to receive_messages(document_index_view_type: :current_view)
    end

    it 'accepts an explicit field label' do
      expect(helper.render_index_field_label(doc, field: 'xyz', label: 'some label')).to eq 'some label:'
    end

    it 'calculates the appropriate field label for a field' do
      allow(helper).to receive(:blacklight_config).and_return(CatalogController.blacklight_config)
      expect(helper.render_index_field_label(doc, field: 'xyz')).to eq 'Xyz:'
    end
  end

  describe "render_grouped_response?" do
    it "checks if the response ivar contains grouped data" do
      assign(:response, instance_double(Blacklight::Solr::Response, grouped?: true))
      expect(helper.render_grouped_response?).to be true
    end

    it "checks if the response param contains grouped data" do
      response = instance_double(Blacklight::Solr::Response, grouped?: true)
      expect(helper.render_grouped_response?(response)).to be true
    end
  end

  describe "render_grouped_document_index" do
    pending 'not implemented'
  end

  describe "#opensearch_description_tag" do
    subject { helper.opensearch_description_tag 'title', 'href' }

    it "has a search rel" do
      expect(subject).to have_selector "link[rel='search']", visible: false
    end

    it "has the correct mime type" do
      expect(subject).to have_selector "link[type='application/opensearchdescription+xml']", visible: false
    end

    it "has a title attribute" do
      expect(subject).to have_selector "link[title='title']", visible: false
    end

    it "has an href attribute" do
      expect(subject).to have_selector "link[href='href']", visible: false
    end
  end

  describe "#render_document_index" do
    it "renders the document index with the current view type" do
      allow(helper).to receive_messages(document_index_view_type: :current_view)
      allow(helper).to receive(:render_document_index_with_view).with(:current_view, [], a: 1, b: 2)
      helper.render_document_index [], a: 1, b: 2
    end
  end

  describe "#render_document_index_with_view" do
    let(:obj1) { SolrDocument.new }
    let(:blacklight_config) { CatalogController.blacklight_config.deep_copy }

    before do
      allow(helper).to receive(:blacklight_config).and_return(blacklight_config)
      assign(:response, instance_double(Blacklight::Solr::Response, grouped?: false, start: 0))
      allow(helper).to receive(:link_to_document).and_return('<a/>')
      allow(helper).to receive(:render_index_doc_actions).and_return('<div/>')
    end

    it "ignores missing templates" do
      blacklight_config.view.view_type(partials: %w[index_header a b])

      response = helper.render_document_index_with_view :view_type, [obj1, obj1]
      expect(response).to have_selector "div#documents"
    end

    context 'with a template partial provided by the view config' do
      before do
        blacklight_config.view.gallery(template: '/my/partial')
      end

      def stub_template(hash)
        view.view_paths.unshift(ActionView::FixtureResolver.new(hash))
      end

      it 'renders that template' do
        stub_template 'my/_partial.html.erb' => 'some content'

        response = helper.render_document_index_with_view :gallery, [obj1, obj1]

        expect(response).to eq 'some content'
      end
    end
  end

  describe "#document_index_view_type" do
    it "defaults to the default view" do
      allow(helper).to receive(:document_index_views).and_return(a: 1, b: 2)
      allow(helper).to receive(:default_document_index_view_type).and_return(:xyz)
      expect(helper.document_index_view_type).to eq :xyz
    end

    it "uses the query parameter" do
      allow(helper).to receive(:document_index_views).and_return(a: 1, b: 2)
      expect(helper.document_index_view_type(view: :a)).to eq :a
    end

    it "uses the default view if the requested view is not available" do
      allow(helper).to receive(:default_document_index_view_type).and_return(:xyz)
      allow(helper).to receive(:document_index_views).and_return(a: 1, b: 2)
      expect(helper.document_index_view_type(view: :c)).to eq :xyz
    end

    context "when they have a preferred view" do
      before do
        session[:preferred_view] = :b
      end

      context "and no view is specified" do
        it "uses the saved preference" do
          allow(helper).to receive(:document_index_views).and_return(a: 1, b: 2, c: 3)
          expect(helper.document_index_view_type).to eq :b
        end

        it "uses the default view if the preference is not available" do
          allow(helper).to receive(:document_index_views).and_return(a: 1)
          expect(helper.document_index_view_type).to eq :a
        end
      end

      context "and a view is specified" do
        it "uses the query parameter" do
          allow(helper).to receive(:document_index_views).and_return(a: 1, b: 2, c: 3)
          expect(helper.document_index_view_type(view: :c)).to eq :c
        end
      end
    end
  end

  context "related classes" do
    let(:presenter_class) { double }
    let(:blacklight_config) { Blacklight::Configuration.new }

    around { |test| Deprecation.silence(Blacklight::BlacklightHelperBehavior) { test.call } }

    before do
      allow(helper).to receive(:blacklight_config).and_return(blacklight_config)
    end

    describe "#index_presenter_class" do
      it "uses the value defined in the blacklight configuration" do
        blacklight_config.index.document_presenter_class = presenter_class
        expect(helper.index_presenter_class(nil)).to eq presenter_class
      end

      it "defaults to Blacklight::IndexPresenter" do
        expect(helper.index_presenter_class(nil)).to eq Blacklight::IndexPresenter
      end
    end

    describe "#show_presenter_class" do
      it "uses the value defined in the blacklight configuration" do
        blacklight_config.show.document_presenter_class = presenter_class
        expect(helper.show_presenter_class(nil)).to eq presenter_class
      end

      it "defaults to Blacklight::DocumentPresenter" do
        expect(helper.show_presenter_class(nil)).to eq Blacklight::ShowPresenter
      end
    end
  end

  describe "#render_document_heading" do
    around { |test| Deprecation.silence(Blacklight::BlacklightHelperBehavior) { test.call } }

    let(:document) { double }

    before do
      allow(helper).to receive(:presenter).and_return(double(heading: "Heading"))
    end

    it "accepts no arguments and render the document heading" do
      expect(helper.render_document_heading).to have_selector "h4", text: "Heading"
    end

    it "accepts the tag name as an option" do
      expect(helper.render_document_heading(tag: "h1")).to have_selector "h1", text: "Heading"
    end

    it "accepts an explicit document argument" do
      allow(helper).to receive(:presenter).with(document).and_return(double(heading: "Document Heading"))
      expect(helper.render_document_heading(document)).to have_selector "h4", text: "Document Heading"
    end

    it "accepts the document with a tag option" do
      allow(helper).to receive(:presenter).with(document).and_return(double(heading: "Document Heading"))
      expect(helper.render_document_heading(document, tag: "h3")).to have_selector "h3", text: "Document Heading"
    end
  end

  describe "#presenter" do
    around { |test| Deprecation.silence(Blacklight::BlacklightHelperBehavior) { test.call } }

    let(:document) { double }

    before do
      allow(helper).to receive(:index_presenter).and_return(:index_presenter)
      allow(helper).to receive(:show_presenter).and_return(:show_presenter)
      allow(helper).to receive(:action_name).and_return(action_name)
    end

    context "action is show" do
      let(:action_name) { "show" }

      it "uses the show presenter" do
        expect(helper.presenter(document)).to eq(:show_presenter)
      end
    end

    context "action is citation" do
      let(:action_name) { "citation" }

      it "uses the show presenter" do
        expect(helper.presenter(document)).to eq(:show_presenter)
      end
    end

    context "action is index" do
      let(:action_name) { "index" }

      it "uses the index presenter" do
        expect(helper.presenter(document)).to eq(:index_presenter)
      end
    end

    context "action is foo" do
      let(:action_name) { "foo" }

      it "uses the index presenter (by default)" do
        expect(helper.presenter(document)).to eq(:index_presenter)
      end
    end
  end
end
