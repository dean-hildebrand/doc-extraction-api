class Document < ApplicationRecord
  include PublicId
  public_id_prefix "doc"

  belongs_to :organization
  belongs_to :api_key
  has_one_attached :file

  validates :filename, :content_type, :byte_size, :checksum_sha256, presence: true

  # Builds a document from an uploaded file on behalf of an API key. Call it on
  # an organization's documents so the document belongs to that organization.
  # Every call makes a new document, even for a file uploaded before. Raises an
  # ApiError for a file the service cannot process.
  def self.build_from_upload(upload, api_key:)
    file = DocumentFile.new(upload).tap(&:validate!)
    new(
      api_key: api_key,
      filename: file.filename,
      content_type: file.content_type,
      byte_size: file.byte_size,
      checksum_sha256: file.checksum_sha256,
      page_count: file.page_count,
      file: file.attachable
    )
  end
end
