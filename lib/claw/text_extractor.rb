module TextExtractor
  RE_DELIMITER  = /\r?\n/
  RE_LINK       = /<(https?:\/\/[^>]+)>/im

  BEGINNING_OF_LINE = [
    # English
    'On',
    # French
    'Le',
    # Polish
    'W dniu',
    # Dutch
    'Op'
  ].map { |x| "\\b#{x}\\b" }.join('|')
  DATE_AND_SENDER_SEPARATOR = [
    # most languages separate date and sender address by comma
    ',',
    # polish date and sender address separator
    'użytkownik'
  ].join('|')
  END_OF_LINE = [
    # English
    'wrote', 'sent',
    # French
    'a écrit',
    # Polish
    'napisał',
    # Dutch
    'schreef','verzond','geschreven'
  ].map { |x| "\\b#{x}\\b" }.join('|')
  ORIGINAL_MESSAGE = [
    # English
    'Original Message', 'Reply Message',
    # German
    'Ursprüngliche Nachricht', 'Antwort Nachricht',
    # Danish
    'Oprindelig meddelelse',
  ].join('|')
  ON_DATE_WROTE_SMB_ENDING_OF_LINE = [
    # Dutch
    'schreef','verzond','geschreven'
  ].join('|')
  FROM_DATE_PATTERN = [
    # "From" in different languages.
    'From', 'Van', 'De', 'Von', 'Fra',
    # "Date" in different languages.
    'Date', 'Datum', 'Envoyé'
  ].join('|')

  RE_ON_DATE_SMB_WROTE = "(-*[ ]?(#{BEGINNING_OF_LINE})[ ].*(#{DATE_AND_SENDER_SEPARATOR})(.*\\n){0,2}.*(#{END_OF_LINE}):?-*)"
  RE_ORIGINAL_MESSAGE = "[\\s]*[-]+[ ]*(#{ORIGINAL_MESSAGE})[ ]*[-]+"
  # Special case for languages where text is translated like this: 'on {date} wrote {somebody}:'
  RE_ON_DATE_WROTE_SMB = "-*[ ]?(Op)[ ].*(.*\\n){0,2}.*(#{ON_DATE_WROTE_SMB_ENDING_OF_LINE})[ ].*:"
  RE_FROM_COLON_OR_DATE_COLON = "(_+\\r?\\n)?[\\s]*(:?[*]?#{FROM_DATE_PATTERN})[\\s]?:[*]? .*"

  RE_FWD_PATTERN = "[-]+[ ]*Forwarded message[ ]*[-]+$"

  RE_PARENTHESIS_LINK = "\\(https?:\/\/"

  RE_QUOTATION = "((?:s|(?:me*){2,}).*me*)[te]*$"
  RE_EMPTY_QUOTATION = "((?:s|(?:me*){2,}))e*"
  RE_NORMALIZED_LINK = /@@(https?:\/\/[^>@]*)@@/

  QUOT_PATTERN = /\A>+ ?/

  SPLITTER_PATTERNS = [
    RE_ORIGINAL_MESSAGE,
    # <date> <person>
    "(\\d+/\\d+/\\d+|\\d+\\.\\d+\\.\\d+).*@",
    RE_ON_DATE_SMB_WROTE,
    RE_ON_DATE_WROTE_SMB,
    RE_FROM_COLON_OR_DATE_COLON,
    "\\S{3,10}, \\d\\d? \\S{3,10} 20\\d\\d,? \\d\\d?:\\d\\d(:\\d\\d)?( \\S+){3,6}@\\S+:"
    ]
  SPLITTER_MAX_LINES = 4

  def extract_from_text(message)
    delimiter = get_delimiter(message)
    message = preprocess(message, delimiter)
    lines = message.split("\n")

    markers = mark_message_lines(lines)

    lines = process_marked_lines(lines, markers)

    message = lines.join(delimiter)
    postprocess(message)
  end

  # Prepares message for being stripped.
  #
  # Replaces link brackets so that they couldn't be taken for quotation marker.
  # Splits line in two if splitter pattern preceded by some text on the same
  # line (done only for 'On <date> <person> wrote:' pattern).
  def preprocess(message, delimiter)
    message = message.gsub RE_LINK do
      match = Regexp.last_match
      offset = message.index(match[0])
      newline_index = message.slice(0, offset).rindex("\n")

      newline_index.nil? || message[newline_index + 1] == '>' ? match[0] : "@@#{match[1]}@@"
    end

    message.gsub Regexp.new(RE_ON_DATE_SMB_WROTE) do
      match = Regexp.last_match
      offset = match.begin(0)
      if offset && offset > 0 && message[offset - 1] != "\n"
        delimiter + match[0]
      else
        match[0]
      end
    end
  end

  # Mark message lines with markers to distinguish quotation lines.
  #
  # Markers:
  #
  # * e - empty line
  # * m - line that starts with quotation marker '>'
  # * s - splitter line
  # * t - presumably lines from the last message in the conversation
  # * f - forward line
  def mark_message_lines(lines)
    markers = []
    counter = 0

    while counter < lines.length
      line = lines[counter].to_s.strip

      if line == ''
        markers[counter] = 'e'
      elsif QUOT_PATTERN.match(line)
        markers[counter] = 'm'
      elsif Regexp.new("\\A#{RE_FWD_PATTERN}").match(line)
        markers[counter] = 'f'
      else
        possible_splitter_lines = lines[counter, SPLITTER_MAX_LINES].join("\n")
        splitter = is_splitter(possible_splitter_lines)
        if splitter
          splitter_lines = splitter[0].split("\n")
          splitter_lines.each_with_index { |l, j| markers[counter + j] = 's' }
          counter += (splitter_lines.length - 1)
        else
          markers[counter] = 't'
        end
      end

      counter += 1
    end

    markers.join('')
  end

  # Run regexes against message's marked lines to strip quotations.
  # Return only last message lines.
  # mark_message_lines(['Hello', 'From: foo@bar.com', '', '> Hi', 'tsem'])
  # ['Hello']
  #
  def process_marked_lines(lines, markers)
    # scan just returns a list of matches but i need a list of MatchData objects
    # so stole this from: http://stackoverflow.com/questions/9528035/ruby-stringscan-equivalent-to-return-matchdata
    def matches(string, re)
      start_at = 0
      matches  = [ ]
      while(m = string.match(re, start_at))
        matches.push(m)
        start_at = m.end(0)
      end

      matches
    end

    # if there are no splitter there should be no markers
    if markers.index('s').nil? && !markers.match(/(me*){3}/)
      markers = markers.gsub(/m/, 't')
    end

    if markers.match /\A[te]*f/
      # TODO: Set return_flags
      # return_flags[:] = [False, -1, -1]
      return lines
    end

    # inlined reply
    # use lookbehind assertions to find overlapping entries e.g. for 'mtmtm'
    # both 't' entries should be found
    matches(markers, /(?<=m)e*((?:t+e*)+)m/).each do |inline_reply|

      links = lines[inline_reply.begin(0) - 1].match(Regexp.new(RE_PARENTHESIS_LINK)) ||
              lines[inline_reply.begin(0)].strip.match(Regexp.new("\\A#{RE_PARENTHESIS_LINK}"))

      if links.nil?
        # TODO: Set return_flags
        # return_flags[:] = [False, -1, -1]
        return lines
      end
    end

    # cut out text lines coming after splitter if there are no markers there
    quotation = markers.match /(se*)+((t|f)+e*)+/

    if quotation
      # TODO: Set return_flags
      # return_flags[:] = [True, quotation.start(), len(lines)]
      return lines[0...quotation.begin(0)]
    end

    # handle the case with markers
    quotation = markers.match(Regexp.new(RE_QUOTATION)) || markers.match(Regexp.new(RE_EMPTY_QUOTATION))

    if quotation
      # TODO: Set return_flags
      # return_flags[:] = True, quotation.start(1), quotation.end(1)
      return lines[0...quotation.begin(1)] + lines[quotation.end(1)...lines.length]
    end

    # TODO: Set return_flags
    # return_flags[:] = [False, -1, -1]
    return lines
  end

  private
  def get_delimiter(message)
    delimiter = message.match(RE_DELIMITER)
    delimiter ? delimiter[0] : '\n'
  end

  #
  # Returns Matcher object if provided string is a splitter and
  # None otherwise.
  #
  def is_splitter(line)
    SPLITTER_PATTERNS.each do |pattern_string|
      pattern = Regexp.new("\\A#{pattern_string}")
      matcher = pattern.match(line)
      return matcher if matcher
    end

    return nil
  end

  def postprocess(message)
    message.gsub(RE_NORMALIZED_LINK, "<#{$1}>").strip
  end
end
