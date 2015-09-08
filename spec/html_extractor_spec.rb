require "claw/html_extractor"

describe HtmlExtractor do
  shared_examples_for "should extract the reply" do
    it "should extract the reply" do
      expect(HtmlExtractor.extract_from_html(message).to_s.gsub(/\s/, '').strip).to eql reply.gsub(/\s/, '').strip
    end
  end

  describe '.extract_from_html' do
    context 'splitter inside block quote' do
      let!(:message) do
<<EOF
Reply
<blockquote>

  <div>
    On 11-Apr-2011, at 6:54 PM, Bob &lt;bob@example.com&gt; wrote:
  </div>

  <div>
    Test
  </div>

</blockquote>"""
EOF
      end

      let!(:reply) { "<html><body><p>Reply</p></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context 'splitter outside the blockquote' do
      let!(:message) do
<<EOF
<html>
<body>
Reply

<div>
  On 11-Apr-2011, at 6:54 PM, Bob &lt;bob@example.com&gt; wrote:
</div>

<div>
  Test
</div>
</body>
</html>
EOF
      end
      let!(:reply) do
<<EOF
<html>
<body>
Reply

</body></html>
EOF
      end

      it_should_behave_like "should extract the reply"
    end

    context 'empty body' do
      let!(:message) { "" }
      let!(:reply)   { "" }

      it_should_behave_like "should extract the reply"
    end

    context 'gmail quote' do
      let!(:message) do
<<EOF
Reply
<div class="gmail_quote">
  <div class="gmail_quote">
    On 11-Apr-2011, at 6:54 PM, Bob &lt;bob@example.com&gt; wrote:
    <div>
      Test
    </div>
  </div>
</div>
EOF
      end

      let!(:reply) { "<html><body><p>Reply</p></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "unicode reply" do
      let!(:message) do
<<EOF
Reply \xa0 \xa0 Text<br>

<div>
  <br>
</div>

<blockquote class="gmail_quote">
  Quote
</blockquote>
EOF
      end

      let!(:reply) { "<html><body><p>Reply&#160;&#160;Text<br></p><div><br></div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "with blockquote disclaimer" do
      let!(:message) do
<<EOF
<html>
  <body>
  <div>
    <div>
      message
    </div>
    <blockquote>
      Quote
    </blockquote>
  </div>
  <div>
    disclaimer
  </div>
  </body>
</html>
EOF
      end

      let!(:reply) do
<<EOF
<html>
  <body>
  <div>
    <div>
      message
    </div>
  </div>
  <div>
    disclaimer
  </div>
  </body>
</html>
EOF
      end

      it_should_behave_like "should extract the reply"
    end

    context 'with date block' do
      let!(:message) do
<<EOF
<div>
  message<br>
  <div>
    <hr>
    Date: Fri, 23 Mar 2012 12:35:31 -0600<br>
    To: <a href="mailto:bob@example.com">bob@example.com</a><br>
    From: <a href="mailto:rob@example.com">rob@example.com</a><br>
    Subject: You Have New Mail From Mary!<br><br>

    text
  </div>
</div>
EOF
      end

      let!(:reply) { "<html><body><div>message<br></div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "with from block" do
      let!(:message) do
<<EOF
<div>
message<br>
<div>
<hr>
From: <a href="mailto:bob@example.com">bob@example.com</a><br>
Date: Fri, 23 Mar 2012 12:35:31 -0600<br>
To: <a href="mailto:rob@example.com">rob@example.com</a><br>
Subject: You Have New Mail From Mary!<br><br>

text
</div></div>
EOF
      end

      let!(:reply) { "<html><body><div>message<br></div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "reply shares div with from block" do
      let!(:message) do
<<EOF
<body>
  <div>

    Blah<br><br>

    <hr>Date: Tue, 22 May 2012 18:29:16 -0600<br>
    To: xx@hotmail.ca<br>
    From: quickemail@ashleymadison.com<br>
    Subject: You Have New Mail From x!<br><br>

  </div>
</body>
EOF
      end

      let!(:reply) { "<html><body><div>Blah<br><br></div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "reply quotations share block" do
      pending
    end

    context "OLK_SRC_BODY_SECTION stripped" do
      let!(:message) { File.read(File.join('spec', 'fixtures', 'OLK_SRC_BODY_SECTION.html')) }
      let!(:reply)  { "<html><body><div>Reply</div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "reply separated by hr" do
      let!(:message) { File.read(File.join('spec', 'fixtures', 'reply-separated-by-hr.html')) }
      let!(:reply)  { "<html><body><div>Hi<div>there</div></div></body></html>" }

      it_should_behave_like "should extract the reply"
    end

    context "mail from different providers" do
      let!(:reply_regex) { /\AHi\. I am fine\.\s*\n\s*Thanks,\s*\n\s*Alex\s*\Z/ }

      shared_examples "should extract the reply from the provider" do
        it 'parses and extracts the reply for the provider' do
          message = File.read(File.join('spec', 'fixtures', 'html_replies', "#{provider}.html"))
          reply = HtmlExtractor.extract_from_html(message)
          reply
          plain_reply = Nokogiri::HTML(reply).text
          if plain_reply.match(reply_regex)
            expect(plain_reply).to match reply_regex
          else
            expect(plain_reply).to eql "Hi. I am fine.\n\nThanks,\nAlex"
          end
        end
      end

      %w(gmail mail_ru hotmail ms_outlook_2003 ms_outlook_2007 thunderbird windows_mail yandex_ru).each do |provider_string|
        context "provider: #{provider_string}" do
          it_should_behave_like "should extract the reply from the provider" do
            let!(:provider) { provider_string }
          end
        end
      end
    end
  end
end
