# A credential belonging to one organization. The plaintext token,
# dx_live_<prefix>_<secret>, exists only in memory when the key is generated;
# the database keeps the prefix for lookup and a SHA-256 digest of the token.
class ApiKey < ApplicationRecord
  SCOPES = %w[
    documents:read
    documents:write
    extractions:read
    extractions:write
    webhooks:manage
    keys:manage
  ].freeze

  TOKEN_PATTERN = /\Adx_live_(?<prefix>[A-Za-z0-9]{12})_(?<secret>[A-Za-z0-9]{32})\z/
  LAST_USED_RESOLUTION = 1.minute
  UNKNOWN_KEY_DIGEST = "0" * 64

  belongs_to :organization

  validates :name, :prefix, :token_digest, presence: true
  validate :scopes_are_known

  # The plaintext token; only set on a key built by .generate.
  attr_reader :token

  def self.generate(organization:, name:, scopes: SCOPES)
    prefix = SecureRandom.alphanumeric(12)
    token = "dx_live_#{prefix}_#{SecureRandom.alphanumeric(32)}"
    new(organization:, name:, scopes:, prefix:, token_digest: digest(token)).tap do |key|
      key.instance_variable_set(:@token, token)
    end
  end

  # Creates the organization if it is missing and issues it a new key with every
  # scope. The returned key carries its plaintext token in #token.
  def self.issue!(organization_slug:, name:)
    transaction do
      organization = Organization.create_with(name: organization_slug.titleize)
                                 .find_or_create_by!(slug: organization_slug)
      generate(organization:, name:).tap(&:save!)
    end
  end

  # Returns the active key the token belongs to, or nil for any token that is
  # malformed, unknown, revoked or has the wrong secret.
  def self.authenticate(token)
    match = TOKEN_PATTERN.match(token.to_s)
    return nil unless match

    key = find_by(prefix: match[:prefix])
    # Compare against a dummy digest for unknown prefixes so the response time
    # does not reveal which prefixes exist.
    digest_matches = ActiveSupport::SecurityUtils.secure_compare(key&.token_digest || UNKNOWN_KEY_DIGEST, digest(token))
    return nil unless key && digest_matches && !key.revoked?

    key
  end

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def revoked?
    revoked_at.present?
  end

  # Records that the key was used, writing at most once per LAST_USED_RESOLUTION
  # so authentication does not write to the database on every request.
  def record_use!
    now = Time.current
    return if last_used_at && last_used_at > now - LAST_USED_RESOLUTION

    update_column(:last_used_at, now)
  end

  def scope?(scope)
    scopes.include?(scope)
  end

  private

  def scopes_are_known
    unknown = scopes - SCOPES
    errors.add(:scopes, "contains unknown scopes: #{unknown.join(', ')}") if unknown.any?
  end
end
