module Dsl

  ##
  # The subnet component of the DSL.
  # {
  #   "Type" : "AWS::EC2::Subnet",
  #   "Properties" : {
  #     "AvailabilityZone" : String,
  #     "CidrBlock" : String,
  #     "MapPublicIpOnLaunch" : Boolean,
  #     "Tags" : [ Resource Tag, ... ],
  #     "VpcId" : String
  #   }
  # }
  
  class Subnet < Common::Resource

    ##
    # Need to know what is the CIDR block that defines this subnet.
    
    define_keyword(
      :cidr_block, 
      validation: Utils.method(:string?), 
      transformer: ->(block) { Common::CidrBlock.new(block) },
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # The availability zone associated with this subnet.
    
    define_keyword(
      :availability_zone, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # Do VMs automatically get public IPs assigned when launched in this subnet.
    
    define_keyword(
      :public_ip, validation: Utils.method(:boolean?),
      required: false, default: false,
      properties: [Common::KeywordProperties::Mutable]
    )

    ##
    # VPC this subnet belongs to.
    
    define_keyword(
      :vpc, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # Route table associated with this subnet.
    
    define_keyword(
      :route_table, validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Mutable]
    )

  end

end
