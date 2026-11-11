module ProductOnboarding
  class ItemsController < BaseController
    before_action(only: %i[new create]) { head :not_found unless current_user&.seller? }

    rescue_from(NotFound) { head :not_found }

    def index
      @status = params[:status].presence_in(Item::STATUSES)
      @items = Store.all
      @items = @items.select { |item| item.status == @status } if @status
    end

    def new
      @values = {}
      @uploads = []
    end

    # The wizard uploads files first (UploadsController) and submits only their keys, in order.
    def create
      keys = Array(params[:upload_keys]).map(&:to_s)
      @uploads = UploadStore.ready!(keys, seller_id: current_user.id)
      item = Store.create!(item_attributes, media: @uploads.map { |upload| media_entry(upload) })
      UploadStore.attach!(keys, seller_id: current_user.id)
      redirect_to product_onboarding_root_path, notice: "ส่งสินค้า “#{item.title}” แล้ว รอแอดมินตรวจสอบ"
    rescue ActiveModel::ValidationError => error
      render_form(error.model.errors.map { |e| [ e.attribute, e.message ] })
    rescue UploadPolicy::Rejected => error
      @uploads = []
      render_form([ [ :base, error.message ] ])
    end

    private

    def form_values = params.fetch(:item, {}).permit(:title, :category, :description, :price, :contact_channel)

    # Sellers type baht; money is stored as satang. Text that is not an amount stays as typed so
    # the item's own validation rejects it.
    def item_attributes
      values = form_values
      { seller_id: current_user.id, title: values[:title], category: values[:category],
        description: values[:description], contact_channel: values[:contact_channel].presence,
        min_price_cents: Baht.parse(values[:price]) || values[:price] }
    end

    def media_entry(upload)
      { kind: upload.kind, key: upload.key, filename: upload.filename, content_type: upload.content_type,
        byte_size: upload.byte_size }
    end

    def render_form(errors)
      @errors = errors
      @values = form_values
      render :new, status: :unprocessable_content
    end
  end
end
