module Dsl

  ##
  # Generate the DSL context and evaluate the given block in that context.
  # TODO: Figure out how to link contexts for better modularity.
  
  def self.define(name:, &blk)
    # Top level contexts don't have parents. That is until I decide on making contexts
    # into trees as well
    ctx = Context.new(name, nil)
    ctx.instance_eval(&blk)
    ctx
  end

end
