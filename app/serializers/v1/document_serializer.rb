module V1
  module DocumentSerializer
    def self.call(document)
      {
        id: document.public_id,
        filename: document.filename,
        content_type: document.content_type,
        byte_size: document.byte_size,
        checksum_sha256: document.checksum_sha256,
        page_count: document.page_count,
        created_at: document.created_at.iso8601
      }
    end
  end
end
