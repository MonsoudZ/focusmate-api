class SavedLocationSerializer
  attr_reader :location

  def initialize(location)
    @location = location
  end

  def as_json
    {
      id: location.id,
      name: location.name,
      latitude: location.latitude.to_f,
      longitude: location.longitude.to_f,
      radius_meters: location.radius_meters,
      address: location.address,
      created_at: location.created_at.iso8601,
      updated_at: location.updated_at.iso8601
    }
  end
end
