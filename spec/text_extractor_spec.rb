require "claw/text_extractor"

describe TextExtractor do
  class ExtractorKlass
    extend TextExtractor
  end

  describe '.preprocess' do
    context 'with links' do
      let!(:message) {
<<EOF
Hello
See <http://google.com
> or
<https://www.google.com>
for more
information
 On Nov 30, 2011, at 12:47 PM, Somebody <
416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4
@example.com>
wrote:

> Hi
EOF
      }

      let!(:result) {
<<EOF
Hello
See @@http://google.com
@@ or
@@https://www.google.com@@
for more
information
 On Nov 30, 2011, at 12:47 PM, Somebody <
416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4
@example.com>
wrote:

> Hi
EOF
      }

      it 'should escape links' do
        expect(ExtractorKlass.preprocess(message, '\n')).to eql result
      end
    end

    context 'when links are part of a quotation' do
      let!(:message) do
<<EOF
> <http://teemcl.mailgun.org/u/**aD1mZmZiNGU5ODQwMDNkZWZlMTExNm**

> MxNjQ4Y2RmOTNlMCZyPXNlcmdleS5v**YnlraG92JTQwbWFpbGd1bmhxLmNvbS**

> Z0PSUyQSZkPWUwY2U<http://example.org/u/aD1mZmZiNGU5ODQwMDNkZWZlMTExNmMxNjQ4Y>
EOF
      end

      it 'should not do anything' do
        expect(ExtractorKlass.preprocess(message, '\n')).to eql message
      end
    end

    context 'with splitters' do
      context 'it should wrap splitters' do
        it "shouldn't spread the splitter among too many lines" do
          message =
<<EOF
Hello
How are you? On Nov 30, 2011, at 12:47 PM,
Example <
416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4
@example.org>
wrote:

> Hi
EOF
          result =
<<EOF
Hello
How are you? On Nov 30, 2011, at 12:47 PM,
Example <
416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4
@example.org>
wrote:

> Hi
EOF

          expect(ExtractorKlass.preprocess(message, '\n')).to eql message

          message =
<<EOF
Hello
 On Nov 30, smb wrote:
Hi
On Nov 29, smb wrote:
hi
EOF

          result =
<<EOF
Hello
 On Nov 30, smb wrote:
Hi
On Nov 29, smb wrote:
hi
EOF

          expect(ExtractorKlass.preprocess(message, '\n')).to eql result
        end
      end
    end
  end

  describe '.mark_message_lines' do
    it 'should mark lines with metadata' do
      lines = ['Hello',
               '',
               # next line should be marked as splitter
               '_____________',
               'From: foo@bar.com',
               '',
               '> Hi',
               '',
               'Signature']
      expect(ExtractorKlass.mark_message_lines(lines)).to eql 'tessemet'

      lines = ['Just testing the email reply',
               '',
               'Robert J Samson',
               'Sent from my iPhone',
               '',
               # all 3 next lines should be marked as splitters
               'On Nov 30, 2011, at 12:47 PM, Skapture <',
               '416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4@skapture-staging.mailgun.org>',
               'wrote:',
               '',
               'Tarmo Lehtpuu has posted the following message on']
      expect(ExtractorKlass.mark_message_lines(lines)).to eql 'tettessset'
    end
  end

  describe '.process_marked_lines' do
    context 'quotations and last message lines are mixed' do
      it 'should consider all to be the last message' do
        markers = 'tsemmtetm'
        lines = markers.split('')
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql lines
      end
    end

    context 'no splitters => no markers' do
      it 'should return no markers' do
        markers = 'tmm'
        lines = ['1', '2', '3']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['1', '2', '3']
      end
    end

    context 'text after splitter without markers' do
      it 'should return only text that is not a quotation' do
        markers = 'tst'
        lines = ['1', '2', '3']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['1']
      end
    end

    context 'message + quotation + signature' do
      it 'should only return the message' do
        markers = 'tsmt'
        lines = ['1', '2', '3', '4']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['1', '4']
      end
    end

    context 'message + <quotation without markers> + nested quotation' do
      it 'should only return the message' do
        markers = 'tstsmt'
        lines = ['1', '2', '3', '4', '5', '6']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['1']
      end
    end

    context 'test links start with parentheses (link starts on the marker lines)' do
      it 'should return only the message' do
        markers = 'tsmttem'
        lines = ['text',
                 'splitter',
                 '>View (http://example.com',
                 '/abc',
                 ')',
                 '',
                 '> quote']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['text']
      end
    end

    context 'link starts on new line' do
      it 'should return only the message' do
        markers = 'tmmmtm'
        lines = ['text',
                 '>',
                 '>',
                 '>',
                 '(http://example.com) >  ',
                 '> life is short. (http://example.com)  '
                 ]
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql ['text']
      end
    end

    context 'with inline replies' do
      it 'should return all inline replies' do
        markers = 'tsmtmtm'
        lines = ['text',
                 'splitter',
                 '>',
                 '(http://example.com)',
                 '>',
                 'inline  reply',
                 '>']

        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql lines
      end
    end

    context 'inline replies with link not wrapped in parentheses' do
      it 'should return all inline replies' do
        markers = 'tsmtm'
        lines = ['text',
                 'splitter',
                 '>',
                 'inline reply with link http://example.com',
                 '>']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql lines
      end
    end

    context 'inline replies with link wrapped in parentheses' do
      it 'should return all inline replies' do
        markers = 'tsmtm'
        lines = ['text',
                 'splitter',
                 '>',
                 'inline  reply (http://example.com)',
                 '>']
        expect(ExtractorKlass.process_marked_lines(lines, markers)).to eql lines
      end
    end
  end

  shared_examples_for "extracts the reply" do
    it "should extract the reply" do
      expect(Claw.extract_from(message, 'text/plain')).to eql reply
    end
  end

  context "with MIME type 'text/plain'" do
    context "with 'On date, somebody wrote'" do
      let!(:message) do
