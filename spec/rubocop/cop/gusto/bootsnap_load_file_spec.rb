# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::BootsnapLoadFile, :config do
  context 'when calling JSON.parse(File.read(path))' do
    let(:source) do
      <<~RUBY
        JSON.load(File.read(path))
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use JSON.load_file(path) to improve load time with bootsnap
      RUBY
    end

    it { expect_offense(source) }
  end

  context 'when calling YAML.parse(File.read(path))' do
    let(:source) do
      <<~RUBY
        YAML.load(File.read(path))
        ^^^^^^^^^^^^^^^^^^^^^^^^^^ Use YAML.load_file(path) to improve load time with bootsnap
      RUBY
    end

    it { expect_offense(source) }
  end

  context 'when using File.open and a block' do
    let(:source) do
      <<~RUBY
        File.open('config/locales/mandatory_sick_time.yml') { |file| YAML.load(file) }
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use YAML.load_file('config/locales/mandatory_sick_time.yml') to improve load time with bootsnap
      RUBY
    end

    it { expect_offense(source) }
  end

  context 'when calling YAML.load_file(path)' do
    let(:source) do
      <<~RUBY
        YAML.load_file(path)
      RUBY
    end

    it { expect_no_offenses(source) }
  end

  context 'when calling load with no arguments' do
    let(:source) do
      <<~RUBY
        YAML.load
        JSON.load
        load
        method.load.file
        Object.load
      RUBY
    end

    it { expect_no_offenses(source) }
  end
end
