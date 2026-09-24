# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  company_name           :string
#  created_at             :datetime         not null
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  jti                    :string           not null
#  membership_expires_at  :datetime
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :string           default("company"), not null
#  updated_at             :datetime         not null
#
class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher

  audited

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: self

  enum :role, { admin: "admin", company: "company" }, default: "company"

  validates :role, presence: true, inclusion: { in: roles.keys }
  validates :company_name, presence: true, if: -> { role == "company" }

  before_validation :initialize_jti, on: :create
  before_create :set_default_membership_expiration

  def active_for_authentication?
    super && (admin? || (active? && (membership_expires_at.nil? || membership_expires_at >= Time.current)))
  end

  def membership_expired?
    return false if admin?
    return true if membership_expires_at.present? && Time.current > membership_expires_at
    false
  end

  private

  def initialize_jti
    self.jti ||= SecureRandom.uuid
  end

  def set_default_membership_expiration
    if company? && membership_expires_at.nil?
      self.membership_expires_at = 1.month.from_now
    end
  end
end