<<EOF
Test reply
On 11-Apr-2011, at 6:54 PM, Roman Tkachenko <romant@example.com> wrote:

>
> Test
>
> Roman
EOF
      end
      let!(:reply) { "Test reply" }

      it_should_behave_like "extracts the reply"
    end

    context "with 'On date, somebody wrote (with foreign language)'" do
      let!(:message) do
<<EOF
Lorem

Op 13-02-2014 3:18 schreef Julius Caesar <pantheon@rome.com>:

Veniam laborum mlkshk kale chips authentic. Normcore mumblecore laboris, fanny pack readymade eu blog chia pop-up freegan enim master cleanse.
EOF
      end
      let!(:reply) { "Lorem" }

      it_should_behave_like "extracts the reply"
    end

    context "with 'On date, somebody wrote' (with slashes in the date)" do
      let!(:message) do
<<EOF
Test reply

On 04/19/2011 07:10 AM, Roman Tkachenko wrote:

>
> Test.
>
> Roman
EOF
      end
      let!(:reply) { "Test reply" }

      it_should_behave_like "extracts the reply"
    end

    context "with 'On date, somebody wrote' (allow spaces in front)" do
      let!(:message) do
<<EOF
Thanks Thanmai
On Mar 8, 2012 9:59 AM, "Example.com" <
r+7f1b094ceb90e18cca93d53d3703feae@example.com> wrote:


>**
>  Blah-blah-blah"""
EOF
      end
      let!(:reply) { "Thanks Thanmai" }

      it_should_behave_like "extracts the reply"
    end

    context "with 'On date, somebody sent'" do
      let!(:message) do
<<EOF
Test reply

On 11-Apr-2011, at 6:54 PM, Roman Tkachenko <romant@example.com> sent:

>
> Test
>
> Roman
EOF
      end
      let!(:reply) { "Test reply" }

      it_should_behave_like "extracts the reply"
    end

    context "message starts with 'On...'" do
      let!(:message) do
<<EOF
Blah-blah-blah
On blah-blah-blah
EOF
      end
      let!(:reply) { message.strip }

      it_should_behave_like "extracts the reply"
    end

    context "reply and quotation splitter share line" do
      context 'splitter pattern on the same line' do
        let!(:message) do
<<EOF
reply On Wed, Apr 4, 2012 at 3:59 PM, bob@example.com wrote:
> Hi"""
EOF
        end
        let!(:reply) { 'reply' }

        it_should_behave_like "extracts the reply"
      end

      context 'reply text is on the same line' do
        let!(:message) do
<<EOF
reply--- On Wed, Apr 4, 2012 at 3:59 PM, me@domain.com wrote:
> Hi
EOF
        end
        let!(:reply) { 'reply' }

        it_should_behave_like "extracts the reply"
      end

      context 'reply text containing "-" symbol' do
        let!(:message) do
<<EOF
reply
bla-bla - bla--- On Wed, Apr 4, 2012 at 3:59 PM, me@domain.com wrote:
> Hi
EOF
        end
        let!(:reply) { "reply\nbla-bla - bla" }

        it_should_behave_like "extracts the reply"
      end
    end

    context "when separator line is 'Original Message' in various languages" do
      let!(:base_message) do
