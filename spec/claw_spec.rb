require 'spec_helper'

describe Claw do
  describe '.extract_from' do
    shared_examples_for "extracts the reply" do
      it "should extract the reply" do
        expect(Claw.extract_from(message, 'text/plain')).to eql reply
      end
    end

    context 'with an invalid MIME type' do
      it 'should raise an error' do
        expect {
          Claw.extract_from("hello", "image/jpeg")
        }.to raise_error(Claw::InvalidMimeTypeError, "Invalid MIME type image/jpeg")
      end
    end
  end
end
