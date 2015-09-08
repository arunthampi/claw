require "claw/html_extractor"

describe HtmlExtractor do
  shared_examples_for "extracts the reply" do
    it "should extract the reply" do
      expect(HtmlExtractor.extract_from_html(message, 'text/html')).to eql reply
    end
  end

  describe '.extract_from_html' do

  end
end
