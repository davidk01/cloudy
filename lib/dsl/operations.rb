module Dsl

  module Operations

    ##
    # Allowed operation types.
    
    Ops = Set.new([
      ReconcileWithCurrent = :reconcile_with_current,
      Diff = :diff,
      ApplyDiff = :apply_diff,
      ResolveReferences = :resolve_references,
      ResolvedReferences = :resolved_references
    ])

    ##
    # Container for an operation with potentially some extra arguments.
    
    class Operation

      def self.[](op, *args)
        Operation.new(operation: op, arguments: args)
      end

      attr_reader :operation, :arguments

      def initialize(operation:, arguments:)
        unless Ops.include?(operation)
          raise StandardError, "Unknown operation: #{operation}."
        end
        @operation = operation
        @arguments = arguments
      end

    end

  end

end
