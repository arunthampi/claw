require "claw/extractor"
require "nokogiri"

class HtmlExtractor < Extractor
  CHECKPOINT_PREFIX = '#!%!'
  CHECKPOINT_SUFFIX = '!%!#'
  CHECKPOINT_PATTERN = CHECKPOINT_PREFIX + "\\d+" + CHECKPOINT_SUFFIX
  QUOTE_IDS = ['OLK_SRC_BODY_SECTION']

  # Extract not quoted message from provided html message body
  # using tags and plain text algorithm.

  # Cut out the 'blockquote', 'gmail_quote' tags.
  # Cut Microsoft quotations.

  # Then use plain text algorithm to cut out splitter or
  # leftover quotation.
  # This works by adding checkpoint text to all html tags,
  # then converting html to text,
  # then extracting quotations from text,
  # then checking deleted checkpoints,
  # then deleting necessary tags.
  def self.extract_from_html(message)
    message = message.strip
    return message if message == ''

    html_tree = Nokogiri::HTML(message)

    cut_quotations = cut_gmail_quote(html_tree) ||
                     cut_blockquote(html_tree) ||
                     cut_microsoft_quote(html_tree) ||
                     cut_by_id(html_tree) ||
                     cut_from_block(html_tree)

    html_tree.text
    #html_tree = html_tree.dup

    #number_of_checkpoints = add_checkpoint(html_tree, 0)
    #quotation_checkpoints = number_of_checkpoints.times.map { false }
    #msg_with_checkpoints = html_tree.text

    #plain_text = msg_with_checkpoints

    #delimiter = get_delimiter(plain_text)
    #plain_text = preprocess(plain_text, delimiter, false)

    #lines = plain_text.split("\n")
  end

  # Cuts the outermost block element with class gmail_quote. '''
  def self.cut_gmail_quote(tree)
    gmail_quotes = tree.css('.gmail_quote')
    if gmail_quotes.length > 0
      gmail_quotes.each { |q| q.remove }
      return true
    end

    return false
  end

  # Cuts splitter block and all following blocks.
  def self.cut_microsoft_quote(tree)
    tree.xpath('//comment()').remove

    splitter = tree.xpath(
      # outlook 2007, 2010
      "//div[@style='border:none;border-top:solid #B5C4DF 1.0pt;" +
      "padding:3.0pt 0cm 0cm 0cm']|" +
      "//div[@style='padding-top: 5px; " + # windows mail
      "border-top-color: rgb(229, 229, 229); " +
      "border-top-width: 1px; border-top-style: solid;']"
    )

    if splitter.length > 0
      splitter = splitter[0]

      if splitter == splitter.parent.children()[0]
        splitter = splitter.parent
      end
    else
      splitter = tree.xpath(
        "//div" +
        "/div[@class='MsoNormal' and @align='center' " +
        "and @style='text-align:center']" +
        "/font" +
        "/span" +
        "/hr[@size='3' and @width='100%' and @align='center' " +
        "and @tabindex='-1']"
      )
      if splitter.length > 0
        splitter = splitter[0]
        splitter = splitter.parent.parent
        splitter = splitter.parent.parent
      end
    end

    if !splitter.nil?
      while elem = splitter.next
        elem.remove
      end
      splitter.remove

      return true
    end

    return false
  end

  def self.cut_blockquote(tree)
    quotes = tree.xpath('.//blockquote')
    if quotes.length > 0
      quotes.remove
      return true
    end

    return false
  end

  def self.cut_by_id(tree)
    QUOTE_IDS.each do |quote_id|
      quotes = tree.css("##{quote_id}")
      if quotes.length > 0
        quotes.remove
        return true
      end
    end

    return false
  end

  # Cuts div tag which wraps block starting with "From:"
  # handle the case when From: block is enclosed in some tag
  def self.cut_from_block(tree)
    block = tree.xpath(
      "//*[starts-with(mg:text_content(), 'From:')]|" +
      "//*[starts-with(mg:text_content(), 'Date:')]"
    )

    if block.length > 0
      block = block[-1]
      while block.parent
        if block.name == 'div'
          block.parent.next.remove
          return true
        else
          block = block.parent
        end
      end
    else
      block = tree.xpath(
        "//*[starts-with(mg:tail(), 'From:')]|" +
        "//*[starts-with(mg:tail(), 'Date:')]"
      )
      if block.length > 0
        block = block[0]
        while block.next
          block.next.remove
        end
        block.remove
        return true
      end
    end

    return false
  end

  # Recursively adds checkpoints to the html tree
  def self.add_checkpoint(html_note, counter)

  end
end
