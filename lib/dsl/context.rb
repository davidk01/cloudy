module Dsl

  class RefChain

    attr_reader :node, :parent, :chain, :value

    def initialize(node:, parent: nil)
      @node = node
      @parent = parent
      @chain = {}
      # All ref chains start off with nil value and unresolved
      @value = nil
      @resolved = false
    end

    ##
    # Can only resolve a ref chain once.
    
    def resolve(val)
      if @resolved
        raise StandardError, "Can not resolve reference more than once."
      end
      @value, @resolved = val, true
    end

    ##
    # Does this reference have a value we can use.
    
    def resolved?
      @resolved
    end

    def to_s
      as_json.to_json
    end

    def [](sym)
      unless Utils.symbol?(sym)
        raise StandardError, "Can only chain symbols: #{sym}."
      end
      @chain[sym] ||= RefChain.new(node: sym, parent: self)
    end

    ##
    # Chase all the branches from this node and return all the leaves.
    
    def leaves
      chain.flat_map {|k, c|
        c.chain.empty? ? c : c.leaves
      }
    end

    ##
    # TODO: Not sure where this is used now.
    
    def ==(other)
      other && (self.class == other.class) &&
        (node == other.node) && 
        (parent == other.parent)
    end

    ##
    # TODO: Figure out what this means
    
    def as_json(options = nil)
      (parent ? parent.as_json(options) : []) + [node]
    end

  end

  class Context

    ##
    # This pattern is used over and over again. Initialize a context and then evaluate
    # the block in that context.
    
    def contextual_evaluation(klass, name, metadata, &blk)
      self.class.contextual_evaluation(klass, name, metadata, &blk)
    end

    ##
    # Same as above but as a class method to be used in other places.
    
    def self.contextual_evaluation(klass, name, metadata, &blk)
      unless Utils.symbol?(name)
        raise StandardError, "Resource name must be a symbol: #{name}."
      end
      parent = eval 'self', blk.send(:binding)
      ctx = klass.new(name, parent, metadata)
      ctx.instance_eval(&blk)
      ctx.fill_in_defaults
      ctx.validate!
      ctx
    end

    attr_reader :resources, :name, :parent, :refs, :metadata

    ##
    # Basic stuff. Set the name, parent context, and resource collection to initial values.
    
    def initialize(name, parent)
      unless Utils.symbol?(name)
        raise StandardError, "Name must be a symbol."
      end
      @name, @parent, @refs, @resources, @metadata = name, parent, RefChain.new(node: :''), {}, {}
    end

    ##
    # Find a resource by its name. Trying to grab a resource that does not exist should be
    # impossible so if we get +nil+ then we raise an exception.
    
    def resource(sym)
      unless Utils.symbol?(sym)
        raise StandardError, "Resource name must be a symbol: #{sym}."
      end
      if (r = resources[sym]).nil?
        raise StandardError, "Impossible situation. Non-existent resource: #{sym}."
      end
      r
    end

    def [](attr)
      unless Utils.symbol?(attr)
        raise StandardError, "Attribute lookup key must be a symbol: #{attr}."
      end
      if instance_variable_defined?(var = '@' + attr.to_s)
        instance_variable_get(var)
      else
        raise StandardError, "Undefined attribute lookup: #{self}, #{var}."
      end
    end

    ##
    # Try to set the value of a reference if the corresponding resource is sufficiently
    # "hydrated".
    
    def try_to_resolve(ref:)
      matching_containers = matching_resources(ref: ref)
      if matching_containers.length > 1
        raise StandardError, "Can not resolve ambiguous reference: #{ref}."
      end
      if matching_containers.length == 0
        raise StandardError, "Dangling reference: #{ref}."
      end
      container = matching_containers.values.first
      ref_node = ref.node
      if (container_value = container[ref_node]).nil?
        false
      else
        ref.resolve(container_value)
      end
    end

    ##
    # Find all the resources that contain the given reference. This will descend into 
    # nested resource collections to find the most specific resource possible.
    
    def matching_resources(ref:)
      reference_chain = Utils.reference_chain(ref)
      resources.select {|name, resource_definition|
        resource_definition.contains_reference_chain?(reference_chain)
      }
    end

    ##
    # The resource definitions all follow the same common pattern so it is easier
    # to define them with meta-programming.
    #
    # Unpacking the metaprogramming we get a macro of the following form
    #
    # def :keyword(name, &blk)
    #   @:store ||= {}
    #   if @:store[name]
    #     raise StandardError, "Resource (#{:klass}) with that name already exists: #{name}."
    #   end
    #   @:store[name] = contextual_evaluation(:klass, name, &blk)
    # end
    
    def self.define_context_keyword(keyword, context:)
      if instance_methods.include?(keyword)
        raise StandardError, "Method already defined: #{keyword}."
      end
      define_method(keyword) do |name, &blk|
        if resources[name]
          raise StandardError, "Resource (#{context}) already exists: #{name}."
        end
        # We don't really have any metadata to pass along when we are at the
        # top level since the parent pointer is gonna be passed along anyway
        # and includes everything we'd want to know so we just pass along
        # empty metadata
        resources[name] = contextual_evaluation(context, name, {}, &blk)
      end
    end

    ##
    # Security groups.
    
    define_context_keyword(
      :security_group, 
      context: SecurityGroup
    )

    ##
    # VPC.
    
    define_context_keyword(
      :vpc,
      context: Vpc
    )

    ##
    # Route tables.
    
    define_context_keyword(
      :route_table,
      context: RouteTable
    )

    ##
    # Subnets.
    
    define_context_keyword(
      :subnet,
      context: Subnet
    )

    ##
    # Internet gateways.
    
    define_context_keyword(
      :internet_gateway,
      context: InternetGateway
    )

    ##
    # EC2 instance definitions.
    
    define_context_keyword(
      :instance,
      context: Instance
    )

    ##
    # Network interface definition.
    
    define_context_keyword(
      :network_interface,
      context: NetworkInterface
    )

  end

end
