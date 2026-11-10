require "vips"

# What the service learns about an uploaded file by reading its bytes. The
# client's filename is kept, but nothing else the client declares is trusted.
class DocumentFile
  # Everything about one supported content type: the name it goes by in
  # error messages, the largest file and the most pages accepted, and whether
  # it is read as a PDF or as an image.
  Format = Data.define(:label, :kind, :max_bytes, :max_pages) do
    def max_size
      "#{max_bytes / 1.megabyte} MB"
    end
  end

  FORMATS = {
    "application/pdf" => Format.new(label: "PDF", kind: :pdf, max_bytes: 20.megabytes, max_pages: 20),
    "image/png" => Format.new(label: "PNG", kind: :image, max_bytes: 7.megabytes, max_pages: 1),
    "image/jpeg" => Format.new(label: "JPEG", kind: :image, max_bytes: 7.megabytes, max_pages: 1)
  }.freeze

  def initialize(upload)
    @upload = upload
  end

  # Raises an ApiError naming the first reason the service cannot process the file.
  def validate!
    raise ApiError.unsupported_file_type unless file_format
    raise ApiError.file_too_large(file_format.label, file_format.max_size) if byte_size > file_format.max_bytes
    raise ApiError.too_many_pages(file_format.label, file_format.max_pages) if page_count > file_format.max_pages
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
  # ApiError for a file that cannot be read: a PDF that cannot be parsed,
  # including an encrypted one, or an image that does not decode.
  def page_count
    @page_count ||= file_format.kind == :pdf ? pdf_page_count : decode_image!
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

  attr_reader :upload

  def file_format
    FORMATS[content_type]
  end

  def pdf_page_count
    PDF::Reader.new(rewound_io).page_count
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
    raise ApiError.unreadable_file(file_format.label)
  end

  # Decodes every pixel, so a truncated or corrupt image is rejected before
  # extraction. An image that decodes is one page.
  def decode_image!
    Vips::Image.new_from_buffer(rewound_io.read, "", access: :sequential, fail_on: :truncated).avg
    1
  rescue Vips::Error
    raise ApiError.unreadable_file(file_format.label)
  end

  def rewound_io
    upload.to_io.tap(&:rewind)
  end
end
