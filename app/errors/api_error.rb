# An error the API reports to the client in the one shared shape:
# {"error": {"type", "code", "message", "param"}}.
class ApiError < StandardError
  STATUS_BY_TYPE = {
    "authentication" => :unauthorized,
    "permission" => :forbidden,
    "invalid_request" => :unprocessable_content,
    "not_found" => :not_found,
    "conflict" => :conflict,
    "internal" => :internal_server_error
  }.freeze

  attr_reader :type, :code, :param

  def initialize(type:, code:, message:, param: nil)
    raise ArgumentError, "unknown error type #{type}" unless STATUS_BY_TYPE.key?(type)

    super(message)
    @type = type
    @code = code
    @param = param
  end

  def status
    STATUS_BY_TYPE.fetch(type)
  end

  def as_json(*)
    { error: { type: type, code: code, message: message, param: param } }
  end

  def self.missing_api_key
    new(type: "authentication", code: "missing_api_key",
        message: "No API key provided. Send it as Authorization: Bearer <token>.")
  end

  def self.invalid_api_key
    new(type: "authentication", code: "invalid_api_key", message: "The API key provided is invalid.")
  end

  def self.missing_scope(scope)
    new(type: "permission", code: "missing_scope",
        message: "This API key lacks the #{scope} scope required for this request.")
  end

  def self.internal
    new(type: "internal", code: "internal_error", message: "An unexpected error occurred.")
  end

  def self.not_found
    new(type: "not_found", code: "not_found", message: "No such resource.")
  end
end
