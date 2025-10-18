class ListShare < ApplicationRecord
  belongs_to :list
  belongs_to :user, optional: true  # Optional until invite accepted

  # Enums
  enum :role, { viewer: 0, editor: 1, admin: 2 }
  enum :status, { pending: "pending", accepted: "accepted", declined: "declined" }

  # Validations
  validates :list_id, uniqueness: { scope: :user_id, message: "is already shared with this user" }, if: :user_id?
  validates :list_id, uniqueness: { scope: :email, message: "is already shared with this email" }, if: :email?
  validates :can_view, inclusion: { in: [ true, false ] }
  validates :can_edit, inclusion: { in: [ true, false ] }
  validates :can_add_items, inclusion: { in: [ true, false ] }
  validates :can_delete_items, inclusion: { in: [ true, false ] }
  validates :receive_notifications, inclusion: { in: [ true, false ] }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Callbacks
  before_validation :normalize_email
  before_create :prepare_status_and_links
  after_commit :deliver_notification_email, on: :create

  # Scopes
  scope :with_permission, ->(permission) { where(permission => true) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_list, ->(list) { where(list: list) }

  # Permission methods
  def can_view?
    can_view
  end

  def can_edit?
    can_edit
  end

  def can_add_items?
    can_add_items
  end

  def can_delete_items?
    can_delete_items
  end

  def receive_notifications?
    receive_notifications
  end

  # Update permissions
  def update_permissions(permission_params)
    update!(permission_params.slice(:can_view, :can_edit, :can_add_items, :can_delete_items, :receive_notifications))
  end

  # Check if user has specific permission
  def has_permission?(permission)
    case permission.to_s
    when "view"
      can_view?
    when "edit"
      can_edit?
    when "add_items"
      can_add_items?
    when "delete_items"
      can_delete_items?
    when "notifications"
      receive_notifications?
    else
      false
    end
  end

  # Get all permissions as hash
  def permissions_hash
    {
      can_view: can_view?,
      can_edit: can_edit?,
      can_add_items: can_add_items?,
      can_delete_items: can_delete_items?,
      receive_notifications: receive_notifications?
    }
  end

  # Check if this share allows the user to perform an action
  def allows_action?(action)
    case action.to_s
    when "view"
      can_view?
    when "edit"
      can_edit?
    when "create"
      can_add_items?
    when "destroy"
      can_delete_items?
    else
      false
    end
  end

  # Permissions (adjust if you want viewers read-only)
  def can_view_tasks?
    true
  end

  def can_create_tasks?
    editor? || admin?
  end

  def can_edit_tasks?
    editor? || admin?
  end

  def can_complete_tasks?
    editor? || admin?
  end

  def can_delete_tasks?
    admin?
  end

  def can_share_list?
    admin?
  end

  def receives_alerts?
    true  # All shared users get overdue alerts
  end

  # Invitation methods
  def accept!(user)
    update!(
      user: user,
      status: "accepted",
      accepted_at: Time.current
    )
  end

  def decline!
    update!(status: "declined")
  end

  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def declined?
    status == "declined"
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def prepare_status_and_links
    if (found = User.find_by(email: email))
      self.user = found
      self.status = "accepted"
      self.accepted_at = Time.current
      self.invitation_token = nil
    else
      self.status = "pending"
      self.invitation_token ||= SecureRandom.urlsafe_base64(24)
    end
  end

  def deliver_notification_email
    if accepted?
      ListShareMailer.with(list_share: self).added_email.deliver_later
    else
      ListShareMailer.with(list_share: self).invited_email.deliver_later
    end
  end

  def accepted?
    status == "accepted"
  end
end
