# Shows a record's UUIDv7 primary key with a type prefix (ADR 0001), and finds
# records by that public id. A wrong prefix or malformed id is treated exactly
# like a missing record.
module PublicId
  extend ActiveSupport::Concern

  UUID_PATTERN = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

  class_methods do
    def public_id_prefix(prefix = nil)
      @public_id_prefix = prefix if prefix
      @public_id_prefix
    end

    # Works on relations too, so it stays scoped:
    # Current.organization.documents.find_by_public_id!(id)
    def find_by_public_id!(public_id)
      prefix, uuid = public_id.to_s.split("_", 2)
      raise ActiveRecord::RecordNotFound unless prefix == public_id_prefix && UUID_PATTERN.match?(uuid.to_s)

      find(uuid)
    end
  end

  def public_id
    "#{self.class.public_id_prefix}_#{id}"
  end
end
