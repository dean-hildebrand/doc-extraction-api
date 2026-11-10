require "rails_helper"

RSpec.describe "API key scopes", type: :request do
  def missing_scope_error(scope)
    {
      "error" => {
        "type" => "permission",
        "code" => "missing_scope",
        "message" => "This API key lacks the #{scope} scope required for this request.",
        "param" => nil
      }
    }
  end

  it "rejects creating a document with 403 missing_scope when the key lacks documents:write" do
    api_key = create(:api_key, scopes: ApiKey::SCOPES - [ "documents:write" ])

    post_document(api_key)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq(missing_scope_error("documents:write"))
  end

  it "rejects fetching a document with 403 missing_scope when the key lacks documents:read" do
    api_key = create(:api_key, scopes: [ "documents:write" ])
    post_document(api_key)
    expect(response).to have_http_status(:created)

    get "/v1/documents/#{json['id']}", headers: auth_headers(api_key)

    expect(response).to have_http_status(:forbidden)
    expect(json).to eq(missing_scope_error("documents:read"))
  end
end
