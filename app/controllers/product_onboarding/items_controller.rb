module ProductOnboarding
  class ItemsController < BaseController
    def index
      @status = params[:status].presence_in(Item::STATUSES)
      @items = Store.all
      @items = @items.select { |item| item.status == @status } if @status
    end
  end
end
