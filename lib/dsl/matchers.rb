module Dsl

  module Matchers

    class BasicMatcher

      attr_reader :backend

      def initialize(backend:)
        @backend = backend
      end
      
      ##
      # Try to find by ID, then try to find by tags, then try to find by name.
      # If nothing is found then return an empty list.
      
      def find_matches(needle:)
        (found = backend.find_by_id(id: needle[:id])).any? ||
          (found = backend.find_by_tags(tags: needle[:tags])).any? ||
          (found = backend.find_by_name(name: needle[:name])).any? ||
          (found = [])
      end

    end

  end

end
