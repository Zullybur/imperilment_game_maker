require 'game_submitter.rb'
require 'vcr_setup.rb'

describe GameSubmitter do
  context "Creating a game" do
    VCR.use_cassette("new_game_cassette") do
      it { expect(false).to be_truthy }
    end
  end

  context "Creating a category" do
    VCR.use_cassette("new_game_cassette") do
      it { expect(false).to be_truthy }
    end
  end

  context "Creating an answer" do
    VCR.use_cassette("new_game_cassette") do
      it { expect(false).to be_truthy }
    end
  end
end