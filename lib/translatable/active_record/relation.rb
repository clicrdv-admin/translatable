module Translatable
  module ActiveRecord
    module Relation
      def exec_queries
        queries = super

        return queries.map(&:translate) if @translate_records

        queries
      end

      private

      def translate
        @translate_records = true

        self.eager_load(:translations)
      end
    end
  end
end

class Railtie < Rails::Railtie

  initializer "easy_translatable.configure_rails_initialization" do
    ActiveSupport.on_load(:active_record) do
      ActiveRecord::Relation.send :prepend, Translatable::ActiveRecord::Relation
    end
  end

end if defined?(Rails)
