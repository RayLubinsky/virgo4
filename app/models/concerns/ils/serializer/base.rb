# app/models/concerns/ils/serializer/base.rb
#
# frozen_string_literal: true
# warn_indent:           true

__loading_begin(__FILE__)

require 'ils/serializer/_internal'
require 'ils/serializer/associations'

# The base class for serialization/de-serialization of objects derived from
# Ils::Record::Base.
#
class Ils::Serializer::Base < Representable::Decorator

  include Ils::Schema
  include Ils::Serializer::Associations

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @type [String, Hash]
  attr_reader :source_data

  # Initialize a new instance.
  #
  # @param [Ils::Record::Base] represented
  #
  def initialize(represented)
    super
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Type of serializer (based on the name of descendent class if not set
  # explicitly).
  #
  # @return [Symbol]
  #
  # @see Ils::Schema#SERIALIZER_TYPES
  # @see Ils::Schema#DEFAULT_SERIALIZER_TYPE
  #
  def serializer_type
    @serializer_type ||=
      SERIALIZER_TYPES.find { |type|
        self.class.to_s =~ /::#{type.to_s.downcase}/i
      } || DEFAULT_SERIALIZER_TYPE
  end

  # Render data elements in serialized format.
  #
  # @param [Symbol, Proc] method
  # @param [Hash, nil]    opt         Options argument for *method*.
  #
  # @return [String]
  #
  # == Usage Notes
  # This method must be overridden by the derived class to pass in :method.
  #
  def serialize(method, **opt)
    start_time = Time.now
    case method
      when Symbol then send(method, **opt)
      when Proc   then method.call(**opt)
      else             abort "#{__method__}: subclass must supply method"
    end
  rescue => error
    $stderr.puts "!!! #{self.class} #{__method__} ERROR #{error.message}"
    raise error
  ensure
    if start_time
      elapsed_time = '%g msec.' % (Time.now - start_time).in_milliseconds
      $stderr.puts ">>> #{self.class} serialized in #{elapsed_time}"
      Rails.logger.info { "#{self.class} serialized in #{elapsed_time}" }
    end
  end

  # Load data elements from the supplied data.
  #
  # If *data* is a String, it is assumed that it is already in the form
  # required by the derived serializer class.
  #
  # @param [String, Hash] data
  # @param [Symbol, Proc] method
  #
  # @return [Hash]
  # @return [nil]
  #
  # == Usage Notes
  # The derived class must override this to pass in :method via the arguments
  # to `super`.
  #
  def deserialize(data, method = nil)
    return unless set_source_data(data)
    start_time = Time.now
    case method
      when Symbol then send(method, source_data)
      when Proc   then method.call(source_data)
      else             abort "#{__method__}: subclass must supply method"
    end
  rescue => error
    $stderr.puts "!!! #{self.class} #{__method__} ERROR #{error.message}"
    raise error
  ensure
    if start_time
      elapsed_time = '%g msec.' % (Time.now - start_time).in_milliseconds
      $stderr.puts ">>> #{self.class} parsed in #{elapsed_time}"
      Rails.logger.info { "#{self.class} parsed in #{elapsed_time}" }
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Set source data string.
  #
  # If *data* is a String, it is assumed that it is already in the form
  # required by the derived serializer class.
  #
  # @param [String, Hash] data
  #
  # @return [String]
  # @return [nil]                 If *data* is neither a String nor a Hash.
  #
  # == Usage Notes
  # This method will not be invoked (and @source_data will be *nil*) for an
  # instance where #error? is *true*.
  #
  def set_source_data(data)
    @source_data ||= (data.dup if data.is_a?(String) || data.is_a?(Hash))
  end

  # ===========================================================================
  # :section: Record field schema DSL
  # ===========================================================================

  public

  defaults do |name|
    { as: element_name(name, ELEMENT_NAMING_MODE) }
  end

end

__loading_end(__FILE__)
