# app/controllers/saved_searches_controller.rb
#
# frozen_string_literal: true
# warn_indent:           true

__loading_begin(__FILE__)

require 'blacklight/lens'

# Replaces the Blacklight class of the same name.
#
class SavedSearchesController < ApplicationController
  include Blacklight::SavedSearchesExt
end

__loading_end(__FILE__)
