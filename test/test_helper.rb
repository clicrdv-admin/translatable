require 'rubygems'
require 'bundler/setup'
require 'test/unit'
require 'fileutils'
require 'logger'

Bundler.require(:default, :test)
require 'database_cleaner'
require 'test_declarative'

log = '/tmp/translatable_test.log'
FileUtils.touch(log) unless File.exists?(log)
require 'active_record'
ActiveRecord::Base.logger = Logger.new(log)
ActiveRecord::LogSubscriber.attach_to(:active_record)
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

$:.unshift File.expand_path('../../lib', __FILE__)
require 'translatable'
require 'erb'

require File.expand_path('../data/models/translation', __FILE__)
Translatable.translation_class_name = 'Translation'

require File.expand_path('../data/schema', __FILE__)
require File.expand_path('../data/models', __FILE__)


DatabaseCleaner.strategy = :truncation

class Test::Unit::TestCase
  def setup
    I18n.locale = I18n.default_locale = :en
    Translatable.locale = nil
    DatabaseCleaner.start
  end

  def teardown
    DatabaseCleaner.clean
  end

  def with_locale(*args, &block)
    Translatable.with_locale(*args, &block)
  end

  def with_fallbacks
    previous = I18n.backend
    I18n.backend = BackendWithFallbacks.new
    I18n.pretend_fallbacks
    return yield
  ensure
    I18n.hide_fallbacks
    I18n.backend = previous
  end

  def assert_included(item, array)
    assert_block "Item #{item.inspect} is not included in the array #{array.inspect}" do
      array.include?(item)
    end
  end

  def assert_belongs_to(model, other)
    assert_association(model, :belongs_to, other)
  end

  def assert_has_many(model, other)
    assert_association(model, :has_many, other)
  end

  def assert_association(model, type, other)
    assert model.reflect_on_all_associations(type).any? { |a| a.name == other }
  end

  def assert_translated(record, locale, attributes, translations)
    assert_equal Array.wrap(translations), Array.wrap(attributes).map { |name| record.send(name, locale) }
  end
end

ActiveRecord::Base.class_eval do
  class << self
    def index_exists?(index_name)
      connection.indexes(table_name).any? { |index| index.name == index_name.to_s }
    end

    def index_exists_on?(column_name)
      connection.indexes(table_name).any? { |index| index.columns == [column_name.to_s] }
    end
  end

  # undo dup backport if Object has private method initialize_dup, so that
  # initialize_dup does not get accidentally called when testing against
  # rbx-2.x and Rails 3.1
  if Module.const_defined?(:RUBY_ENGINE) && (RUBY_ENGINE == 'rbx') && Object.respond_to?(:initialize_dup, true)
    def dup
      super
    end
  end
end

class BackendWithFallbacks < I18n::Backend::Simple
  include I18n::Backend::Fallbacks
end

meta = class << I18n; self; end
meta.class_eval do
  alias_method(:alternatives, :fallbacks)

  def pretend_fallbacks
    class << I18n; self; end.send(:alias_method, :fallbacks, :alternatives)
  end

  def hide_fallbacks
    class << I18n; self; end.send(:remove_method, :fallbacks)
  end
end

I18n.hide_fallbacks
