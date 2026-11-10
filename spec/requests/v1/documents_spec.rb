require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:api_key) { create(:api_key) }
  let(:pdf) { fixture_file_upload("invoice.pdf", "application/pdf") }

  # Known-good values for spec/fixtures/files/invoice.pdf.
  let(:pdf_sha256) { "6350af32579ffbd7b251a6244bf9bd036d303cbc7404ae06d5e02f1b8f5b994f" }
  let(:pdf_byte_size) { 218 }

  describe "POST /v1/documents" do
    it "stores the PDF and returns 201 with the document" do
      post "/v1/documents", params: { file: pdf }, headers: auth_headers(api_key)

      expect(response).to have_http_status(:created)
      expect(json.keys).to contain_exactly("id", "filename", "content_type", "byte_size", "checksum_sha256", "created_at")
      expect(json["id"]).to match(/\Adoc_\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
      expect(json).to include(
        "filename" => "invoice.pdf",
        "content_type" => "application/pdf",
        "byte_size" => pdf_byte_size,
        "checksum_sha256" => pdf_sha256
      )
      expect(Time.iso8601(json["created_at"])).to be_within(1.minute).of(Time.current)
    end

    it "stores the file with Active Storage and records the API key that uploaded it" do
      post "/v1/documents", params: { file: pdf }, headers: auth_headers(api_key)

      # Not visible through the API yet, so checked on the record.
      document = Document.find_by_public_id!(json["id"])
      expect(document.api_key).to eq(api_key)
      expect(document.file.download).to eq(file_fixture("invoice.pdf").binread)
    end

    it "reports an unexpected failure as a 500 internal error in the shared shape" do
      allow_any_instance_of(ActiveStorage::Service::DiskService).to receive(:upload).and_raise(Errno::ENOSPC)

      post "/v1/documents", params: { file: pdf }, headers: auth_headers(api_key)

      expect(response).to have_http_status(:internal_server_error)
      expect(json).to eq(
        "error" => { "type" => "internal", "code" => "internal_error", "message" => "An unexpected error occurred.", "param" => nil }
      )
    end

    it "creates a new document each time the same file is uploaded" do
      ids = Array.new(2) do
        post_document(api_key)
        expect(response).to have_http_status(:created)
        json["id"]
      end

      expect(ids.uniq.size).to eq(2)
      ids.each do |id|
        get "/v1/documents/#{id}", headers: auth_headers(api_key)
        expect(json["checksum_sha256"]).to eq(pdf_sha256)
      end
    end
  end
  describe "GET /v1/documents/:id" do
    let(:not_found_error) do
      { "error" => { "type" => "not_found", "code" => "not_found", "message" => "No such resource.", "param" => nil } }
    end

    def create_document(key = api_key)
      post_document(key)
      json
    end

    it "returns the uploaded document" do
      uploaded = create_document

      get "/v1/documents/#{uploaded['id']}", headers: auth_headers(api_key)

      expect(response).to have_http_status(:ok)
      expect(json).to eq(uploaded)
    end

    it "returns the identical 404 for a wrong prefix, a malformed id and a missing id" do
      uuid = create_document["id"].delete_prefix("doc_")

      [ "ext_#{uuid}", "doc_not-a-uuid", "doc_#{uuid}x", uuid, "doc_#{SecureRandom.uuid}" ].each do |id|
        get "/v1/documents/#{id}", headers: auth_headers(api_key)

        expect(response).to have_http_status(:not_found), "expected 404 for #{id}"
        expect(json).to eq(not_found_error)
      end
    end

    it "returns the identical 404 for another organization's document" do
      other_orgs_document = create_document(create(:api_key))

      get "/v1/documents/#{other_orgs_document['id']}", headers: auth_headers(api_key)

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(not_found_error)
    end
  end
end
