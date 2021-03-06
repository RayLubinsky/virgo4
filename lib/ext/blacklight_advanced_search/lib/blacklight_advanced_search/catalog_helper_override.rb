# lib/ext/blacklight_advanced_search/lib/blacklight_advanced_search/catalog_helper_override.rb
#
# Inject BlacklightAdvancedSearch::CatalogHelperOverride extensions and
# replacement methods.

__loading_begin(__FILE__)

require 'blacklight_advanced_search/catalog_helper_override'

# Override BlacklightAdvancedSearch definitions.
#
# @see BlacklightAdvancedSearch::CatalogHelperOverride
#
module BlacklightAdvancedSearch::CatalogHelperOverrideExt

  # Special display for facet limits that include advanced search inclusive-or
  # limits.
  #
  # @param [Blacklight::Lens::Response::Facets::FacetField, Symbol] field
  # @param [String]         value
  # @param [Hash, nil]      my_params   Default: `params`.
  #
  # @return [String]
  #
  # This method overrides:
  # @see BlacklightAdvancedSearch::CatalogHelperOverride#remove_advanced_facet_param
  #
  def remove_advanced_facet_param(field, value, my_params = nil)
    field = field.name if field.respond_to?(:name)
    field = field.to_sym
    my_params ||= params
    result = controller.search_state_class.new(my_params, blacklight_config)
    result = result.to_hash.deep_symbolize_keys
    if result.dig(:f_inclusive, field)&.include?(value)
      result[:f_inclusive] = result[:f_inclusive].dup
      result[:f_inclusive][field] = result[:f_inclusive][field].dup
      result[:f_inclusive][field].delete(value)
      result[:f_inclusive].delete(field) if result[:f_inclusive][field].empty?
      result.delete(:f_inclusive) if result[:f_inclusive].empty?
    end
    result.except(:id, :counter, :page, :commit)
  end

end

# =============================================================================
# Override gem definitions
# =============================================================================

override BlacklightAdvancedSearch::CatalogHelperOverride =>
         BlacklightAdvancedSearch::CatalogHelperOverrideExt

__loading_end(__FILE__)
