module Dsl

  module Differs

    ##
    # The constants for the various types of diffing operations.
    
    module Type
      Create = :create
      Destroy = :destroy
      Modify = :modify
      Noop = :noop
    end

    ##
    # Basic container for diffing operations.
    
    class BasicDiff

      attr_reader :type, :target, :diffs

      def initialize(type:, target:, diffs:)
        unless Type.constants(false).map(&:downcase).include?(type)
          raise StandardError, "Unknown diff type: #{type}."
        end
        @type = type
        @target = target
        @diffs = diffs
      end

    end

    class BasicDiffer

      ##
      # We can only do a diff on non-ambiguous matches, i.e. current must have at most
      # 1 resource.
      
      def diff(target:, current:)
        case current.length
        when 0
          [BasicDiff.new(type: Type::Create, target: target, diffs: [])]
        when 1
          raise StandardError, "Implement!"
        else
          raise StandardError, "Ambiguous diff."
        end
      end

    end

  end

end
