require "claw/extractor"

class TextExtractor < Extractor
  def self.extract_from_text(message)
    delimiter = get_delimiter(message)
    message = preprocess(message, delimiter)
    lines = message.split("\n")

    markers = mark_message_lines(lines)

    lines = process_marked_lines(lines, markers)

    message = lines.join(delimiter)
    postprocess(message)
  end
end
