class Order < ApplicationRecord
  belongs_to :user, class_name: 'User', optional: true
  has_many :items, dependent: :destroy, foreign_key: 'order_id'
  has_many :item_users, through: :items, source: :user, class_name: 'User'
  has_one :owner, class_name: 'User', foreign_key: 'order_id'
  belongs_to :subject, polymorphic: true, optional: true
  has_many :ghosts, class_name: 'NotLoadedGhost'
  has_many :reviewers, class_name: 'User'
  has_many :editors, class_name: 'User'
  has_many :approvers, class_name: 'User'
  has_many :watchers, class_name: 'User'
  has_many :admins, class_name: 'Admin::User'
  has_many :attachments, as: :attachable
end
