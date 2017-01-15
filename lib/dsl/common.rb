module Dsl

  module Common

    ##
    # Properties for the DSL keywords. These are basically assumptions we can make about
    # the keyword. The idea being that when we are traversing the list of resource
    # we can use these properties to decide what to do. The main example being about
    # breaking cycles basically. If we know a property is mutable then we can defer
    # modifications until after the resource is created. This happens a lot with security
    # groups that have cyclic dependencies.
    
    module KeywordProperties
      Lazy = :lazy
      Mutable = :mutable
      Immutable = :immutable
    end

    ##
    # Most resources should inherit from this class because most resources need
    # a name and a parent link/context.
    
    class Resource

      attr_reader :parent, :metadata

      ##
      # When inherited we need to define some class instance variables so that DSL keyword
      # definitions work properly. We track keywords, collections, and delayed keywords
      # so that when we are traversing the AST to figure stuff out we can do it
      # generically by just inspecting those class instance variables.
      
      def self.inherited(subclass)
        subclass.instance_eval do

          ##
          # We keep track of keyword definitions in these hash maps so that
          # we can have generic methods for traversing the AST and verifying
          # various properties.
          
          @keywords, @collections = {}, {}

          ##
          # Every resource always has an associated ID that can be filled in. In fact
          # it should be filled in as soon as possible so that whatever other
          # resources reference IDs can be resolved as soon as possible.
          
          define_keyword(
            :id,
            properties: [
              Common::KeywordProperties::Lazy, 
              Common::KeywordProperties::Immutable
            ],
            validation: Utils.method(:string?)
          )

          ##
          # Tags are common to all resources unless +ignore_tags!+ is called in which case
          # we don't worry about tags.
          
          define_keyword(
            :tags,
            required: false,
            default: [],
            validation: ->(tgs) { 
              ignore_tags? || (tgs.all? {|t| Utils.tag?(t)} && tgs.length > 0)
            },
            properties: [
              Common::KeywordProperties::Mutable
            ]
          )

          ##
          # Every resource needs a name so we can easily reference it.
          
          define_keyword(
            :name,
            required: true,
            validation: Utils.method(:symbol?),
            properties: [
              Common::KeywordProperties::Mutable
            ]
          )

        end
      end

      ##
      # Are there still any unresolved references owned by this resource.
      
      def unresolved_references
        downward_owned_refs.reject {|owner, ref_data| 
          ref_data[:ref].resolved?
        }
      end

      ##
      # Lazily initialize a hash map for tracking references created inside
      # a resource.
      
      def owned_refs
        @owned_refs ||= {}
      end

      ##
      # Union the owned references for this resource and all references owned by nested
      # collections.
      
      def downward_owned_refs
        collections.flat_map {|collection_name, collection_properties|
          instance_eval(&collection_properties[:storage]).map {|resource_name, resource|
            resource.downward_owned_refs
          }
        }.reduce(owned_refs) {|m, r| m.merge(r)}
      end

      ##
      # Convert the resource into a structure that can be converted to JSON. This is going
      # to be our serialization format for checkpointing and other purposes.
      # TODO: Write deserialization logic.
      
      def as_json(options = nil)
        keywords_as_json = keywords.reduce({}) {|memo, (keyword, _)|
          instance_variable = instance_variable_get('@' + keyword.to_s)
          converted_value = instance_variable.nil? ? nil : instance_variable.as_json(options)
          memo[keyword] = converted_value
          memo
        }
        collections_as_json = collections.reduce({}) {|memo, (keyword, collection_data)|
          value = instance_eval(&collection_data[:storage]).as_json(options)
          memo[keyword] = value
          memo
        }
        json = keywords_as_json.merge(collections_as_json)
        # We also need to add the class so that we can deserialize
        if json['class']
          message = "'class' is a reserved keyword: #{self}."
          raise StandardError, message
        end
        json['class'] = self.class
        json
      end

      ##
      # Figure out the list of changes that need to be performed to take the current
      # state of the resource to the new state of the resource.
      
      def diff(current:)
        unless self.class == current.class || current == NullResource
          message = [
            "Can not perform diff on two different resource types:",
            "#{self.class}, #{current.class}"
          ].join(' ')
          raise StandardError, message
        end
        # The null resource case is easy because that means need to create
        # the resource
        if current == NullResource
          return [
            Diff.new(
              resource: self, 
              type: Diff::Type::Create, 
              payload: Diff::Payload.new
            )
          ]
        end
        # Now see what non-lazy keywords we have see what changes we need to make
        keyword_diffs = keywords.select {|keyword, keyword_data|
          require 'pry'; binding.pry
        }.map {|keyword, keyword_data|
          require 'pry'; binding.pry
        }
        # Similar comparison operation for collections
        collection_diffs = collections.select {|keyword, collection_data|
          require 'pry'; binding.pry
        }.map {|keyword, collection_data|
          require 'pry'; binding.pry
        }
        # Now combine and return the diff operations
        keyword_diffs + collection_diffs
      end

      ##
      # Some resources do not need tags so they can opt out by calling this method.
      
      def self.ignore_tags!
        @ignore_tags = true
      end

      ##
      # Are we ignoring tags for instances of this resource?
      
      def ignore_tags?
        self.class.instance_variable_defined?(:@ignore_tags)
      end

      ##
      # If there are required values or even not required values that
      # have defaults then we fill them in before performing validation.
      
      def fill_in_defaults
        # First fill-in any non-lazy keywords with defaults
        keywords.reject {|_, keyword_data|
          keyword_data[:properties].include?(Common::KeywordProperties::Lazy)
        }.each do |keyword, keyword_data|
          instance_variable = '@' + keyword.to_s
          variable_value = instance_variable_get(instance_variable)
          default = keyword_data[:default]
          if variable_value.nil?
            unless default.nil?
              send(keyword, default)
            end
          end
        end
        # Now do the same for any nested collections
        collections.each do |key, storage_data|
          storage = storage_data[:storage]
          elements = instance_eval(&storage)
          elements.each do |_, element|
            element.fill_in_defaults
          end
        end
      end

      ##
      # We have defined the collection keywords above so we can generically traverse
      # the collections and validate all items inside.
      
      def validate!
        # TODO: This should not be special cased.
        unless ignore_tags?
          unless @tags
            raise StandardError, "Must define tags: #{self.class}."
          end
        end
        # Traverse any nested collections and validate them
        collections.each do |key, storage_data|
          storage = storage_data[:storage]
          elements = instance_eval(&storage)
          if storage_data[:required]
            unless elements.any?
              raise StandardError, "There must be at least one #{key} set: #{self}."
            end
          end
          elements.each do |_, element|
            element.validate!
          end
        end
        # Now validate any required keywords by making sure they are actually set
        keywords.reject {|keyword, keyword_data| 
          keyword_data[:properties].include?(Common::KeywordProperties::Lazy)
        }.each do |keyword, keyword_data|
          instance_variable = '@' + keyword.to_s
          variable_value = instance_variable_get(instance_variable)
          if keyword_data[:required] && variable_value.nil?
            raise StandardError, "Required keyword is not set: #{keyword}, #{self}."
          end
        end
      end

      ##
      # The keywords that are mutable and that have references are considered mutable
      # references and these allow us to ignore any potential cyclic dependencies.
      # The second argument is required because collections can have properties as
      # well and when we descend into the collection we need to pass along the
      # collection properties. This might potentially lead to interesting conflicts
      # when the parent says the entire collection is mutable but a specific item in
      # the collection doesn't think the reference is mutable.
      
      def mutable_ref?(ref:, collection_properties: [])
        # Is the ref one of the keywords. This is kinda tricky because some keywords
        # can be an array of values and in that case we have to check if the array
        # contains the ref instead of being equal to it
        matching_keywords = keywords.select {|keyword, keyword_properties|
          instance_variable, instance_variable_value = '@' + keyword.to_s, nil
          if instance_variable_defined?(instance_variable)
            instance_variable_value = instance_variable_get(instance_variable)
          end
          (
            ref.class == instance_variable_value.class && 
            ref == instance_variable_value
          ) || (
            instance_variable_value.respond_to?(:any?) && 
            instance_variable_value.any? {|v| ref == v}
          )
        }
        # We have to union the collection properties that were passed to us from
        # our parent context because elements of a mutable collection inherit
        # mutability from their parent context
        mutable_keywords = matching_keywords.select {|keyword, keyword_properties|
          unioned_properties = keyword_properties[:properties] | collection_properties
          unioned_properties.include?(Common::KeywordProperties::Mutable)
        }
        # We found a matching so let us see if it is mutable or not
        if matching_keywords.any?
          # It is mutable so we can stop
          return mutable_keywords.any?
        else
          # We found a matching keyword but it was not mutable so stop
          return false
        end
        # We did not find matching keywords so we must descend into the nested collections
        matching_collection_elements = collections.flat_map {|keyword, col_properties|
          storage = col_properties[:storage]
          elements = instance_eval(&storage)
          elements.select {|name, ctx|
            ctx.mutable_ref?(ref: ref, collection_properties: col_properties[:properties])
          }
        }
        # Did we find any matching references among the nested collections and were they mutable?
        matching_collection_elements.any?
      end

      ##
      # Create a tag.
      
      def tag(key, value)
        Tag.new(key, value)
      end

      ##
      # Create the ref prototype so we can call +[]+ on it to start chaining refs.
      
      def refs
        parent.refs
      end

      ##
      # Basic stuff. Just initialize the necessities for tracking the parent
      # context and references.
      
      def initialize(name, parent, metadata)
        unless Utils.symbol?(name)
          raise StandardError, "Name must be a symbol: #{name}."
        end
        @name, @parent, @metadata = name, parent, metadata
      end

      ##
      # When performing matching and other actions we need to be able to look up
      # various attributes associated with the resource.
      
      def [](attribute)
        unless Utils.symbol?(attribute)
          raise StandardError, "Attributes must be symbols: #{attribute}."
        end
        unless keywords[attribute] || collections[attribute]
          raise StandardError, "Unknown attribute: #{attribute}."
        end
        if instance_variable_defined?(var = '@' + attribute.to_s)
          instance_variable_get(var)
        else
          nil
        end
      end

      ##
      # Grab the keywords for the nested collections.
      
      def collections
        self.class.instance_variable_get(:@collections)
      end

      ##
      # Grab all the keywords.
      
      def keywords
        self.class.instance_variable_get(:@keywords)
      end

      ##
      # TODO: Take the current resources if there are any and try to fill in any
      # missing attributes. Each resource will have its own reconcilation logic
      # potentially.
      
      def reconcile_with_current!(current:)
        if current.length > 1
          raise StandardError, "Ambiguous reconciliation."
        end
        if current.any?
          # Otherwise just fill in the ID field
          id current.first[:id]
        end
      end

      ##
      # TODO: In theory each resource should have its own reconcilation logic so this will
      # need to be moved to the resource at some point.
      
      def reconcile_with_backend_response!(backend_response:)
        id backend_response[:id]
      end

      ##
      # Go through the keywords and nested collections and see
      # if the reference chain matches. The main context object uses this to
      # figure out if the references are valid. If a reference is dangling
      # (meaning it doesn't point to anything valid) then the resource
      # definitions are inconsistent.
      
      def contains_reference_chain?(ref_chain)
        @ref_chain_inclusion_cache ||= {}
        cached_value = @ref_chain_inclusion_cache[ref_chain]
        unless cached_value.nil?
          return cached_value
        end
        # First make sure the head of the chain matches our name
        if ref_chain[0].node == @name
          # Now chop off the head and see if there is anything left
          ref_chain = ref_chain[1..-1]
          if ref_chain.length == 1
            ref_name = ref_chain.first.node
            # If there is only 1 thing left then it must match one of the keywords
            @ref_chain_inclusion_cache[ref_chain] = 
              keywords.keys.select {|k| k == ref_name}.length == 1
          else
            # Otherwise it must be something that matches in one of the sub-collections
            @ref_chain_inclusion_cache[ref_chain] = collections.flat_map do |c, storage_data|
              storage = storage_data[:storage]
              instance_eval(&storage).values.select {|r| r.contains_reference_chain?(ref_chain)}
            end.length == 1
          end
        else
          @ref_chain_inclusion_cache[ref_chain] = false
        end
      end

      ##
      # The method used to define keywords for setting attributes in the context.
      # Keywords can have several properties that informs how they should be used
      # when it comes time to doing cross-referencing and topological sorting to 
      # figure out which resources should be defined when.

      def self.define_keyword(
        keyword, validation: ->(_) { true }, 
        transformer: ->(x) { x }, required: true, default: nil,
        properties: []
      )
        if @keywords[keyword]
          raise StandardError, "Keyword already defined: #{keyword}."
        end
        if @collections[keyword]
          message = "Keyword already defined as a collection keyword: #{keyword}."
          raise StandardError, message
        end
        @keywords[keyword] = {
          validation: validation, transformer: transformer,
          required: required, default: default, properties: properties
        }
        # Gotta make sure we are not clobbering anything
        if instance_methods.include?(keyword)
          raise StandardError, "Method already defined: #{keyword}."
        end
        define_method(keyword) do |arg|
          unless instance_exec(arg, &validation)
            raise StandardError, "Invalid argument for keyword: #{self[:name]}, #{keyword}, #{arg}."
          end
          if instance_variable_defined?(storage = '@' + keyword.to_s)
            raise StandardError, "Configuration value already set: #{instance_variable_get(storage)}."
          end
          if RefChain === arg
            owned_refs[self] = {ref: arg, keyword: keyword}
          end
          instance_variable_set(storage, instance_exec(arg, &transformer))
        end
      end

      ##
      # Some keywords store the data in a hashmap and this is the common pattern
      # for defining such keywords.
      
      def self.define_collection_keyword(
        keyword, storage:, context:, required: true,
        properties: []
      )
        if @collections[keyword]
          raise StandardError, "Collection keyword already defined: #{keyword}."
        end
        if @keywords[keyword]
          message = "Keyword already defined as a regular keyword: #{keyword}."
          raise StandardError, message
        end
        @collections[keyword] = {
          storage: storage, context: context, required: required,
          properties: properties
        }
        if instance_methods.include?(keyword)
          raise StandardError, "Method already defined: #{keyword}."
        end
        define_method(keyword) do |name, &blk|
          if (store = instance_eval(&storage))[name]
            raise StandardError, "Collection element already exists: #{name}."
          end
          # We also pass along any other extra information that might later be
          # necessary to traverse the resource graph
          # TODO: This feels brittle. Figure out if there is a better way
          metadata = {
            parent_collection: keyword
          }
          store[name] = Context.contextual_evaluation(context, name, metadata, &blk)
        end
      end

    end

    ##
    # CIDR blocks are used in a few places so they should be a common resource.
    
    class CidrBlock < BasicObject

      ##
      # We just delegate to a CIDR block library.
      
      def initialize(cidr_block)
        @cidr_block = ::NetAddr::CIDR.create(cidr_block)
      end

      def class
        CidrBlock
      end

      def as_json(options = nil)
        cidr_block
      end

      def cidr_block
        @cidr_block
      end

      def to_s
        @cidr_block.to_s
      end

      def inspect
        to_s
      end

      ##
      # By definition can not be nil.
      
      def nil?
        false
      end

      ##
      # When checking refs in subnets we come across cidr blocks and the way we check
      # mutability we need +respond_to?+ to be defined.
      
      def respond_to?(sym, priv = false)
        [:nil?, :inspect, :to_s, :as_json, :cidr_block].include?(sym)
      end

    end

    ##
    # Many AWS resources can have tags.
    
    class Tag < BasicObject

      ##
      # Tag must have a key and a value. Key must be a symbol. Value must be a string.
      
      def initialize(key, value)
        unless key.to_sym == key
          ::Kernel.raise ::StandardError, "Key must be a symbol."
        end
        unless value.to_s == value
          ::Kernel.raise ::StandardError, "Value must be a string."
        end
        @key, @value = key, value
      end

      ##
      # Pre-json form for tags.
      
      def as_json(options = nil)
        {'key' => @key, 'value' => @value}
      end

      ##
      # I didn't know basic objects did not know how to look up their class.
      
      def class
        Tag
      end

      def ==(other)
        other && 
          (self.class == other.class) && 
          (@key == other.key) && 
          (@value == other.value)
      end

      def to_s
        "#{@key} -> #{@value}"
      end

      def inspect
        to_s
      end

      def key
        @key
      end

      def value
        @value
      end

      def const_missing(c)
        ::Object.const_get(c)
      end

    end

  end

end
