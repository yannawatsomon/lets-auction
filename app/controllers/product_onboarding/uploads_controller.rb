module ProductOnboarding
  # Stand-in for the storage service's direct upload: `create` issues a target, `update` receives
  # the file. Sellers only; everyone else gets 404 so the endpoint is not discoverable.
  class UploadsController < BaseController
    before_action { head :not_found unless current_user&.seller? }

    rescue_from(UploadPolicy::Rejected) { |error| render json: { error: error.message }, status: :unprocessable_content }
    rescue_from(NotFound) { head :not_found }

    def create
      upload = UploadStore.issue!(seller_id: current_user.id, kind: params[:kind], filename: params[:filename],
                                  content_type: params[:content_type], size: declared_size)
      render status: :created, json: {
        key: upload.key,
        direct_upload: { url: product_onboarding_upload_path(upload.key), method: "PUT",
                         headers: { "Content-Type" => upload.content_type } }
      }
    end

    def update
      UploadStore.receive!(params[:key], seller_id: current_user.id, content_type: request.media_type,
                           byte_size: request.content_length)
      head :no_content
    end

    private

    # JSON sends a number, a form sends a string of digits; anything else stays invalid.
    def declared_size
      size = params[:size]
      size.is_a?(String) ? Integer(size, 10, exception: false) : size
    end
  end
end
