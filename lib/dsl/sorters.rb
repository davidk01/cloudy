module Dsl

  module Sorters

    ##
    # Figures out the order in which resources should be provisioned.
    
    class TopologicalSorter

      def initialize
        @temporarily_marked_nodes = {}
        @permanently_marked_nodes = {}
        @unmarked_nodes = {}
      end

      ##
      # Visit method as defined in the wikipedia article. We only worry about
      # non-mutable references because mutable references can always be added to the
      # resource after the fact and do not create a dependency chain.
      
      def visit(node:)
        if @temporarily_marked_nodes[node]
          raise StandardError, "Not a DAG. Cycle detected: #{node.name}."
        end
        unless @permanently_marked_nodes[node]
          @temporarily_marked_nodes[node] = true
          node.downward_owned_refs.each do |owner, ref_data|
            ref = ref_data[:ref]
            unless owner.mutable_ref?(ref: ref)
              # There should be only 1 matching node because references
              # should not be ambiguous which is validated with +validate_references!+ method
              matching = @resources.matching_resources(ref: ref).values
              matching.each do |n|
                visit(node: n)
              end
            end
          end
          @permanently_marked_nodes[node] = true
          @temporarily_marked_nodes.delete(node)
          @sorted << node
        end
      end

      ##
      # See https://en.wikipedia.org/wiki/Topological_sorting
      
      def sort_resources(resources)
        @resources = resources
        @sorted = []
        @resources.resources.each do |resource_name, resource_data|
          @unmarked_nodes[resource_data] = true
        end
        while @unmarked_nodes.keys.any?
          unmarked_node = @unmarked_nodes.keys.pop
          @unmarked_nodes.delete(unmarked_node)
          visit(node: unmarked_node)
        end
        @sorted
      end

    end

  end

end
