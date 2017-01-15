module Dsl

  ##
  # According to cloud formation docs these are the properties for a route table. We will
  # add routes within the same context since a route table without routes is kinda useless
  #
  # {
  #    "Type" : "AWS::EC2::RouteTable",
  #    "Properties" : {
  #       "VpcId" : String,
  #       "Tags" : [ Resource Tag, ... ]
  #    }
  # } 

  class RouteTable < Common::Resource

    ##
    # As defined in AWS docs
    #
    # {
    #   "Type" : "AWS::EC2::Route",
    #   "Properties" : {
    #     "DestinationCidrBlock" : String,
    #     "DestinationIpv6CidrBlock" : String,
    #     "GatewayId" : String,
    #     "InstanceId" : String,
    #     "NatGatewayId" : String,
    #     "NetworkInterfaceId" : String,
    #     "RouteTableId" : String,
    #     "VpcPeeringConnectionId" : String
    #   }
    # }
    
    ##
    # All properties for a route definition are immutable. Basically means if anything
    # for a route changes we delete the route and create a new one in its place. Simplifies
    # the diffing logic because we just delete entries that don't match and create new ones.
    
    class Route < Common::Resource

      ##
      # Doesn't really make sense to tag routes on their own.
      
      ignore_tags!

      ##
      # Here we make sure everything is properly defined and that we only have 1 destination.
      
      def validate!
        super
        unless [
          defined?(@gateway), defined?(@instance), 
          defined?(@nat), defined?(@network_interface)
        ].reject(&:nil?).length == 1
          error = [
            "Exactly one destination must be set:",
            "gateway|instance|nat|network interface."
          ].join(' ')
          raise StandardError, error
        end
        self
      end

      define_keyword(
        :cidr_block, 
        validation: Utils.method(:string?), 
        transformer: ->(block) { Common::CidrBlock.new(block) },
        properties: [Common::KeywordProperties::Immutable]
      )

      define_keyword(
        :gateway, 
        validation: Utils.method(:string_or_ref?),
        required: false,
        properties: [Common::KeywordProperties::Immutable]
      )

      define_keyword(
        :instance, 
        validation: Utils.method(:string_or_ref?),
        required: false,
        properties: [Common::KeywordProperties::Immutable]
      )

      define_keyword(
        :nat, 
        validation: Utils.method(:string_or_ref?),
        required: false,
        properties: [Common::KeywordProperties::Immutable]
      )

      define_keyword(
        :network_interface, 
        validation: Utils.method(:string_or_ref?),
        required: false,
        properties: [Common::KeywordProperties::Immutable]
      )

    end

    ##
    # Route tables must be associated with VPCs.
    
    define_keyword(
      :vpc, 
      validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # A route table is kinda meaningless without routes.

    define_collection_keyword(
      :route, 
      storage: ->(_) { @routes ||= {} }, 
      context: Route,
      properties: [Common::KeywordProperties::Mutable]
    )

  end

end
