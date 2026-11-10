FactoryBot.define do
  # The built key carries its plaintext token in #token, as it does when issued.
  factory :api_key do
    organization
    name { "Test key" }
    scopes { ApiKey::SCOPES }

    initialize_with { ApiKey.generate(organization:, name:, scopes:) }

    trait :revoked do
      revoked_at { 1.day.ago }
    end
  end
end
