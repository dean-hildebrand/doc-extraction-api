namespace :api_keys do
  desc "Issue an API key with every scope, creating the organization if missing. " \
       "Usage: bin/rails \"api_keys:create[acme,Production key]\""
  task :create, %i[organization_slug name] => :environment do |_task, args|
    abort "Usage: bin/rails \"api_keys:create[organization_slug,key name]\"" if args.organization_slug.blank? || args.name.blank?

    api_key = ApiKey.issue!(organization_slug: args.organization_slug, name: args.name)

    puts "Issued API key \"#{api_key.name}\" for organization #{api_key.organization.slug}."
    puts "Scopes: #{api_key.scopes.join(', ')}"
    puts "Store this token now; it will not be shown again:"
    puts api_key.token
  end
end
