class Post < ActiveRecord::Base
  translatable :title, :content, :published, :published_at
  validates_presence_of :title
  scope :with_some_title, -> { where(:title => 'some_title') }
end
