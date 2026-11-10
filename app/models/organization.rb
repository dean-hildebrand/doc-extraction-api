class Organization < ApplicationRecord
  has_many :api_keys, dependent: :destroy
  has_many :documents, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true
end
