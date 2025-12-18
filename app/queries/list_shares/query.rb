# frozen_string_literal: true

module ListShares
  class Query
    def self.call!(list:, params:)
      scope = list.list_shares.includes(:user)

      scope = scope.where(status: params[:status]) if %w[pending accepted declined].include?(params[:status])
      scope = scope.where(role: params[:role]) if %w[viewer editor admin].include?(params[:role])

      if params[:search].present?
        term = "%#{params[:search].to_s.strip}%"
        scope = scope.where("email ILIKE ?", term)
      end

      scope.order(created_at: :desc)
    end
  end
end
