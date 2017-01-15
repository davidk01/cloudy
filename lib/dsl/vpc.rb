module Dsl

  ##
  # According to cloud formation docs here are the properties and syntax for declaring
  # a VPC
  #
  # {
  #    "Type" : "AWS::EC2::VPC",
  #    "Properties" : {
  #       "CidrBlock" : String,
  #       "EnableDnsSupport" : Boolean,
  #       "EnableDnsHostnames" : Boolean,
  #       "InstanceTenancy" : String, {default|dedicated}
  #       "Tags" : [ Resource Tag, ... ]
  #    }
  # }
  
  class Vpc < Common::Resource

    module Tenancy
      Default = :default
      Dedicated = :dedicated
    end

    define_keyword(
      :tenancy,
      validation: ->(t) { Tenancy.constants(false).map(&:downcase).include?(t) },
      required: false, default: Tenancy::Default
    )

    define_keyword(
      :cidr_block, transformer: ->(block) { Common::CidrBlock.new(block) },
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :dns_support, validation: Utils.method(:boolean?),
      properties: [Common::KeywordProperties::Immutable]
    )

    define_keyword(
      :dns_hostnames, validation: Utils.method(:boolean?),
      properties: [Common::KeywordProperties::Immutable]
    )

  end

end
