# app/models/concerns/ils/record/base.rb
#
# frozen_string_literal: true
# warn_indent:           true

__loading_begin(__FILE__)

require 'ils/record'
require 'ils/common'

# The base class for objects that interact with the ILS Connector API, either
# to be initialized through de-serialized data received from the API or to be
# serialized into data to be sent to the API.
#
class Ils::Record::Base

  include Ils::Common
  include Ils::Schema
  include Ils::Record::Associations
  include Ils::Record::Schema

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # @return [Symbol]
  attr_reader :serializer_type

  # @return [Exception, nil]
  attr_reader :exception

  # Initialize a new instance.
  #
  # @param [Hash, String, nil] data
  # @param [Hash, nil]         opt
  #
  # @option options [Symbol] :format    One of Ils::Schema#SERIALIZER_TYPES.
  #
  def initialize(data = nil, **opt)
    @exception =
      case opt[:error]
        when Exception then opt[:error]
        when String    then Exception.new(opt[:error])
      end
    if @exception
      @serializer_type = :hash
      initialize_attributes
    else
      @serializer_type = opt[:format] || DEFAULT_SERIALIZER_TYPE
      assert_serializer_type(@serializer_type)
      deserialize(data)
    end
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # A serializer instance of the currently-selected type.
  #
  # @param [Symbol, nil] type         Default: #serializer_type
  #
  # @return [Ils::Serializer::Base]
  #
  # @see Ils::Record::Schema::ClassMethods#serializers
  #
  def serializer(type = nil)
    type ||= serializer_type
    if type == serializer_type
      @serializer ||= self.class.serializers[type].new(self)
    else
      self.class.serializers[type].new(self)
    end
  end

  # Load data elements from the supplied data.
  #
  # (If the data is a String, it must already be in the form required by the
  # serializer.)
  #
  # @param [String, Hash] data
  # @param [Symbol, nil] type         Default: #serializer_type
  #
  # @return [Ils::Record::Base]
  # @return [nil]
  #
  # @see Ils::Serializer::Base#deserialize
  #
  def deserialize(data, type = nil)
    serializer(type).deserialize(data)
  end

  # Serialize data elements to the indicated format.
  #
  # @param [Symbol, nil] type         Default: #serializer_type
  # @param [Hash, nil]   opt
  #
  # @return [String]
  #
  # @see Ils::Serializer::Base#serialize
  #
  def serialize(type = nil, **opt)
    serializer(type).serialize(**opt)
  end

  # Serialize the record instance into JSON format.
  #
  # @param [Hash, nil] opt
  #
  # @return [String]
  #
  # @see Ils::Serializer::JsonBase#serialize
  #
  def to_json(**opt)
    serialize(:json, **opt)
  end

  # Serialize the record instance into XML format.
  #
  # @param [Hash, nil] opt
  #
  # @return [String]
  #
  # @see Ils::Serializer::XmlBase#serialize
  #
  def to_xml(**opt)
    serialize(:xml, **opt)
  end

  # Serialize the record instance into a Hash.
  #
  # @param [Boolean, nil] symbolize_keys
  # @param [Hash, nil]    opt
  #
  # @return [Hash]
  #
  # @see Ils::Serializer::HashBase#serialize
  # @see Ils::Serializer::HashBase#SERIALIZE_SYMBOLIZE_KEYS
  #
  def to_hash(symbolize_keys: nil, **opt)
    opt = opt.merge(symbolize_keys: symbolize_keys) unless symbolize_keys.nil?
    serialize(:hash, **opt)
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  public

  # Returns *nil* unless this instance is an error placeholder.
  #
  # @return [String, nil]
  #
  def error_message
    exception&.message
  end

  # Indicate whether this is an instance created as part of a placeholder
  # generated due to a failure to acquire valid data from the source.
  #
  def error?
    exception.present?
  end

  # Indicate whether this is a valid data instance.
  #
  def valid?
    !error?
  end

  # Default data used to initialize an error instance.
  #
  # @return [Hash{Symbol=>BasicObject}]
  #
  # @see Ils::Record::Associations#property_defaults
  #
  def default_data
    self.class.property_defaults.deep_dup
  end

  # ===========================================================================
  # :section:
  # ===========================================================================

  protected

  # Directly assign schema attributes.
  #
  # @param [Hash, nil] data           Default: #default_data
  #
  # @return [Hash{Symbol=>BasicObject}]
  #
  # == Usage Notes
  # This is only intended for use in the initialization of an error instance.
  #
  def initialize_attributes(data = nil)
    (data || default_data).each_pair do |attr, value|
      case value
        when Class then value = value.new
        when Proc  then value = value.call(error: exception)
      end
      send(:"#{attr}=", value)
    end
  end

end

__loading_end(__FILE__)
