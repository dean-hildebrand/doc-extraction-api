module V1
  class BaseController < ApplicationController
    # Declared first so the specific handlers below take precedence.
    rescue_from StandardError do |exception|
      Rails.error.report(exception, handled: true)
      render_error ApiError.internal
    end

    rescue_from ActiveRecord::RecordNotFound do
      render_error ApiError.not_found
    end

    rescue_from ActionController::ParameterMissing do |exception|
      render_error ApiError.parameter_missing(exception.param)
    end

    rescue_from ApiError do |error|
      render_error error
    end

    before_action :authenticate!

    # Declares the scope an action needs; a key without it gets 403 missing_scope.
    def self.require_scope(scope, **options)
      raise ArgumentError, "unknown scope #{scope}" unless ApiKey::SCOPES.include?(scope)

      before_action(**options) do
        raise ApiError.missing_scope(scope) unless Current.api_key.scope?(scope)
      end
    end

    private

    def authenticate!
      raise ApiError.missing_api_key if request.authorization.blank?

      Current.api_key = ApiKey.authenticate(bearer_token) || raise(ApiError.invalid_api_key)
      Current.api_key.record_use!
    end

    def bearer_token
      scheme, token = request.authorization.split(" ", 2)
      token&.strip if scheme == "Bearer"
    end

    def render_error(error)
      render json: error, status: error.status
    end
  end
end
