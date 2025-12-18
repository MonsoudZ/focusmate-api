module ListShares
  class UpdatePermissions
    def self.call!(share:, params:)
      share.update_permissions(
        params.transform_values { |v| cast_bool(v) }
      )
      share
    end

    def self.cast_bool(value)
      case value
      when true, false then value
      else
        value.to_s.downcase.in?(%w[true yes on 1])
      end
    end
  end
end
