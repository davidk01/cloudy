module Dsl

  module Executors

    class BasicExecutor

      O = Dsl::Operations

      def initialize(definition:, backend:, validators:, sorter:, matcher:, differ:)
        @definition = definition
        @backend = backend
        @matcher = matcher
        @differ = differ
        # Run validators to make sure our definition is kosher
        validators.each {|v| v.validate!(@definition)}
        # We need to know the order in which to modify the resources
        @sorted_resources = sorter.sort_resources(@definition)
        # Match up the local resources with remote resources. We need this for diffing
        @matched_resources = @sorted_resources.reduce({}) {|m, r| 
          m[r] = @matcher.find_matches(needle: r)
          m
        }
        # Initialize the first few work items
        @work_items = @sorted_resources.reduce({}) {|m, r|
          m[r] = [
            O::Operation[O::ReconcileWithCurrent], O::Operation[O::Diff]
          ]
          m
        }
      end

      ##
      # Are there any work items.
      
      def work?
        @work_items.any? {|k, v| v.any?}
      end

      ##
      # Grab the work item for the given resource and dispatch it.
      
      def do_resource_work(r)
        work_items = @work_items[r]
        work_item = work_items.shift
        return if work_item.nil?
        args = work_item.arguments
        case (op = work_item.operation)
        when O::ReconcileWithCurrent
          r.reconcile_with_current!(current: @matched_resources[r])
        when O::Diff
          diff = @differ.diff(target: r, current: @matched_resources[r])
          operation = O::Operation[O::ApplyDiff, diff]
          work_items.push(operation)
        when O::ApplyDiff
          if args.length > 1
            raise StandardError, "Too many arguments for operation: #{op}."
          end
          diffs = args.first
          diffs.each do |diff|
            case (diff_type = diff.type)
            when Differs::Type::Create
              backend_response = @backend.create_resource(resource: r)
              r.reconcile_with_backend_response!(backend_response: backend_response)
              if (unresolved_references = r.unresolved_references).any?
                resolution_operation = O::Operation[O::ResolveReferences, unresolved_references]
                work_items.push(resolution_operation)
              end
            when Differs::Type::Destroy
              raise StandardError
            when Differs::Type::Noop
              raise StandardError
            when Differs::Type::Modify
              raise StandardError
            else
              raise StandardError, "Unknown diff type: #{diff_type}."
            end # case diff_type
          end # diffs do
        when O::ResolveReferences
          resolved_references, unresolved_references = Hash.new {|h, k| h[k] = []}, 
            Hash.new {|h, k| h[k] = []}
          args.each do |refs|
            refs.each do |owner, ref_data|
              ref = ref_data[:ref]
              (ref.resolved? ? resolved_references : unresolved_references)[owner] << ref_data
            end
          end
          if resolved_references.any?
            resolved_operation = O::Operation[O::ResolvedReferences, resolved_references]
            work_items.push(resolved_operation)
          end
          if unresolved_references.any?
            resolution_operation = O::Operation[O::ResolveReferences, unresolved_references]
            work_items.push(resolution_operation)
          end
        when O::ResolvedReferences
          args.each do |refs|
            refs.each do |owner, ref_array|
              ref_array.each do |ref_data|
                # The path is an array of symbols that let us descend down the hierarchy
                # of the resources and extract the pieces we need. Each symbol in the path
                # must be something that can be passed to the various +[]+ methods and return
                # valid responses
                ref_path = Utils.ref_path(owner, ref_data)
                # The head is the top level context and we are not worried about it for the
                # time being.
                chopped_path = ref_path[1..-1]
                # Now we need the top-level resource because the backend only understands
                # things in terms of top-level resources
                mother_resource = @definition.resource(chopped_path.first)
                # The remaining elements in the path are what we will need to modify so we
                # pass it along to the backend
                modification_path = chopped_path[1..-1]
                backend_response = @backend.modify_resource(
                  resource: mother_resource,
                  modification_path: modification_path
                )
                require 'pry'; binding.pry
              end
            end
          end
        else # case op
          raise StandardError, "Unknown work item operation type: #{op}."
        end # case op
      end

      ##
      # Before trying to create or modify resources we first try to resolve
      # any unresolved references. TODO: Figure out if it is better to do this
      # before or after or before and after. And also what happens for references
      # that can potentially change after being resolved. Is that a possible scenario?
      
      def resolve_unresolved_references
        @unresolved_references ||= @definition.refs.leaves.reject(&:resolved?)
        @unresolved_references.each do |ref|
          @definition.try_to_resolve(ref: ref)
        end
        @unresolved_references = @unresolved_references.reject(&:resolved?)
      end

      ##
      # Iterate through resources and start dispatching the work items.
      
      def work!
        @sorted_resources.each do |r|
          # Q: Why do we do reference resolution both before and after resource work?
          # A: Because the work item could be creating the resource in which case we
          # can resolve all the references pointing to that resource. If we don't do this
          # then we will need to delay doing the creation work for various resource until
          # we come back to this loop again which is more error prone that calling reference
          # resolution before and after resource work.
          resolve_unresolved_references
          do_resource_work(r) 
          resolve_unresolved_references
        end
      end

      ##
      # Go through the process of setting things up on the backend.
      
      def execute!
        work! while work?
      end

    end

  end

end
