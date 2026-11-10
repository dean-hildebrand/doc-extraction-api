require "rails_helper"

RSpec.describe "API authentication", type: :request do
  let(:path) { "/v1/documents/doc_#{SecureRandom.uuid}" }

  it "returns 401 missing_api_key when the Authorization header is absent" do
    get path

    expect(response).to have_http_status(:unauthorized)
    expect(json).to eq(
      "error" => {
        "type" => "authentication",
        "code" => "missing_api_key",
        "message" => "No API key provided. Send it as Authorization: Bearer <token>.",
        "param" => nil
      }
    )
  end

  describe "keys that do not authenticate" do
    let(:invalid_api_key_error) do
      {
        "error" => {
          "type" => "authentication",
          "code" => "invalid_api_key",
          "message" => "The API key provided is invalid.",
          "param" => nil
        }
      }
    end

    {
      "an unknown key" => -> { "dx_live_#{'a' * 12}_#{'b' * 32}" },
      "a malformed key" => -> { "not-a-key" },
      "a key with a known prefix but the wrong secret" => -> { create(:api_key).token.sub(/_[^_]+\z/, "_#{'c' * 32}") },
      "a revoked key" => -> { create(:api_key, :revoked).token },
      "a non-Bearer scheme" => -> { nil }
    }.each do |description, token_builder|
      it "returns the identical 401 invalid_api_key for #{description}" do
        token = instance_exec(&token_builder)
        headers = token ? auth_headers(token) : { "Authorization" => "Basic dXNlcjpwYXNz" }

        get path, headers: headers

        expect(response).to have_http_status(:unauthorized)
        expect(json).to eq(invalid_api_key_error)
      end
    end
  end
  describe "last_used_at" do
    let(:api_key) { create(:api_key) }
    let(:start) { Time.zone.parse("2026-11-10 12:00:00") }

    # Not exposed through the API until the /api_keys endpoints, so read from the record.
    def last_used_at = api_key.reload.last_used_at

    it "is set on the first authenticated request" do
      travel_to(start) { get path, headers: auth_headers(api_key) }

      expect(last_used_at).to eq(start)
    end

    it "is not rewritten within a minute of the last write" do
      travel_to(start) { get path, headers: auth_headers(api_key) }
      travel_to(start + 59.seconds) { get path, headers: auth_headers(api_key) }

      expect(last_used_at).to eq(start)
    end

    it "is rewritten once it is more than a minute old" do
      travel_to(start) { get path, headers: auth_headers(api_key) }
      travel_to(start + 61.seconds) { get path, headers: auth_headers(api_key) }

      expect(last_used_at).to eq(start + 61.seconds)
    end
  end
end
