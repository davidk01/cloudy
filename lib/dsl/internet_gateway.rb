module Dsl

  class InternetGateway < Common::Resource

    define_keyword(
      :vpc,
      validation: Utils.method(:string_or_ref?),
      properties: [Common::KeywordProperties::Immutable]
    )

  end

end