<<EOF
Test reply

-----%s-----

Test
EOF
      end
      let!(:reply) { "Test reply" }

      context "english 1" do
        let!(:message) { sprintf(base_message, "Original Message") }
        it_should_behave_like "extracts the reply"
      end

      context "english 2" do
        let!(:message) { sprintf(base_message, "Reply Message") }
        it_should_behave_like "extracts the reply"
      end

      context "german 1" do
        let!(:message) { sprintf(base_message, "Ursprüngliche Nachricht") }
        it_should_behave_like "extracts the reply"
      end

      context "german 2" do
        let!(:message) { sprintf(base_message, "Antwort Nachricht") }
        it_should_behave_like "extracts the reply"
      end

      context "danish" do
        let!(:message) { sprintf(base_message, "Oprindelig meddelelse") }
        it_should_behave_like "extracts the reply"
      end
    end

    context "when reply is after quotations" do
      let!(:message) do
<<EOF
On 04/19/2011 07:10 AM, Roman Tkachenko wrote:

>
> Test
Test reply
EOF
      end
      let!(:reply) { "Test reply" }

      it_should_behave_like "extracts the reply"
    end

    context "when reply wraps quotations" do
      let!(:message) do
<<EOF
Test reply

On 04/19/2011 07:10 AM, Roman Tkachenko wrote:

>
> Test

Regards, Roman
EOF
      end
      let!(:reply) { "Test reply\n\nRegards, Roman" }

      it_should_behave_like "extracts the reply"
    end

    context "when reply wraps nested quotations" do
      let!(:message) do
<<EOF
Test reply
On 04/19/2011 07:10 AM, Roman Tkachenko wrote:

>Test test
>On 04/19/2011 07:10 AM, Roman Tkachenko wrote:
>
>>
>> Test.
>>
>> Roman

Regards, Roman
EOF
      end
      let!(:reply) { "Test reply\nRegards, Roman" }

      it_should_behave_like "extracts the reply"
    end

    context "when quotation separator takes 2 lines" do
      let!(:message) do
<<EOF
Test reply

On Fri, May 6, 2011 at 6:03 PM, Roman Tkachenko from Hacker News
<roman@definebox.com> wrote:

> Test.
>
> Roman

Regards, Roman
EOF
      end
      let!(:reply) { "Test reply\n\nRegards, Roman" }

      it_should_behave_like "extracts the reply"
    end

    context "when quotation separator takes 3 lines" do
      let!(:message) do
<<EOF
Test reply

On Nov 30, 2011, at 12:47 PM, Somebody <
416ffd3258d4d2fa4c85cfa4c44e1721d66e3e8f4@somebody.domain.com>
wrote:

Test message
EOF
      end
      let!(:reply) { "Test reply" }

      it_should_behave_like "extracts the reply"
    end

    context "with short quotation" do
      let!(:message) do
<<EOF
Hi

On 04/19/2011 07:10 AM, Roman Tkachenko wrote:

> Hello
EOF
      end
      let!(:reply) { "Hi" }

      it_should_behave_like "extracts the reply"
    end

    context "with indent" do
      let!(:message) do
<<EOF
YOLO salvia cillum kogi typewriter mumblecore cardigan skateboard Austin.

------On 12/29/1987 17:32 PM, Julius Caesar wrote-----

Brunch mumblecore pug Marfa tofu, irure taxidermy hoodie readymade pariatur.
EOF
      end
      let!(:reply) { "YOLO salvia cillum kogi typewriter mumblecore cardigan skateboard Austin." }

      it_should_behave_like "extracts the reply"
    end

    context "with short quotation with newline" do
      let!(:message) do
<<EOF
Btw blah blah...

On Tue, Jan 27, 2015 at 12:42 PM -0800, "Company" <christine.XXX@XXX.com> wrote:

Hi Mark,
Blah blah? 
Thanks,Christine 

On Jan 27, 2015, at 11:55 AM, Mark XXX <mark@XXX.com> wrote:

Lorem ipsum?
Mark

Sent from Acompli
EOF
      end
      let!(:reply) { "Btw blah blah..." }

      it_should_behave_like "extracts the reply"
    end

    context "with date and unicode" do
      let!(:message) do
<<EOF
Replying ok
2011/4/7 Nathan \xd0\xb8ova <support@example.com>

>  Cool beans, scro
EOF
      end
      let!(:reply) { "Replying ok" }

      it_should_behave_like "extracts the reply"
    end

    context "from block" do
      let!(:reply) { "Allo! Follow up MIME!" }

      context "english" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

