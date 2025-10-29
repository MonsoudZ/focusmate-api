# frozen_string_literal: true

class ListChannel < ApplicationCable::Channel
  def subscribed
    @list = find_authorized_list
    return if performed? # Early return if error was handled

    stream_for @list
    log_subscription_established
  end

  def unsubscribed
    log_subscription_terminated
  end

  # Handle incoming messages from clients
  def receive(data)
    log_message_received(data)
    
    case data['action']
    when 'ping'
      transmit({ type: 'pong', timestamp: Time.current.iso8601 })
    when 'typing'
      handle_typing_indicator(data)
    when 'presence'
      handle_presence_update(data)
    else
      log_unknown_action(data['action'])
      transmit({ type: 'error', message: 'Unknown action' })
    end
  end

  private

  def find_authorized_list
    list_id = params[:list_id]
    
    if list_id.blank?
      log_subscription_rejected("No list_id provided")
      reject_subscription("List ID is required")
      return nil
    end

    begin
      list = List.find(list_id)
    rescue ActiveRecord::RecordNotFound
      log_subscription_rejected("List not found: #{list_id}")
      reject_subscription("List not found")
      return nil
    end

    # Check if user has access to this list
    unless can_access_list?(list)
      log_subscription_rejected("Access denied to list #{list_id}")
      reject_subscription("Access denied")
      return nil
    end

    # Additional security checks
    unless list_active?(list)
      log_subscription_rejected("List is inactive: #{list_id}")
      reject_subscription("List is not available")
      return nil
    end

    list
  end

  def can_access_list?(list)
    return false unless list.present?
    return false unless current_user.present?

    # Check if user owns the list
    return true if list.user_id == current_user.id

    # Check if user is a member of the list
    return true if current_user.memberships.exists?(list_id: list.id)

    # Check if user has a coaching relationship with the list owner
    if defined?(CoachingRelationship) && list.user_id
      relationship = current_user.relationship_with_coach(User.find(list.user_id))
      return true if relationship&.active?
    end

    false
  end

  def list_active?(list)
    return false unless list.present?
    
    # Add any additional list status checks here
    # For example: list.active?, !list.archived?, etc.
    true
  end

  def handle_typing_indicator(data)
    return unless data['user_id'] == current_user.id

    # Broadcast typing indicator to other subscribers
    ActionCable.server.broadcast(
      "list_#{@list.id}",
      {
        type: 'typing',
        user_id: current_user.id,
        user_name: current_user.name || current_user.email,
        timestamp: Time.current.iso8601
      }
    )
  end

  def handle_presence_update(data)
    return unless data['user_id'] == current_user.id

    # Broadcast presence update to other subscribers
    ActionCable.server.broadcast(
      "list_#{@list.id}",
      {
        type: 'presence',
        user_id: current_user.id,
        user_name: current_user.name || current_user.email,
        status: data['status'] || 'online',
        timestamp: Time.current.iso8601
      }
    )
  end

  def reject_subscription(message)
    reject
    transmit({ type: 'error', message: message })
  end

  def log_subscription_established
    Rails.logger.info "[WebSocket] ListChannel subscription established: user ##{current_user.id} -> list ##{@list.id}"
  end

  def log_subscription_terminated
    Rails.logger.info "[WebSocket] ListChannel subscription terminated: user ##{current_user.id} -> list ##{@list.id}"
  end

  def log_subscription_rejected(reason)
    Rails.logger.warn "[WebSocket] ListChannel subscription rejected: #{reason} for user ##{current_user.id}"
  end

  def log_message_received(data)
    Rails.logger.debug "[WebSocket] ListChannel message received from user ##{current_user.id}: #{data.inspect}"
  end

  def log_unknown_action(action)
    Rails.logger.warn "[WebSocket] ListChannel unknown action '#{action}' from user ##{current_user.id}"
  end
end
