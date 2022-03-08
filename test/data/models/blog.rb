class Blog < ActiveRecord::Base
  has_many :posts, -> { order(id: :asc) }
end
