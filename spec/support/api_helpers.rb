module ApiHelpers
  def auth_headers(api_key_or_token)
    token = api_key_or_token.respond_to?(:token) ? api_key_or_token.token : api_key_or_token
    { "Authorization" => "Bearer #{token}" }
  end

  def post_document(api_key_or_token, fixture: "invoice.pdf", content_type: "application/pdf")
    post "/v1/documents", params: { file: fixture_file_upload(fixture, content_type) },
                          headers: auth_headers(api_key_or_token)
  end

  def json
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
