class LocationCheckWorker
  include Sidekiq::Worker

  sidekiq_options queue: :critical, retry: 1

  def perform(user_id, latitude, longitude, accuracy = nil)
    user = User.find(user_id)

    Rails.logger.info "[LocationCheckWorker] Checking location for user ##{user_id} at (#{latitude}, #{longitude})"

    # Save location record
    user.user_locations.create!(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      recorded_at: Time.current
    )

    # Find location-based tasks for this user
    location_tasks = Task.joins(:list)
                         .where(lists: { user_id: user.id })
                         .where(location_based: true)
                         .where(completed_at: nil)

    Rails.logger.info "[LocationCheckWorker] Found #{location_tasks.count} location-based tasks"

    location_tasks.find_each do |task|
      check_task_location(task, latitude, longitude, user)
    end

  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "[LocationCheckWorker] User ##{user_id} not found"
  rescue => e
    Rails.logger.error "[LocationCheckWorker] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def check_task_location(task, user_lat, user_lng, user)
    # Calculate distance from user to task location
    distance = Geocoder::Calculations.distance_between(
      [ task.location_latitude, task.location_longitude ],
      [ user_lat, user_lng ],
      units: :km
    ) * 1000 # Convert to meters

    is_within = distance <= task.location_radius_meters

    # Get user's previous location to determine if arriving or departing
    previous_location = user.user_locations
                            .where("recorded_at < ?", 5.minutes.ago)
                            .order(recorded_at: :desc)
                            .first

    was_within = if previous_location
                   prev_distance = Geocoder::Calculations.distance_between(
                     [ task.location_latitude, task.location_longitude ],
                     [ previous_location.latitude, previous_location.longitude ],
                     units: :km
                   ) * 1000
                   prev_distance <= task.location_radius_meters
    else
                   false
    end

    # Determine event
    if is_within && !was_within && task.notify_on_arrival?
      # User just arrived at location
      Rails.logger.info "[LocationCheckWorker] User arrived at location for task ##{task.id}"
      NotificationService.location_based_reminder(task, :arrival)

    elsif !is_within && was_within && task.notify_on_departure?
      # User just left location
      Rails.logger.info "[LocationCheckWorker] User departed from location for task ##{task.id}"
      NotificationService.location_based_reminder(task, :departure)
    end

  rescue => e
    Rails.logger.error "[LocationCheckWorker] Error checking task ##{task.id}: #{e.message}"
  end
end
