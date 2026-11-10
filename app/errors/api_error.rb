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

  def self.parameter_missing(param)
    new(type: "invalid_request", code: "parameter_missing",
        message: "The #{param} parameter is required.", param: param.to_s)
  end

  def self.unsupported_file_type
    new(type: "invalid_request", code: "unsupported_file_type",
        message: "The file must be a PDF, PNG or JPEG.", param: "file")
  end

  def self.file_too_large(label, max_size)
    new(type: "invalid_request", code: "file_too_large",
        message: "#{label} files must be #{max_size} or smaller.", param: "file")
  end

  def self.too_many_pages(label, max_pages)
    new(type: "invalid_request", code: "too_many_pages",
        message: "#{label} files must have #{max_pages} pages or fewer.", param: "file")
  end

  def self.unreadable_file(label)
    new(type: "invalid_request", code: "unreadable_file",
        message: "The file could not be read as a #{label}.", param: "file")
  end

  def self.not_found
    new(type: "not_found", code: "not_found", message: "No such resource.")
  end
end
