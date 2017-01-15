module Dsl

  class ::Array

    def as_json(options = nil)
      map {|e| e.as_json(options)}
    end

  end

  class ::Integer

    def as_json(options = nil)
      self
    end
  end

  class ::TrueClass

    def as_json(options = nil)
      self
    end

  end

  class ::FalseClass

    def as_json(options = nil)
      self
    end
  end

  class ::String

    def as_json(options = nil)
      self
    end

  end

  class ::Hash

    def as_json(options = nil)
      reduce({}) {|m, (k, v)| m[k.to_s] = v.as_json(options); m}
    end

  end

  class ::Symbol

    def as_json(options = nil)
      self
    end

  end

end
