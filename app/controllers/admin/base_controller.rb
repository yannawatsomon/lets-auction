module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin

    rescue_from Auction::Error do |e|
      redirect_back_or_to admin_auctions_path, alert: e.message
    end

    private

    # 404 rather than 403 so non-admins can't tell admin pages exist.
    def require_admin
      head :not_found unless current_user&.admin?
    end
  end
end
