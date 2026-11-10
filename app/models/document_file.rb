# What the service learns about an uploaded file by reading its bytes. The
# client's filename is kept, but nothing else the client declares is trusted.
class DocumentFile
  MAX_PDF_PAGES = 20

  # The largest file accepted for each supported content type, and the name the
  # type goes by in error messages.
  LIMITS = {
    "application/pdf" => { label: "PDF", max_bytes: 20.megabytes },
    "image/png" => { label: "PNG", max_bytes: 7.megabytes },
    "image/jpeg" => { label: "JPEG", max_bytes: 7.megabytes }
  }.freeze

  attr_reader :upload

  def initialize(upload)
    @upload = upload
  end

  # Raises an ApiError naming the first reason the service cannot process the file.
  def validate!
    limits = LIMITS[content_type] || raise(ApiError.unsupported_file_type)
    raise ApiError.file_too_large(**limits) if byte_size > limits[:max_bytes]
    raise ApiError.too_many_pages(MAX_PDF_PAGES) if page_count > MAX_PDF_PAGES
  end

  def filename
    upload.original_filename
  end

  def byte_size
    upload.size
  end

  def content_type
    @content_type ||= Marcel::MimeType.for(rewound_io)
  end

  # The number of pages in a PDF; an image is always one page. Raises an
  # ApiError for a PDF that cannot be parsed, including an encrypted one.
  def page_count
    @page_count ||= content_type == "application/pdf" ? pdf_page_count : 1
  end

  def checksum_sha256
    @checksum_sha256 ||= begin
      digest = OpenSSL::Digest::SHA256.new
      io = rewound_io
      while (chunk = io.read(64.kilobytes))
        digest.update(chunk)
      end
      digest.hexdigest
    end
  end

  # Attachable for Active Storage, carrying the detected content type rather
  # than the one the client declared.
  def attachable
    { io: rewound_io, filename: filename, content_type: content_type, identify: false }
  end

  private

  def pdf_page_count
    PDF::Reader.new(rewound_io).page_count
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
    raise ApiError.unreadable_file
  end

  def rewound_io
    upload.to_io.tap(&:rewind)
  end
end
