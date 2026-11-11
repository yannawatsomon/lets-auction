module ProductOnboarding
  class ItemsController < BaseController
    SELLER_ACTIONS = %i[new create edit update destroy resubmit].freeze

    before_action(only: SELLER_ACTIONS) { head :not_found unless current_user&.seller? }
    before_action :set_item, only: %i[edit update destroy resubmit]

    rescue_from(NotFound) { head :not_found }
    rescue_from(Item::NotEditable) { redirect_to product_onboarding_root_path, alert: "แก้ไขได้เฉพาะสินค้าที่รอตรวจสอบหรือถูกขอหลักฐานเพิ่ม" }
    rescue_from(Item::InvalidTransition) { redirect_to product_onboarding_root_path, alert: "ทำรายการนี้ไม่ได้ในสถานะปัจจุบันของสินค้า" }

    # A seller sees their own products; anyone else (mock overview) sees all of them.
    def index
      @status = params[:status].presence_in(Item::STATUSES)
      @items = current_user&.seller? ? Store.for_seller(current_user.id) : Store.all
      @items = @items.select { |item| item.status == @status } if @status
    end

    def new
      @values = {}
      @files = []
    end

    def edit
      raise Item::NotEditable unless @item.editable?

      @values = { title: @item.title, category: @item.category, description: @item.description,
                  price: Baht.format(@item.min_price_cents), contact_channel: @item.contact_channel }
      @files = file_rows(@item.media.map(&:key))
      render :new
    end

    # The wizard uploads files first (UploadsController) and submits only their keys, in order.
    def create
      keys = submitted_keys
      uploads = UploadStore.ready!(keys, seller_id: current_user.id)
      item = Store.create!(item_attributes, media: uploads.map { |upload| media_entry(upload) })
      UploadStore.attach!(keys, seller_id: current_user.id)
      redirect_to product_onboarding_root_path, notice: "ส่งสินค้า “#{item.title}” แล้ว รอแอดมินตรวจสอบ"
    rescue ActiveModel::ValidationError => error
      @files = file_rows(keys)
      render_form(error.model.errors.map { |e| [ e.attribute, e.message ] })
    rescue UploadPolicy::Rejected => error
      @files = []
      render_form([ [ :base, error.message ] ])
    end

    # Files already on the product keep their key; new keys must be finished uploads of this seller.
    def update
      keys = submitted_keys
      current = @item.media.index_by(&:key)
      new_keys = keys - current.keys
      uploads = UploadStore.ready!(new_keys, seller_id: current_user.id).index_by(&:key)
      @item.revise!(item_attributes.except(:seller_id),
                    media: keys.map { |key| current[key] || media_entry(uploads.fetch(key)) })
      UploadStore.attach!(new_keys, seller_id: current_user.id)
      redirect_to product_onboarding_root_path, notice: "บันทึกการแก้ไข “#{@item.title}” แล้ว"
    rescue ActiveModel::ValidationError => error
      @files = file_rows(keys)
      render_form(error.model.errors.map { |e| [ e.attribute, e.message ] })
    rescue UploadPolicy::Rejected => error
      @files = file_rows(@item.media.map(&:key))
      render_form([ [ :base, error.message ] ])
    end

    # Withdraw: allowed until the product is in an auction.
    def destroy
      @item.transition!(:withdrawn)
      redirect_to product_onboarding_root_path, notice: "ถอนสินค้า “#{@item.title}” แล้ว"
    end

    # After the seller fixes what the admin asked for, the product goes back for review.
    def resubmit
      @item.transition!(:pending_review)
      redirect_to product_onboarding_root_path, notice: "ส่ง “#{@item.title}” ให้ตรวจสอบอีกครั้งแล้ว"
    end

    private

    # Another seller's product looks the same as one that does not exist.
    def set_item
      @item = Store.find(params[:id])
      head :not_found unless @item && @item.seller_id == current_user.id
    end

    # Blank entries (a form posting `upload_keys=` with no files) count as no files.
    def submitted_keys = Array(params[:upload_keys]).map(&:to_s).compact_blank

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

    # What the wizard shows as already uploaded: the product's own files or this seller's uploads.
    def file_rows(keys)
      keys.filter_map do |key|
        file = @item&.media&.find { |media| media.key == key }
        upload = UploadStore.find(key)
        file ||= upload if upload&.seller_id == current_user.id
        { key: key, kind: file.kind, filename: file.filename } if file
      end
    end

    def render_form(errors)
      @errors = errors
      @values = form_values
      render :new, status: :unprocessable_content
    end
  end
end
