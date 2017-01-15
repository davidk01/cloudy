module Dsl

  ##
  # The security group component of the DSL.
  
  class SecurityGroup < Common::Resource

    ##
    # Ingress and egress rules both share some common methods so those are in this
    # module.
    
    module SecurityGroupCommon
      
      ##
      # Supported protocols for ingress and egress rules.
      
      module Protocol
        Tcp = :tcp
        All = :all
      end

      Protocols = Protocol.constants(false).map(&:downcase)

      ##
      # Minimum and maximum allowed port numbers.
      
      MinPort, MaxPort = 0, 2 ** 16

      ##
      # Create a CIDR block component.
      
      def cidr_block(cidr_block)
        Common::CidrBlock.new(cidr_block)
      end

      ##
      # Validation that we can't perform at creation time.

      def validate!
        super
        unless @cidr_blocks || @security_groups
          error = [
            "Either security groups or CIDR blocks must be defined for #{self.class}."
          ].join(' ')
          raise StandardError, error
        end
        self
      end

    end

    ##
    # To create security groups we need a vpc ID.
    
    define_keyword(
      :vpc,
      validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

    ##
    # We need a description for the security group.
    
    define_keyword(
      :description,
      validation: Utils.method(:string?)
    )

    ##
    # Unpacking this bit of meta-programming should be simple. It just gives us the common
    # definitions of ingress and egress rule classes.
    
    [:ingress, :egress].each do |rule_type|
      klass_name = rule_type.to_s.capitalize + 'Rule'
      const_set(klass_name, Class.new(Common::Resource) do
        include SecurityGroupCommon

        ##
        # We don't need tags for ingress/egress rules.
        
        ignore_tags!

        ##
        # A sequence of CIDR blocks.

        define_keyword(
          :cidr_blocks,
          validation: ->(blocks) { blocks.all? {|b| Common::CidrBlock === b} && blocks.length > 0 },
          required: false,
          properties: [Common::KeywordProperties::Mutable]
        )

        ##
        # The protocol for this rule.

        define_keyword(
          :protocol,
          validation: ->(proto) { SecurityGroupCommon::Protocols.include?(proto) },
          required: false, default: SecurityGroupCommon::Protocol::All,
          properties: [Common::KeywordProperties::Mutable]
        )

        ##
        # Starting port for this ingress rule.

        define_keyword(
          :from,
          validation: ->(port) { Utils.int?(port) && port >= SecurityGroupCommon::MinPort },
          required: false, default: SecurityGroupCommon::MinPort,
          properties: [Common::KeywordProperties::Mutable]
        )

        ##
        # Ending port for ingress rule.

        define_keyword(
          :to,
          validation: ->(to) { Utils.int?(to) && to <= SecurityGroupCommon::MaxPort },
          required: false, default: SecurityGroupCommon::MaxPort,
          properties: [Common::KeywordProperties::Mutable]
        )

        ##
        # Ingress and egress rules can reference other security groups instead of
        # just defining CIDR blocks.

        define_keyword(
          :security_groups,
          validation: ->(sgs) { sgs.all?(&Utils.method(:string_or_ref?)) },
          required: false,
          properties: [Common::KeywordProperties::Mutable]
        )

      end)
    end

    ##
    # Same pattern as in other keywords. Instantiate a context and evaluate a block
    # in that context.
    
    define_collection_keyword(
      :ingress,
      storage: ->(_) { @ingress_rules ||= {} },
      context: IngressRule,
      properties: [Common::KeywordProperties::Mutable]
    )

    ##
    # Same as above but for egress rules.
    
    define_collection_keyword(
      :egress,
      storage: ->(_) { @egress_rules ||= {} },
      context: EgressRule,
      properties: [Common::KeywordProperties::Mutable]
    )

  end

end
