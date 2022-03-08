module Translatable
  module ActiveRecord
    module Macro

      def translatable(*attr_names)

        options = attr_names.extract_options!
        setup_translatable!(options) unless translatable?

        attr_names = attr_names.map(&:to_sym)
        attr_names -= translated_attribute_names if defined?(translated_attribute_names)

        if attr_names.present?

          attr_names.each do |attr_name|
            # Create accessors for the attribute.
            translated_attr_accessor(attr_name)
            translations_accessor(attr_name)

            # Add attribute to the list.
            self.translated_attribute_names << attr_name
            if options[:only]
              self.translated_serialized_attributes[attr_name] = options[:only] ? options[:only] : []
            end
          end

          on_after_save_callback(attr_names, options[:after_save]) if options[:after_save]
          on_before_save_callback(attr_names, options[:before_save]) if options[:before_save]
          on_after_update_callback(attr_names, options[:after_update]) if options[:after_update]
          on_before_update_callback(attr_names, options[:before_update]) if options[:before_update]

          Translatable.add_translatable self

        end
      end

      def class_name
        @class_name ||= begin
          class_name = table_name[table_name_prefix.length..-(table_name_suffix.length + 1)].downcase.camelize
          pluralize_table_names ? class_name.singularize : class_name
        end
      end

      def translatable?
        included_modules.include?(InstanceMethods)
      end

      protected
      def setup_translatable!(options)
        options[:table_name] ||= Translatable.translation_class.table_name
        options[:foreign_key] ||= 'record_id'
        options[:conditions] ||= {}
        options[:after_save] ||= false
        options[:before_save] ||= false

        class_attribute :translated_attribute_names, :translation_options, :fallbacks_for_empty_translations, :translated_serialized_attributes
        self.translated_attribute_names = []
        self.translation_options        = options
        self.fallbacks_for_empty_translations = options[:fallbacks_for_empty_translations]
        self.translated_serialized_attributes = Hash.new

        include InstanceMethods
        extend  ClassMethods

        translation_class.table_name = options[:table_name]

        has_many :translations, conditions(options), :class_name  => translation_class.name,
                 :foreign_key => options[:foreign_key],
                 :dependent   => :destroy,
                 :extend      => HasManyExtensions,
                 :autosave    => false

        after_create :save_translations!
        after_update :save_translations!
      end
      
      def conditions(options)        
        table_name = self.table_name      
        proc { 
          c = options[:conditions]
          c = self.instance_eval(&c) if c.is_a?(Proc) 
          c.merge!(:scope => table_name, :locale => Translatable.locale)

          where(c)
        }  
      end
      
    end

    module HasManyExtensions
      def find_or_initialize_by_locale(locale)
        with_locale(locale.to_s).first || build(:locale => locale.to_s)
      end
    end
  end
end
