# Creates a development organization and API key so the API can be called
# locally straight away. Idempotent: the key is issued only once, because its
# token cannot be shown again. Issue another with the api_keys:create task.
unless Rails.env.production?
  if ApiKey.joins(:organization).exists?(name: "Development key", organizations: { slug: "development" })
    puts "Development API key already exists. Issue a new one with: " \
         "bin/rails \"api_keys:create[development,Another key]\""
  else
    api_key = ApiKey.issue!(organization_slug: "development", name: "Development key")
    puts "Development API key (shown once): #{api_key.token}"
  end
end
