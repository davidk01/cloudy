module Dsl

  module Validators

    class ReferenceValidator

      ##
      # Traverse all the collections and make sure references actually point to valid
      # definitions inside the context.
      
      def validate!(definitions)
        references = definitions.refs
        references.leaves.each do |ref|
          containing_resources = definitions.matching_resources(ref: ref)
          if containing_resources.length.zero?
            message = "Could not resolve reference: #{ref}."
            raise StandardError, message
          end
          if containing_resources.length > 1
            message = "Ambiguous reference. Several resources found for ref #{ref}."
            raise StandardError, message
          end
        end
      end

    end

  end

end
