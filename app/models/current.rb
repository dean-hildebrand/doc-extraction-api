class Current < ActiveSupport::CurrentAttributes
  attribute :api_key

  def organization
    api_key&.organization
  end
end
