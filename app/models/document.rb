class Document < ApplicationRecord
  include PublicId
  public_id_prefix "doc"

  belongs_to :organization
  belongs_to :api_key
  has_one_attached :file

  validates :filename, :content_type, :byte_size, :checksum_sha256, presence: true

  # Builds a document from an uploaded file on behalf of an API key. Call it on
  # an organization's documents so the document belongs to that organization.
  # Every call makes a new document, even for a file uploaded before.
  def self.build_from_upload(upload, api_key:)
    new(
      api_key: api_key,
      filename: upload.original_filename,
      content_type: upload.content_type,
      byte_size: upload.size,
      checksum_sha256: sha256_of(upload),
      file: upload
    )
  end

  def self.sha256_of(upload)
    digest = OpenSSL::Digest::SHA256.new
    io = upload.to_io
    io.rewind
    while (chunk = io.read(64.kilobytes))
      digest.update(chunk)
    end
    io.rewind
    digest.hexdigest
  end
  private_class_method :sha256_of
end
