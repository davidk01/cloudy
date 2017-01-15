module Dsl

  ##
  # Used for dry runs and basic validation.
  
  class InMemoryBackend

    ##
    # Where we stash the resources.
    
    @resources = {}

    ##
    # ID counter. Incremented every time a new resource is added and then converted to a string
    # because AWS resource IDs are strings.
    
    @id = 0

    ##
    # Find resources by ID.
    
    def self.find_by_id(id:)
      if (match = @resources[id])
        [match]
      else
        []
      end
    end

    ##
    # Find a resource by name.
    
    def self.find_by_name(name:)
      @resources.select {|id, res| res[:name] == name}.values
    end

    ##
    # Find resources by tags.
    
    def self.find_by_tags(tags:)
      if tags && tags.any?
        found = @resources
        tags.each do |tag|
          found = @resources.select {|id, resource| resource[:tags].include?(tag)}
        end
        if found.any?
          return found
        end
      end
      []
    end

    ##
    # Create the resource. For this backend that just means creating an ID while
    # making sure there is no resource by that name already.
    
    def self.create_resource(resource:)
      if find_by_name(name: resource[:name]).any?
        raise StandardError, "Resource names must be unique: #{resource[:name]}."
      end
      # We can't create a resource that is not mostly complete. Mostly complete means
      # all the required keywords are available and fully resolved if they are references.
      require 'pry'; binding.pry
      # TODO: Figure this out. This is trickier than I expected
      property_accumulator = {}
      resource.keywords.each do |keyword, keyword_properties|
        keyword_value = resource[keyword]
        if resource.required_keyword?(keyword) && keyword_value.nil? && !resource.lazy_keyword?(keyword)
            raise StandardError, "Required property is not set: #{keyword}."
          end
        end
      end
      response = {id: (@id += 1).to_s}
      @resources[response[:id]] = resource
      response
    end

    ##
    # Given a top-level resource we descend along the path and try to perform the modification
    # if possible. 
    
    def self.modify_resource(resource:, modification_path:)
      unless modification_path.length >= 2
        raise StandardError, "Modification path must have at least 2 elements: #{modification_path}."
      end
      require 'pry'; binding.pry
    end

  end

end
