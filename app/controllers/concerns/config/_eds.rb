# app/controllers/concerns/config/_eds.rb
#
# frozen_string_literal: true
# warn_indent:           true

__loading_begin(__FILE__)

require_relative '_base'
require 'blacklight/eds'
require 'blacklight/eds/repository'

# The baseline configuration for lenses that access items from EBSCO EDS.
#
# A baseline configuration for a repository contains all possible fields that
# will be needed from the repository.  Individual lens configurations tailor
# information displayed to the user by selecting removing fields from their
# copy of this configuration.
#
class Config::Eds < Config::Base

  # === Common field values ===
  #
  # Certain "index" and "show" configuration fields have the same values based
  # on the relevant fields defined by the search service.
  #
  # @see self#semantic_fields!
  #
  # NOTE: Use of these field associations is inconsistent in Blacklight and
  # related gems (and in this application).  Some places expect only a single
  # metadata field name to be associated with the semantic field; others expect
  # (or tolerate) multiple metadata field names (to allow fallback fields to be
  # accessed if the main metadata field is missing or empty).
  #
  SEMANTIC_FIELDS = {
    display_type_field: 'eds_publication_type', # TODO: Could remove to avoid partial lookups by display type if "_default" is the only appropriate partial.
    title_field:        'eds_title',
    subtitle_field:     'eds_other_titles', # TODO: ???
    alt_title_field:    nil, # TODO: ???
    author_field:       'eds_authors',
    alt_author_field:   nil, # TODO: ???
    thumbnail_field:    %w(eds_cover_medium_url eds_cover_thumb_url)
  }

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  module ClassMethods

    include Config::Base::ClassMethods

    # Modify a configuration to support searches to EBSCO EDS.
    #
    # @param [Blacklight::Configuration]     config
    # @param [Blacklight::Controller, Class] controller
    #
    # @return [Blacklight::Configuration]   The modified configuration.
    #
    # @see Config::Eds#response_models!
    # @see Config::Base#add_tools!
    # @see Config::Base#finalize_configuration!
    #
    def configure!(config, controller)
      # rubocop:disable Metrics/LineLength

      # Common configuration values.
      super(config, controller)

      # =======================================================================
      # Lens
      # =======================================================================

      # Default Blacklight Lens for controllers based on this configuration.
      config.lens_key = :articles

      response_models!(config)

      # =======================================================================
      # Facets
      # =======================================================================

      # Solr fields that will be treated as facets by the application.
      # (The ordering of the field names is the order of display.)
      #
      # @see Blacklight::Configuration::Files::ClassMethods#define_field_access

      config.add_facet_field 'eds_search_limiters_facet'
      config.add_facet_field 'eds_publication_type_facet'
      config.add_facet_field 'eds_publication_year_facet' #, single: true
      config.add_facet_field 'eds_publication_year_range_facet', single: true # TODO: testing
      config.add_facet_field 'eds_category_facet'
      config.add_facet_field 'eds_subject_topic_facet'
      config.add_facet_field 'eds_language_facet'
      config.add_facet_field 'eds_journal_facet'
      config.add_facet_field 'eds_subjects_geographic_facet'
      config.add_facet_field 'eds_publisher_facet'
      config.add_facet_field 'eds_content_provider_facet'
      # JSON-only facets
      config.add_facet_field 'eds_library_location_facet',   if: :json_request?
      config.add_facet_field 'eds_library_collection_facet', if: :json_request?
      config.add_facet_field 'eds_author_university_facet',  if: :json_request?
      config.add_facet_field 'pub_year_tisim',               if: :json_request?

      # === Experimental facets
      now = Time.zone.now.year
      config.add_facet_field 'example_query_facet_field', query: {
        years_5:  { label: 'within 5 Years',  fq: "pub_date:[#{now-5}  TO *]" },
        years_10: { label: 'within 10 Years', fq: "pub_date:[#{now-10} TO *]" },
        years_25: { label: 'within 25 Years', fq: "pub_date:[#{now-25} TO *]" }
      }, label: 'Publication Range'

      # Set labels from locale for this lens and supply options that apply to
      # multiple field configurations.
      config.facet_fields.each_pair do |key, field|
        if key == 'eds_search_limiters_facet'
          field.limit       = -1
          field.sort        = 'index'
          field.index_range = 'A'..'Z'
        else
          field.limit       = 20
          field.sort        = 'count'
          field.index_range = "\x20".."\x7E"
        end
      end

      # =======================================================================
      # Index pages (search results)
      # =======================================================================

      # === Index metadata fields ===
      # Solr fields to be displayed in the index (search results) view.
      # (The ordering of the field names is the order of the display.)
      #
      # @see Blacklight::Configuration::Files::ClassMethods#define_field_access
      #
      # ==== Implementation Notes
      # [1] Blacklight::Lens::IndexPresenter#label shows title and format so
      #     they should not be included here for HTML -- only for JSON.
      #
      # [2] 'Published in' ('eds_composed_title'), if present, eliminates the
      #     need for separate 'eds_source_title', 'eds_publication_info', and
      #     'eds_publication_date' entries.

      config.add_index_field 'eds_title',                   if: :json_request?
      config.add_index_field 'eds_publication_type',        helper_method: :eds_publication_type_label
      config.add_index_field 'eds_authors'
      config.add_index_field 'eds_composed_title',          helper_method: :eds_index_publication_info
      config.add_index_field 'eds_languages'
      config.add_index_field 'eds_html_fulltext_available', helper_method: :eds_html_fulltext_link, if: :value_present?
      config.add_index_field 'eds_relevancy_score'
      config.add_index_field 'eds_result_id',               if: :json_request?

      # =======================================================================
      # Show pages (item details)
      # =======================================================================

      # === Show page (item details) metadata fields ===
      # Solr fields to be displayed in the show (single result) view.
      # (The ordering of the field names is the order of display.)
      #
      # @see Blacklight::Configuration::Files::ClassMethods#define_field_access
      #
      # ==== Implementation Notes
      # [1] Blacklight::Lens::ShowPresenter#heading shows title and author so
      #     they should not be included here for HTML -- only for JSON.
      #
      # [2] 'Published in' ('eds_composed_title'), if present, eliminates the
      #     need for separate 'eds_source_title', 'eds_publication_info', and
      #     'eds_publication_date' entries.

      config.add_show_field 'eds_title',                    if: :json_request?
      config.add_show_field 'eds_publication_type',         helper_method: :eds_publication_type_label
      config.add_show_field 'eds_authors',                  if: :json_request?
      config.add_show_field 'eds_document_type'             # TODO: Cope with extraneous text (e.g. "Artikel<br>PeerReviewed")
      config.add_show_field 'eds_publication_status'
      config.add_show_field 'eds_other_titles'
      config.add_show_field 'eds_composed_title'
      config.add_show_field 'eds_languages'
      config.add_show_field 'eds_source_title'
      config.add_show_field 'eds_series'
      config.add_show_field 'eds_publication_year'
      config.add_show_field 'eds_volume'
      config.add_show_field 'eds_issue'
      config.add_show_field 'eds_page_start'
      config.add_show_field 'eds_page_count',               unless: :zero_value?
      config.add_show_field 'eds_fulltext_word_count',      unless: :zero_value?
      config.add_show_field 'eds_physical_description'
      config.add_show_field 'eds_notes'
      config.add_show_field 'eds_publication_info'
      config.add_show_field 'eds_publisher'
      config.add_show_field 'eds_publication_date'
      config.add_show_field 'eds_document_doi',             helper_method: :doi_link
      config.add_show_field 'eds_document_oclc'
      config.add_show_field 'eds_issns'
      config.add_show_field 'eds_issn_print'
      config.add_show_field 'eds_isbns'
      config.add_show_field 'eds_isbn_print'
      config.add_show_field 'eds_isbn_electronic'
      config.add_show_field 'eds_isbns_related'
      config.add_show_field 'eds_subjects'
      config.add_show_field 'eds_subjects_geographic'
      config.add_show_field 'eds_subjects_person'
      config.add_show_field 'eds_subjects_company'
      config.add_show_field 'eds_subjects_bisac'
      config.add_show_field 'eds_subjects_mesh'
      config.add_show_field 'eds_subjects_genre'
      config.add_show_field 'eds_code_naics'
      config.add_show_field 'eds_author_supplied_keywords'
      config.add_show_field 'eds_abstract',                 helper_method: :eds_abstract
      config.add_show_field 'eds_publication_type_id'
      config.add_show_field 'eds_access_level'
      config.add_show_field 'eds_authors_composed'
      config.add_show_field 'eds_author_affiliations'
      config.add_show_field 'eds_subset'
      config.add_show_field 'eds_covers'
      config.add_show_field 'eds_cover_thumb_url',          helper_method: :url_link
      config.add_show_field 'eds_cover_medium_url',         helper_method: :url_link
      config.add_show_field 'eds_images'
      config.add_show_field 'eds_quick_view_images'
      config.add_show_field 'eds_abstract_supplied_copyright'
      config.add_show_field 'eds_descriptors'
      config.add_show_field 'eds_publication_id'
      config.add_show_field 'eds_publication_is_searchable'
      config.add_show_field 'eds_publication_scope_note'
      config.add_show_field 'eds_database_id'
      config.add_show_field 'eds_accession_number'
      config.add_show_field 'eds_database_name'
      config.add_show_field 'eds_relevancy_score'
      config.add_show_field 'eds_result_id',                if: :json_request?
      # == Other
      config.add_show_field 'all_subjects_search_links',    if: :json_request?
      config.add_show_field 'bib_identifiers',              if: :json_request?
      config.add_show_field 'bib_pub_date',                 if: :json_request?
      config.add_show_field 'decode_sanitize_html',         if: :json_request?
      config.add_show_field 'eds_extras_Format',            if: :json_request?
      config.add_show_field 'eds_extras_NoteTitleSource',   if: :json_request?
      config.add_show_field 'eds_extras_TitleTranslated',   if: :json_request?
      # == Citations
      config.add_show_field 'eds_citation_exports',         if: :json_request?
      config.add_show_field 'eds_citation_styles',          if: :json_request?
      # == Availability (links and inline full text)
      config.add_show_field 'eds_pdf_fulltext_available'
      config.add_show_field 'eds_ebook_pdf_fulltext_available'
      config.add_show_field 'eds_ebook_epub_fulltext_available'
      config.add_show_field 'eds_html_fulltext_available',  if: :json_request?
      config.add_show_field 'eds_all_links',                helper_method: :eds_all_links
      config.add_show_field 'eds_plink',                    helper_method: :eds_plink
      config.add_show_field 'eds_fulltext_link',            if: :json_request?
      config.add_show_field 'eds_fulltext_links',           if: :json_request?
      config.add_show_field 'eds_non_fulltext_links',       if: :json_request?
      config.add_show_field 'eds_html_fulltext',            helper_method: :eds_html_fulltext

      # =======================================================================
      # Search fields
      # =======================================================================

      # "Fielded" search configuration. Used by pulldown among other places.
      # For supported keys in hash, see rdoc for Blacklight::SearchFields.
      #
      # @see Blacklight::Configuration::Files::ClassMethods#define_field_access
      # @see EBSCO::EDS#SOLR_SEARCH_TO_EBSCO_FIELD_CODE
      # @see EBSCO::EDS#OTHER_SOLR_SEARCH_TO_EBSCO_FIELD_CODE
      #
      # ==== Implementation Notes
      # "All Fields" is intentionally placed last.
      #
      # NOTE: Lack of a search field is not identical to 'all_fields'
      #
      # For EBSCO, a search without specifying a field code searches in:
      # - author
      # - subject
      # - keywords (most documents in EBSCO databases do not have keywords)
      # - title
      # - source title (i.e., journal title)
      # - abstract
      # BUT NOT in full text, whereas a 'TX' search will search in all fields
      # including full text.
      #
      # For now this is not presented as a search option.

      config.add_search_field 'title'                           # 'TI'
      config.add_search_field 'author'                          # 'AU'
      config.add_search_field 'subject'                         # 'SU'
      config.add_search_field 'abstract'                        # 'AB'
      config.add_search_field 'source'                          # 'SO'
      config.add_search_field 'issn',       autocomplete: false # 'IS'
      config.add_search_field 'isbn',       autocomplete: false # 'IB'
      # config.add_search_field 'basic',    autocomplete: ''
      config.add_search_field 'all_fields', default:      true  # 'TX'

      # Lookup search field labels and initialize :autocomplete.
      config.search_fields.each_pair do |key, field|
        field.autocomplete = key if field.autocomplete.nil?
      end

      # =======================================================================
      # Sort fields
      # =======================================================================

      # "Sort results by" select (pulldown)
      # @see Blacklight::Configuration::Files::ClassMethods#define_field_access

      config.add_sort_field 'relevance', sort: 'relevance'
      config.add_sort_field 'newest',    sort: 'newest'
      config.add_sort_field 'oldest',    sort: 'oldest'

      # =======================================================================
      # Search parameters
      # =======================================================================

      # Force spell checking in all cases, no max results required.
      config.spell_max = 9999999999

      search_builder_processors!(config)
      autocomplete_suggesters!(config)

      # =======================================================================
      # Blacklight Advanced Search
      # =======================================================================

