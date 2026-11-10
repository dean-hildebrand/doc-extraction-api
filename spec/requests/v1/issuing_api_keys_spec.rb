require "rails_helper"
require "rake"

RSpec.describe "Issuing API keys from the command line", type: :request do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def issue(slug, name)
    task = Rake::Task["api_keys:create"]
    task.reenable
    capture_stdout { task.invoke(slug, name) }
  end

  def token_from(output)
    output[/dx_live_[A-Za-z0-9]{12}_[A-Za-z0-9]{32}/]
  end

  it "creates the organization, prints a working token once and stores only its digest" do
    output = issue("acme", "Acme production")
    token = token_from(output)

    expect(token).to be_present
    expect(output.scan(token).size).to eq(1)

    post_document(token)
    expect(response).to have_http_status(:created)
    get "/v1/documents/#{json['id']}", headers: auth_headers(token)
    expect(response).to have_http_status(:ok)

    api_key = Organization.find_by!(slug: "acme").api_keys.sole
    uuidv7 = /\A\h{8}-\h{4}-7\h{3}-[89ab]\h{3}-\h{12}\z/
    expect([ api_key.id, api_key.organization_id ]).to all(match(uuidv7))
    expect(api_key.name).to eq("Acme production")
    expect(api_key.scopes).to match_array(%w[
      documents:read documents:write extractions:read extractions:write webhooks:manage keys:manage
    ])
    expect(api_key.token_digest).to eq(Digest::SHA256.hexdigest(token))
    secret = token.split("_").last
    expect(api_key.attributes.values.map(&:to_s)).to all(satisfy { |value| !value.include?(secret) })
  end

  it "adds a key to an organization that already exists" do
    token_from(issue("acme", "First"))
    second = token_from(issue("acme", "Second"))

    expect(Organization.where(slug: "acme").count).to eq(1)
    expect(Organization.find_by!(slug: "acme").api_keys.pluck(:name)).to contain_exactly("First", "Second")

    get "/v1/documents/doc_#{SecureRandom.uuid}", headers: auth_headers(second)
    expect(response).to have_http_status(:not_found)
  end

  it "seeds a development organization with a working key" do
    token = token_from(capture_stdout { Rails.application.load_seed })

    expect(Organization.find_by(slug: "development")).to be_present
    get "/v1/documents/doc_#{SecureRandom.uuid}", headers: auth_headers(token)
    expect(response).to have_http_status(:not_found)
  end
end
