module Dsl

  ##
  # {
  #    "Type" : "AWS::EC2::NetworkInterface",
  #    "Properties" : {
  #       "Description" : String,
  #       "GroupSet" : [ String, ... ],
  #       "Ipv6AddressCount" : Integer,
  #       "Ipv6Addresses" : [ Ipv6Address, ... ],
  #       "PrivateIpAddress" : String,
  #       "PrivateIpAddresses" : [ PrivateIpAddressSpecification, ... ],
  #       "SecondaryPrivateIpAddressCount" : Integer,
  #       "SourceDestCheck" : Boolean,
  #       "SubnetId" : String,
  #       "Tags" : [ Resource Tag, ... ]
  #    }
  # }

  class NetworkInterface < Common::Resource

    define_keyword(
      :description,
      validation: Utils.method(:string?)
    )

    define_keyword(
      :security_groups,
      validation: ->(sgs) { sgs.all? {|sg| Utils.string_or_ref?(sg)} },
      properties: [Common::KeywordProperties::Mutable]
    )

    define_keyword(
      :ipv6_addresses,
      validation: ->(addrs) { addrs.all? {|addr| Utils.string?(addr)} },
      required: false,
      default: []
    )

    define_keyword(
      :private_ip_address,
      validation: ->(addr) { Utils.cidr_block?(addr) },
      required: false
    )

    define_keyword(
      :private_ip_addresses,
      validation: ->(addrs) { addrs.all? {|addr| Utils.cidr_block?(addr)} },
      required: false
    )

    define_keyword(
      :secondary_private_ip_address_count,
      validation: Utils.method(:int?),
      required: false
    )

    define_keyword(
      :source_destination_check,
      validation: Utils.method(:boolean?),
      required: false, default: true,
      properties: [Common::KeywordProperties::Mutable]
    )

    define_keyword(
      :subnet,
      validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

  end

end
