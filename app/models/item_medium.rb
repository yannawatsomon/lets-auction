# One file attached to an item (an image, a video or a verification document). The file lives in
# Active Storage, so the storage service (local disk now, an S3-compatible bucket later) is
# chosen by configuration, not by this model. Limits per kind are enforced by Item#sync_media!.
class ItemMedium < ApplicationRecord
  enum :kind, { image: "image", video: "video", document: "document" }, validate: true

  belongs_to :item, inverse_of: :item_media
  has_one_attached :file

  validates :file, presence: true
end
