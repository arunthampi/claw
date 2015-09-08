require "claw/version"

require "claw/html_extractor"
require "claw/text_extractor"

class Claw
  class InvalidMimeTypeError < RuntimeError; end

  def self.extract_from(message, mime_type)
    if mime_type == 'text/html'
      HtmlExtractor.extract_from_html(message)
    elsif mime_type == 'text/plain'
      TextExtractor.extract_from_text(message)
    else
      raise InvalidMimeTypeError, "Invalid MIME type #{mime_type}"
    end
  end
end