From: somebody@example.com
Sent: March-19-11 5:42 PM
To: Somebody
Subject: The manager has commented on your Loop

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "german" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

Von: somebody@example.com
Gesendet: Dienstag, 25. November 2014 14:59
An: Somebody
Betreff: The manager has commented on your Loop

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "french 1" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

De : Brendan xxx [mailto:brendan.xxx@xxx.com]
Envoyé : vendredi 23 janvier 2015 16:39
À : Camille XXX
Objet : Follow Up

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "french 2" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

Le 23 janv. 2015 à 22:03, Brendan xxx <brendan.xxx@xxx.com<mailto:brendan.xxx@xxx.com>> a écrit:

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "polish" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

W dniu 28 stycznia 2015 01:53 użytkownik Zoe xxx <zoe.xxx@xxx.com>
napisał:

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "danish" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

Fra: somebody@example.com
Sendt: 19. march 2011 12:10
Til: Somebody
Emne: The manager has commented on your Loop

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end

      context "dutch" do
        let!(:message) do
<<EOF
Allo! Follow up MIME!

Op 17-feb.-2015, om 13:18 heeft Julius Caesar <pantheon@rome.com> het volgende geschreven:

Blah-blah-blah
EOF
        end

        it_should_behave_like "extracts the reply"
      end
    end

    context "quotation marker false positive" do
      let!(:message) do
<<EOF
Visit us now for assistance...
>>> >>>  http://www.domain.com <<<
Visit our site by clicking the link above
EOF
      end

      let!(:reply) { message.strip }

      it_should_behave_like "extracts the reply"
    end

    context "link closed with quotation marker on new line" do
      let!(:message) do
<<EOF
8.45am-1pm

From: somebody@example.com

<http://email.example.com/c/dHJhY2tpbmdfY29kZT1mMDdjYzBmNzM1ZjYzMGIxNT
>  <bob@example.com <mailto:bob@example.com> >

Requester:
EOF
      end
      let!(:reply) { "8.45am-1pm" }

      it_should_behave_like "extracts the reply"
    end

    context "link breaks quotation markers sequence" do
      let!(:message) do
<<EOF
Blah

On Thursday, October 25, 2012 at 3:03 PM, life is short. on Bob wrote:

>
> Post a response by replying to this email
>
(http://example.com/c/YzOTYzMmE) >
> life is short. (http://example.com/c/YzMmE)
>
EOF
      end
      let!(:reply) { "Blah" }

      it_should_behave_like "extracts the reply"

      context "link starts after some text on one line and ends on another" do
        let!(:message) do
<<EOF
Blah

On Monday, 24 September, 2012 at 3:46 PM, bob wrote:

> [Ticket #50] test from bob
>
> View ticket (http://example.com/action
_nonce=3dd518)
>
EOF
        end

        it_should_behave_like "extracts the reply"
      end
    end

    context "from block starts with date" do
      let!(:message) do
<<EOF
Blah

Date: Wed, 16 May 2012 00:15:02 -0600
To: klizhentas@example.com
EOF
      end
      let!(:reply) { "Blah" }

      it_should_behave_like "extracts the reply"
    end

    context "bold from block" do
      let!(:message) do
<<EOF
Hi

*From:* bob@example.com [mailto:
bob@example.com]
*Sent:* Wednesday, June 27, 2012 3:05 PM
*To:* travis@example.com
*Subject:* Hello
EOF
      end
      let!(:reply) { "Hi" }

      it_should_behave_like "extracts the reply"
    end

    context "weird date format in date block" do
      let!(:message) do
<<EOF
Blah
Date: Fri=2C 28 Sep 2012 10:55:48 +0000
From: tickets@example.com
To: bob@example.com
Subject: [Ticket #8] Test

EOF
      end

      let!(:reply) { "Blah" }

      it_should_behave_like "extracts the reply"
    end

    context "forwarded messages" do
      let!(:message) do
<<EOF
FYI

---------- Forwarded message ----------
From: bob@example.com
Date: Tue, Sep 4, 2012 at 1:35 PM
Subject: Two
line subject
To: rob@example.com

Text

EOF
      end

      let!(:reply) { message.strip }

      it_should_behave_like "extracts the reply"
    end

    context "forwarded message in quotations" do
      let!(:message) do
<<EOF
Blah

-----Original Message-----

FYI

---------- Forwarded message ----------
From: bob@example.com
Date: Tue, Sep 4, 2012 at 1:35 PM
Subject: Two
line subject
To: rob@example.com

EOF
      end

      let!(:reply) { "Blah" }

      it_should_behave_like "extracts the reply"
    end
  end
end