=begin # TODO: ???
      config.advanced_search.form_solr_parameters[:'facet.field'] = %w(
        eds_search_limiters_facet
        eds_publication_type_facet
        eds_publication_year_facet
        eds_category_facet
        eds_subject_topic_facet
        eds_language_facet
        eds_journal_facet
        eds_subjects_geographic_facet
        eds_publisher_facet
        eds_content_provider_facet
      )
=end

      # =======================================================================
      # Finalize and return the modified configuration
      # =======================================================================

      add_tools!(config)
      semantic_fields!(config)
      blacklight_gallery!(config)
      finalize_configuration!(config)

      # rubocop:enable Metrics/LineLength
    end

    # Define per-repository response model values and copy them to the top level
    # of the configuration where Blacklight expects to see them.
    #
    # @param [Blacklight::Configuration]                       config
    # @param [Hash, Blacklight::OpenStructWithHashAccess, nil] added_values
    #
    # @return [void]
    #
    # @see Config::Base#response_models!
    #
    def response_models!(config, added_values = nil)
      values =
        Blacklight::OpenStructWithHashAccess.new(
          document_model:        EdsDocument,
          document_factory:      Blacklight::Eds::DocumentFactory,
          response_model:        Blacklight::Eds::Response,
          repository_class:      Blacklight::Eds::Repository,
          search_builder_class:  SearchBuilderEds,
          field_retriever_class: Blacklight::Eds::FieldRetriever,
        )
      values = values.merge(added_values) if added_values.present?
      super(config, values)
    end

    # Settings for autocomplete suggesters.
    #
    # @param [Blacklight::Configuration] config
    #
    # @return [void]
    #
    # This method overrides:
    # @see Config::Base::ClassMethods#autocomplete_suggesters!
    #
    def autocomplete_suggesters!(config)
      config.autocomplete_path      = 'suggest'
      config.autocomplete_suggester = 'suggest' # TODO: TBD?
      super(config)
    end

    # Set mappings of configuration key to repository field for both :index and
    # :show configurations.
    #
    # @param [Blacklight::Configuration]                       config
    # @param [Hash, Blacklight::OpenStructWithHashAccess, nil] added_values
    #
    # @see Config::Base#semantic_fields!
    #
    def semantic_fields!(config, added_values = nil)
      values = SEMANTIC_FIELDS
      values = values.merge(added_values) if added_values.present?
      super(config, values)
    end

  end
  include ClassMethods
  extend  ClassMethods

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Initialize a new configuration as the basis for lenses that access items
  # from EBSCO EDS.
  #
  # @param [Blacklight::Lens::Controller] controller
  #
  def initialize(controller)
    @blacklight_config = build_configuration(controller)
    super(@blacklight_config)
  end

end

__loading_end(__FILE__)
