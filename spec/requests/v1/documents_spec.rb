require "rails_helper"

RSpec.describe "Documents", type: :request do
  let(:api_key) { create(:api_key) }
  let(:pdf) { fixture_file_upload("invoice.pdf", "application/pdf") }

  # Known-good values for spec/fixtures/files/invoice.pdf.
  let(:pdf_sha256) { "0d509281e91d6d7cbfbcb4d16f5a205578e65765a11c59187b07b585d555b00d" }
  let(:pdf_byte_size) { 329 }

  # A fixture padded with zero bytes to the given size, built at run time so
  # the repo needs no multi-megabyte fixtures. Detection reads the leading
  # bytes, so the padded file keeps the fixture's type.
  def padded_upload(fixture, byte_size, content_type)
    file = Tempfile.new([ "padded", File.extname(fixture) ], binmode: true)
    file.write(file_fixture(fixture).binread)
    file.write("\0" * (byte_size - file.size))
    file.flush
    Rack::Test::UploadedFile.new(file.path, content_type, true)
  end

  def file_too_large_error(message)
    { "error" => { "type" => "invalid_request", "code" => "file_too_large", "message" => message, "param" => "file" } }
  end

  describe "POST /v1/documents" do
    it "stores the PDF and returns 201 with the document" do
      post "/v1/documents", params: { file: pdf }, headers: auth_headers(api_key)

      expect(response).to have_http_status(:created)
      expect(json.keys).to contain_exactly("id", "filename", "content_type", "byte_size", "checksum_sha256", "page_count", "created_at")
      expect(json["id"]).to match(/\Adoc_\h{8}-\h{4}-7\h{3}-\h{4}-\h{12}\z/)
      expect(json).to include(
        "filename" => "invoice.pdf",
        "content_type" => "application/pdf",
        "byte_size" => pdf_byte_size,
        "checksum_sha256" => pdf_sha256,
        "page_count" => 1
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

    it "detects the content type from the file's bytes, not the client's header" do
      post_document(api_key, fixture: "receipt.png", content_type: "application/pdf")

      expect(response).to have_http_status(:created)
      expect(json["content_type"]).to eq("image/png")
    end

    it "reports a PDF's page count, and 1 for an image" do
      { [ "three_pages.pdf", "application/pdf" ] => 3,
        [ "receipt.png", "image/png" ] => 1,
        [ "receipt.jpg", "image/jpeg" ] => 1 }.each do |(fixture, content_type), page_count|
        post_document(api_key, fixture: fixture, content_type: content_type)

        expect(response).to have_http_status(:created), "expected 201 for #{fixture}"
        expect(json["page_count"]).to eq(page_count), "expected #{page_count} pages for #{fixture}"
      end
    end

    it "rejects a PDF of more than 20 pages" do
      post_document(api_key, fixture: "twenty_one_pages.pdf")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(
        "error" => {
          "type" => "invalid_request", "code" => "too_many_pages",
          "message" => "PDF files must have 20 pages or fewer.", "param" => "file"
        }
      )
    end

    it "rejects a PDF that cannot be read" do
      post_document(api_key, fixture: "broken.pdf")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(
        "error" => {
          "type" => "invalid_request", "code" => "unreadable_file",
          "message" => "The file could not be read as a PDF.", "param" => "file"
        }
      )
    end

    it "rejects a request with no file, naming the missing field" do
      [ {}, { file: "" }, { file: "invoice.pdf" } ].each do |params|
        post "/v1/documents", params: params, headers: auth_headers(api_key)

        expect(response).to have_http_status(:unprocessable_content), "expected 422 for #{params}"
        expect(json).to eq(
          "error" => {
            "type" => "invalid_request", "code" => "parameter_missing",
            "message" => "The file parameter is required.", "param" => "file"
          }
        )
      end
    end

    it "rejects a file that is not a PDF, PNG or JPEG, whatever the client calls it" do
      expect do
        post_document(api_key, fixture: "notes.txt", content_type: "application/pdf")
      end.not_to change(Document, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(
        "error" => {
          "type" => "invalid_request", "code" => "unsupported_file_type",
          "message" => "The file must be a PDF, PNG or JPEG.", "param" => "file"
        }
      )
    end
  end

  describe "POST /v1/documents size limits" do
    it "rejects a PDF over 20 MB, stating the PDF limit" do
      post "/v1/documents", params: { file: padded_upload("invoice.pdf", 20.megabytes + 1, "application/pdf") },
                            headers: auth_headers(api_key)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(file_too_large_error("PDF files must be 20 MB or smaller."))
    end

    it "rejects a PNG or JPEG over 7 MB, stating the image limit" do
      { "receipt.png" => "PNG", "receipt.jpg" => "JPEG" }.each do |fixture, label|
        post "/v1/documents", params: { file: padded_upload(fixture, 7.megabytes + 1, "image/png") },
                              headers: auth_headers(api_key)

        expect(response).to have_http_status(:unprocessable_content), "expected 422 for #{fixture}"
        expect(json).to eq(file_too_large_error("#{label} files must be 7 MB or smaller."))
      end
    end

    it "accepts an image of exactly 7 MB" do
      post "/v1/documents", params: { file: padded_upload("receipt.png", 7.megabytes, "image/png") },
                            headers: auth_headers(api_key)

      expect(response).to have_http_status(:created)
      expect(json["byte_size"]).to eq(7.megabytes)
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
