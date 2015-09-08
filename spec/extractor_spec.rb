require "claw/extractor"

describe Extractor do
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
        expect(Extractor.preprocess(message, '\n')).to eql result
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
        expect(Extractor.preprocess(message, '\n')).to eql message
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

          expect(Extractor.preprocess(message, '\n')).to eql message

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

          expect(Extractor.preprocess(message, '\n')).to eql result
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
      expect(Extractor.mark_message_lines(lines)).to eql 'tessemet'

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
      expect(Extractor.mark_message_lines(lines)).to eql 'tettessset'
    end
  end

  describe '.process_marked_lines' do
    context 'quotations and last message lines are mixed' do
      it 'should consider all to be the last message' do
        markers = 'tsemmtetm'
        lines = markers.split('')
        expect(Extractor.process_marked_lines(lines, markers)).to eql lines
      end
    end

    context 'no splitters => no markers' do
      it 'should return no markers' do
        markers = 'tmm'
        lines = ['1', '2', '3']
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['1', '2', '3']
      end
    end

    context 'text after splitter without markers' do
      it 'should return only text that is not a quotation' do
        markers = 'tst'
        lines = ['1', '2', '3']
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['1']
      end
    end

    context 'message + quotation + signature' do
      it 'should only return the message' do
        markers = 'tsmt'
        lines = ['1', '2', '3', '4']
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['1', '4']
      end
    end

    context 'message + <quotation without markers> + nested quotation' do
      it 'should only return the message' do
        markers = 'tstsmt'
        lines = ['1', '2', '3', '4', '5', '6']
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['1']
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
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['text']
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
        expect(Extractor.process_marked_lines(lines, markers)).to eql ['text']
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

        expect(Extractor.process_marked_lines(lines, markers)).to eql lines
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
        expect(Extractor.process_marked_lines(lines, markers)).to eql lines
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
        expect(Extractor.process_marked_lines(lines, markers)).to eql lines
      end
    end
  end
end
