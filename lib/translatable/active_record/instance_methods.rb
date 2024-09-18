module Translatable
  module ActiveRecord
    module InstanceMethods
      delegate :translated_locales, :to => :translations

      def translatable
        @translatable ||= Adapter.new(self)
      end

      def self.included(base)
        # Maintian Rails 3.0.x compatibility ..
        if base.method_defined?(:assign_attributes)
          base.class_eval %{
            def assign_attributes(attributes, *options)
              with_given_locale(attributes) { super }
            end
          }
        else
          base.class_eval %{
            def attributes=(attributes, *args)
              with_given_locale(attributes) { super }
            end

            def update_attributes!(attributes, *args)
              with_given_locale(attributes) { super }
            end

            def update_attributes(attributes, *args)
              with_given_locale(attributes) { super }
            end
          }
        end
      end

      # Always call the super method, the attribute is translatable and we asked a translated model
      def write_attribute(name, value, options = {}, &block)
        if r_translated?(name) && translate?
          options = {:locale => Translatable.locale}.merge(options)

          # We don't want to track any changes, but save the new value in a translation hash

          translatable.write(options[:locale], name, value)
        else
          super(name, value)
        end
      end

      def translate
        @translate_me = true
        self
      end

      def end_translate
        @translate_me = nil
        self
      end

      def reload(options = nil)
        @translate_me = false
        translation_caches.clear
        translated_attribute_names.each { |name| @attributes.reset(name.to_s) }
        translatable.reset
        super(options)
      end

      def save(**)
        @translate_me = false
        super
      end

      def translate?
        !@translate_me.nil? && @translate_me
      end

      def read_attribute(name, options = {}, &block)
        options = {:translated => true, :locale => Translatable.locale}.merge(options)
        if r_translated?(name) and options[:translated]
          serialized_value = super(name) if self.attributes.has_key?(name)
          if translate? && (value = translatable.fetch(options[:locale] || Translatable.locale, name, serialized_value))
            value
          else
            super(name)
          end
        else
          super(name)
        end
      end

      def r_translated?(name)
        self.class.translated?(name)
      end

      def translated_attributes
        translated_attribute_names.inject({}) do |attributes, name|
          attributes.merge(name.to_s => translation.send(name))
        end
      end

      # This method is basically the method built into Rails
      # but we have to pass {:translated => false}
      def untranslated_attributes
        attrs = {}
        attribute_names.each do |name|
          attrs[name] = read_attribute(name, {:translated => false})
        end
        attrs
      end

      def translation_for(locale, name, build_if_missing = false)
        unless translation_caches["#{locale}_#{name}"]
          # Fetch translations from database as those in the translation collection may be incomplete
          _translation = translations.detect{|t| t.locale.to_s == locale.to_s && t.key.to_s == name.to_s }
          _translation ||= translations.build(:locale => locale) if build_if_missing
          translation_caches["#{locale}_#{name}"] = _translation if _translation
        end
        translation_caches["#{locale}_#{name}"]
      end

      # Fetch translations per keys in the form
      # model_attr_serialized_attribute
      # E.G.1: ```Model``` has attribute ```config``` which has a key ```auto_save```
      #         will have a translation key ```config_auto_save```
      # E.G.2: ```Model``` has attribute ```config``` which is an array of ```user_id => ([0-9]+)```
      #         will have translations key containing the index: ```config_user_id_0```, ```config_user_id_1```...
      def translation_for_serialized(locale, name, value, build_if_missing = false)

        unless translation_caches["#{locale}_#{name}"]
          engine = self.attributes.has_key?(name) ? nil : JSON
          deserialized_value = engine.nil? ? value : engine.load(value)

          only = self.translated_serialized_attributes[name.to_sym].map(&:to_s)
          if only.empty?
            regex_keys = /\A#{name.to_s}_([a-z_]+[a-z])(?:_([0-9]*))?\Z/
          else
            regex_keys = /\A#{name.to_s}_(#{only.join('|')})(?:_([0-9]*))?\Z/
          end
          # Fetch translations from database as those in the translation collection may be incomplete
          _translations = translations.select{|t| t.locale.to_s == locale.to_s && t.key.to_s =~ regex_keys }
          _translations.each do |t|
            matched = t.key.match regex_keys
            unless matched.nil?
              if matched.size == 3
                sub_attr = matched[1]
                index = matched[2].to_i
                value[index][sub_attr] = t.value if value.size > index && value[index].has_key?(sub_attr)
              elsif matched.size == 3
                sub_attr = matched[1]
                value[sub_attr] = t.value if value.has_key?(sub_attr)
              end
            end
          end

          translation_caches["#{locale}_#{name}"] = value
        end
        translation_caches["#{locale}_#{name}"]
      end

      def translation_caches
        @translation_caches ||= {}
      end


      def with_given_locale(attributes, &block)
        attributes.symbolize_keys! if attributes.respond_to?(:symbolize_keys!)

        locale = respond_to?(:locale=) ? attributes.try(:[], :locale) :
            attributes.try(:delete, :locale)

        if locale && !respond_to?(:locale=)
          already = translate?
          translate unless translate?
          Translatable.with_locale(locale, &block)
          end_translate unless already
        else
          yield
        end
      end

      def translations_by_locale(&block)
        translations.each_with_object(HashWithIndifferentAccess.new) do |t, hash|
          hash[t.locale] ||= HashWithIndifferentAccess.new
          hash[t.locale][t.key] = block_given? ? block.call(t) : t
        end
      end

      protected

      def save_translations!
        translatable.save_translations!
        translation_caches.clear
      end

    end
  end
end
