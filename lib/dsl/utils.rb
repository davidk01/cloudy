module Dsl

  module Utils

    ##
    # References are nested so the leaf node comes first. We want it
    # in reverse order because when we are validating references we
    # need to go from parent to leaf node instead of leaf node to parent.
    # So we traverse the reference chain and then reverse the accumulator.
    
    def self.reference_chain(ref)
      chain = []
      while ref.parent
        chain << ref
        ref = ref.parent
      end
      chain << ref
      # Chop of the head because it is the root node and we don't care about root node
      chain.reverse[1..-1]
    end

    def self.one_of?(arg, *args)
      args.any? {|x| arg == x}
    end

    def self.int?(obj)
      (obj.to_i rescue nil) == obj
    end

    def self.string?(obj)
      (obj.to_s rescue nil) == obj
    end

    def self.symbol?(obj)
      (obj.to_sym rescue nil) == obj
    end

    def self.ref?(obj)
      RefChain === obj
    end

    def self.tag?(obj)
      Common::Tag === obj
    end

    def self.boolean?(obj)
      TrueClass === obj || FalseClass === obj
    end

    def self.boolean_set?(obj, key)
      boolean?(obj.instance_variable_get(key))
    end

    def self.string_or_ref?(obj)
      string?(obj) || ref?(obj)
    end

    ##
    # TODO: Fix the :parent_collection dependency so that it is less brittle because
    # if I change the metadata keys then this will silently break and return incorrect
    # paths.
    
    def self.ref_path(owner, ref_data)
      path_accumulator = ->(resource, accumulator) {
        if (metadata = resource.metadata).any? && (parent_collection = metadata[:parent_collection])
          accumulator << parent_collection
        end
        accumulator << resource[:name]
        if !(resource_parent = resource.parent).nil?
          path_accumulator[resource_parent, accumulator]
        else
          accumulator.reverse!
        end
      }
      path_accumulator[owner, [ref_data[:ref].value, ref_data[:keyword]]]
    end

  end

end
