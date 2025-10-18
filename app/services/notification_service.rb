class NotificationService
  class << self
    
    # ==========================================
    # TASK-RELATED NOTIFICATIONS
    # ==========================================
    
    # When coach assigns a new task to client
    def new_item_assigned(task)
      return unless task.created_by_coach?
      
      client = task.list.owner
      
      send_apns_notification(
        user: client,
        title: "📋 New Task from #{task.creator.name || 'Your Coach'}",
        body: task.title,
        data: {
          type: 'new_task',
          task_id: task.id,
          list_id: task.list_id,
          priority: task.priority,
          due_at: task.due_at&.iso8601
        },
        badge: calculate_badge_count(client),
        sound: 'default',
        category: 'TASK_NEW'
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'new_task_assigned',
        message: "New task assigned: #{task.title}"
      )
    end
    
    # When client completes a task
    def task_completed(task)
      return unless task.created_by_coach?
      
      task.list.coaches.each do |coach|
        relationship = task.list.owner.relationship_with_coach(coach)
        next unless relationship&.notify_on_completion?
        next unless task.visible_to?(coach)
        
        send_apns_notification(
          user: coach,
          title: "✅ Task Completed",
          body: "#{task.list.owner.name} completed: #{task.title}",
          data: {
            type: 'task_completed',
            task_id: task.id,
            client_id: task.list.owner.id,
            client_name: task.list.owner.name
          },
          badge: nil, # Don't update coach's badge
          category: 'TASK_COMPLETED'
        )
        
        log_notification(
          task: task,
          user: coach,
          type: 'task_completed',
          message: "#{task.list.owner.name} completed task"
        )
      end
    end
    
    # When task becomes overdue
    def task_missed(task)
      task.list.coaches.each do |coach|
        relationship = task.list.owner.relationship_with_coach(coach)
        next unless relationship&.notify_on_missed_deadline?
        next unless task.visible_to?(coach)
        
        send_apns_notification(
          user: coach,
          title: "⚠️ Task Missed",
          body: "#{task.list.owner.name} missed: #{task.title}",
          data: {
            type: 'task_missed',
            task_id: task.id,
            client_id: task.list.owner.id,
            minutes_overdue: task.minutes_overdue
          },
          sound: 'default',
          category: 'TASK_MISSED'
        )
        
        log_notification(
          task: task,
          user: coach,
          type: 'task_missed',
          message: "Task missed deadline"
        )
      end
    end
    
    # When task requires explanation from client
    def task_missed_needs_explanation(task)
      client = task.list.owner
      
      send_apns_notification(
        user: client,
        title: "❗️ Explanation Required",
        body: "You missed '#{task.title}'. Please provide an explanation.",
        data: {
          type: 'explanation_required',
          task_id: task.id,
          list_id: task.list_id
        },
        badge: calculate_badge_count(client),
        sound: 'default',
        category: 'EXPLANATION_REQUIRED',
        interruption_level: 'time-sensitive'
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'explanation_required',
        message: "Explanation required for missed task"
      )
      
      task_missed(task)
    end
    
    # When client submits explanation
    def explanation_submitted(task)
      task.list.coaches.each do |coach|
        next unless task.visible_to?(coach)
        
        send_apns_notification(
          user: coach,
          title: "📝 Explanation Submitted",
          body: "#{task.list.owner.name} explained missing: #{task.title}",
          data: {
            type: 'explanation_submitted',
            task_id: task.id,
            client_id: task.list.owner.id,
            explanation: task.missed_reason
          },
          category: 'EXPLANATION_SUBMITTED'
        )
        
        log_notification(
          task: task,
          user: coach,
          type: 'explanation_submitted',
          message: "Client submitted explanation"
        )
      end
    end
    
    # ==========================================
    # ESCALATION & REMINDER NOTIFICATIONS
    # ==========================================
    
    # Regular reminder for overdue task
    def send_reminder(task, escalation_level)
      client = task.list.owner
      
      emoji = case escalation_level
              when 'normal' then '⏰'
              when 'warning' then '⚠️'
              when 'critical' then '🚨'
              when 'blocking' then '🛑'
              else '⏰'
              end
      
      # Use critical interruption for blocking
      interruption_level = case escalation_level
                          when 'blocking' then 'critical'
                          when 'critical' then 'time-sensitive'
                          else 'active'
                          end
      
      sound = escalation_level == 'blocking' ? 'critical.caf' : 'default'
      
      send_apns_notification(
        user: client,
        title: "#{emoji} Task Reminder",
        body: task.title,
        data: {
          type: 'reminder',
          task_id: task.id,
          escalation_level: escalation_level,
          minutes_overdue: task.minutes_overdue,
          notification_count: task.escalation.notification_count
        },
        badge: calculate_badge_count(client),
        sound: sound,
        critical: escalation_level == 'blocking',
        interruption_level: interruption_level,
        category: 'TASK_REMINDER'
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'reminder',
        message: "Reminder sent (#{escalation_level})",
        metadata: {
          escalation_level: escalation_level,
          notification_count: task.escalation.notification_count
        }
      )
    end
    
    # When app gets blocked due to critical overdue task
    def app_blocking_started(task)
      client = task.list.owner
      
      send_apns_notification(
        user: client,
        title: "🛑 Critical Task Overdue",
        body: "Complete '#{task.title}' to continue using the app",
        data: {
          type: 'app_blocking',
          task_id: task.id,
          blocking: true
        },
        badge: calculate_badge_count(client),
        sound: 'critical.caf',
        critical: true,
        interruption_level: 'critical',
        category: 'APP_BLOCKING'
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'app_blocking',
        message: "App blocking started for critical task"
      )
    end
    
    # Alert coaches that client has critical overdue task
    def alert_coaches_of_overdue(task)
      task.list.coaches.each do |coach|
        relationship = task.list.owner.relationship_with_coach(coach)
        next unless relationship&.notify_on_missed_deadline?
        next unless task.visible_to?(coach)
        
        send_apns_notification(
          user: coach,
          title: "🚨 Client Task Critical",
          body: "#{task.list.owner.name}'s task '#{task.title}' is #{task.minutes_overdue} min overdue",
          data: {
            type: 'coach_alert_critical',
            task_id: task.id,
            client_id: task.list.owner.id,
            minutes_overdue: task.minutes_overdue,
            escalation_level: task.escalation.escalation_level
          },
          sound: 'default',
          category: 'COACH_ALERT_CRITICAL'
        )
        
        log_notification(
          task: task,
          user: coach,
          type: 'coach_alert_critical',
          message: "Critical overdue alert sent to coach"
        )
      end
    end
    
    # ==========================================
    # LOCATION-BASED NOTIFICATIONS
    # ==========================================
    
    def location_based_reminder(task, event)
      client = task.list.owner
      
      message = case event
                when :arrival
                  "You're at #{task.location_name}! Don't forget: #{task.title}"
                when :departure
                  "Leaving #{task.location_name}. Did you complete: #{task.title}?"
                else
                  task.title
                end
      
      send_push_notification(
        user: client,
        title: "📍 Location Reminder",
        body: message,
        data: {
          type: 'location_reminder',
          task_id: task.id,
          event: event.to_s,
          location_name: task.location_name
        },
        priority: 'high'
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'location_reminder',
        message: "Location-based reminder (#{event})",
        metadata: {
          event: event,
          location: task.location_name
        }
      )
    end
    
    # ==========================================
    # RECURRING TASK NOTIFICATIONS
    # ==========================================
    
    def recurring_task_generated(task)
      client = task.list.owner
      
      # Only notify if due soon (within 24 hours)
      return unless task.due_at.present? && task.due_at < 24.hours.from_now
      
      send_push_notification(
        user: client,
        title: "🔄 Recurring Task",
        body: task.title,
        data: {
          type: 'recurring_task_generated',
          task_id: task.id,
          due_at: task.due_at.iso8601
        }
      )
      
      log_notification(
        task: task,
        user: client,
        type: 'recurring_task_generated',
        message: "New recurring task instance created"
      )
    end
    
    # ==========================================
    # COACHING RELATIONSHIP NOTIFICATIONS
    # ==========================================
    
    def coaching_invitation_sent(relationship)
      recipient = if relationship.invited_by == 'coach'
                    relationship.client
                  else
                    relationship.coach
                  end
      
      sender = if relationship.invited_by == 'coach'
                 relationship.coach
               else
                 relationship.client
               end
      
      role = recipient.coach? ? 'coach' : 'client'
      
      send_push_notification(
        user: recipient,
        title: "👥 Coaching Invitation",
        body: "#{sender.name || sender.email} wants to connect as your #{relationship.invited_by}",
        data: {
          type: 'coaching_invitation',
          relationship_id: relationship.id,
          sender_id: sender.id,
          sender_name: sender.name
        },
        action: 'VIEW_INVITATION'
      )
      
      log_notification(
        task: nil,
        user: recipient,
        type: 'coaching_invitation',
        message: "Coaching invitation sent"
      )
    end
    
    def coaching_invitation_accepted(relationship)
      inviter = if relationship.invited_by == 'coach'
                  relationship.coach
                else
                  relationship.client
                end
      
      accepter = if relationship.invited_by == 'coach'
                   relationship.client
                 else
                   relationship.coach
                 end
      
      send_push_notification(
        user: inviter,
        title: "✅ Invitation Accepted",
        body: "#{accepter.name || accepter.email} accepted your coaching invitation",
        data: {
          type: 'coaching_invitation_accepted',
          relationship_id: relationship.id,
          accepter_id: accepter.id
        }
      )
      
      log_notification(
        task: nil,
        user: inviter,
        type: 'coaching_invitation_accepted',
        message: "Coaching invitation accepted"
      )
    end
    
    def coaching_invitation_declined(relationship)
      inviter = if relationship.invited_by == 'coach'
                  relationship.coach
                else
                  relationship.client
                end
      
      send_push_notification(
        user: inviter,
        title: "❌ Invitation Declined",
        body: "Your coaching invitation was declined",
        data: {
          type: 'coaching_invitation_declined',
          relationship_id: relationship.id
        }
      )
      
      log_notification(
        task: nil,
        user: inviter,
        type: 'coaching_invitation_declined',
        message: "Coaching invitation declined"
      )
    end
    
    # ==========================================
    # LIST SHARING NOTIFICATIONS
    # ==========================================
    
    def list_shared(list, coach)
      send_push_notification(
        user: coach,
        title: "📋 List Shared",
        body: "#{list.owner.name} shared '#{list.name}' with you",
        data: {
          type: 'list_shared',
          list_id: list.id,
          owner_id: list.user_id
        }
      )
      
      log_notification(
        task: nil,
        user: coach,
        type: 'list_shared',
        message: "List shared with coach"
      )
    end
    
    # ==========================================
    # DAILY SUMMARY
    # ==========================================
    
    def send_daily_summary(summary)
      coach = summary.coaching_relationship.coach
      client = summary.coaching_relationship.client
      
      message = build_summary_message(summary)
      
      send_push_notification(
        user: coach,
        title: "📊 Daily Summary - #{client.name || client.email}",
        body: message,
        data: {
          type: 'daily_summary',
          summary_id: summary.id,
          client_id: client.id,
          summary_date: summary.summary_date.iso8601,
          stats: {
            completed: summary.tasks_completed,
            missed: summary.tasks_missed,
            overdue: summary.tasks_overdue,
            completion_rate: summary.completion_rate
          }
        }
      )
      
      log_notification(
        task: nil,
        user: coach,
        type: 'daily_summary',
        message: "Daily summary sent to coach"
      )
    end
    
    # ==========================================
    # TEST/DEBUG NOTIFICATIONS
    # ==========================================
    
    def send_test_notification(user, message = "Test notification")
      # Send to iOS devices
      if user.devices.ios.any? && APNS_CLIENT.present?
        send_apns_notification(
          user: user,
          title: "🧪 Test Notification",
          body: message,
          data: {
            type: 'test',
            timestamp: Time.current.iso8601
          }
        )
      end
      
      # Send to Android devices
      if user.devices.android.any? && defined?(FCM) && FCM.present?
        send_fcm_notification(
          user: user,
          title: "🧪 Test Notification",
          body: message,
          data: {
            type: 'test',
            timestamp: Time.current.iso8601
          }
        )
      end
      
      log_notification(
        task: nil,
        user: user,
        type: 'test',
        message: "Test notification sent"
      )
    end
    
    # ==========================================
    # PRIVATE HELPER METHODS
    # ==========================================
    
    private
    
    def send_apns_notification(user:, title:, body:, data: {}, badge: nil, sound: 'default', critical: false, interruption_level: 'active', category: nil)
      return unless user.devices.ios.any?
      return unless APNS_CLIENT.present?
      
      # Build notification payload
      aps_payload = {
        alert: {
          title: title,
          body: body
        },
        sound: sound,
        badge: badge || calculate_badge_count(user)
      }
      
      # Add critical alert capability for iOS
      if critical
        aps_payload[:sound] = {
          critical: 1,
          name: 'critical.caf',
          volume: 1.0
        }
      end
      
      # Add interruption level for iOS 15+
      if interruption_level != 'active'
        aps_payload[:'interruption-level'] = interruption_level
      end
      
      # Add category for notification actions
      if category
        aps_payload[:category] = category
      end
      
      # Build complete payload
      payload = {
        aps: aps_payload,
        data: data.merge(
          title: title,
          body: body,
          timestamp: Time.current.to_i
        ).compact
      }
      
      # Send to all iOS devices
      user.devices.ios.each do |device|
        begin
          # Use our custom APNs client
          response = APNS_CLIENT.send_notification(
            device.apns_token,
            payload,
            push_type: "alert",
            priority: critical ? 10 : 5,
            expiration: Time.now.to_i + 1.hour.to_i
          )
          
          Rails.logger.info "[NotificationService] APNs sent to user ##{user.id}: #{title}"
          Rails.logger.debug "[NotificationService] APNs Response: #{response.inspect}"
          
          # Check for errors
          if response[:status] == 410 # Unregistered
            Rails.logger.warn "[NotificationService] Unregistered APNs token for user ##{user.id}, removing device..."
            device.destroy
          elsif !response[:ok]
            Rails.logger.error "[NotificationService] APNs error for user ##{user.id}: #{response[:status]} - #{response[:reason]}"
          end
          
        rescue => e
          Rails.logger.error "[NotificationService] APNs error sending to user ##{user.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end
    
    def send_fcm_notification(user:, title:, body:, data: {}, priority: 'normal', critical: false, sound: 'default', action: nil)
      return unless user.fcm_token.present?
      
      # Build notification payload
      notification_payload = {
        title: title,
        body: body,
        sound: sound
      }
      
      # Add critical alert capability for iOS
      if critical
        notification_payload[:sound] = {
          critical: 1,
          name: 'critical.caf',
          volume: 1.0
        }
      end
      
      # Build complete payload
      payload = {
        notification: notification_payload,
        data: data.merge(
          title: title,
          body: body,
          action: action,
          timestamp: Time.current.to_i
        ).compact,
        priority: priority,
        content_available: true,
        mutable_content: true # Allows notification service extension
      }
      
      # Add iOS-specific options
      payload[:apns] = {
        payload: {
          aps: {
            sound: critical ? 'critical.caf' : 'default',
            badge: calculate_badge_count(user)
          }
        },
        headers: {
          'apns-priority': priority == 'high' ? '10' : '5',
          'apns-push-type': 'alert'
        }
      }
      
      if critical
        payload[:apns][:payload][:aps]['sound'] = {
          critical: 1,
          name: 'critical.caf',
          volume: 1.0
        }
      end
      
      begin
        response = FCM_CLIENT.send([user.fcm_token], payload)
        
        Rails.logger.info "[NotificationService] FCM sent to user ##{user.id}: #{title}"
        Rails.logger.debug "[NotificationService] FCM Response: #{response.inspect}"
        
        # Check if token is invalid
        if response[:status_code] == 200
          results = response[:body]['results']
          if results.any? { |r| r['error'] == 'InvalidRegistration' || r['error'] == 'NotRegistered' }
            Rails.logger.warn "[NotificationService] Invalid FCM token for user ##{user.id}, clearing..."
            user.update_column(:fcm_token, nil)
          end
        end
        
        return response
        
      rescue => e
        Rails.logger.error "[NotificationService] FCM error sending to user ##{user.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        return { error: e.message }
      end
    end
    
    def log_notification(task:, user:, type:, message:, metadata: {})
      NotificationLog.create!(
        task: task,
        user: user,
        notification_type: type,
        message: message,
        metadata: metadata.merge(
          sent_at: Time.current.iso8601
        ),
        delivered: true,
        delivered_at: Time.current
      )
    rescue => e
      Rails.logger.error "[NotificationService] Error logging notification: #{e.message}"
    end
    
    def calculate_badge_count(user)
      # Return count of incomplete un-snoozable tasks
      Task.joins(:list)
          .where(lists: { user_id: user.id })
          .where(completed_at: nil)
          .where(can_be_snoozed: false)
          .count
    end
    
    def build_summary_message(summary)
      parts = []
      parts << "✅ #{summary.tasks_completed} completed" if summary.tasks_completed > 0
      parts << "❌ #{summary.tasks_missed} missed" if summary.tasks_missed > 0
      parts << "⏰ #{summary.tasks_overdue} overdue" if summary.tasks_overdue > 0
      parts << "📊 #{summary.completion_rate}% completion rate"
      
      parts.join(", ")
    end
  end
end