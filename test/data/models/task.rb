class Task < ActiveRecord::Base
  translatable :name, :fallbacks_for_empty_translations => true
  cattr_accessor :fallbacks
  def globalize_fallbacks(locale)
    self.class.fallbacks || super
  end
end
