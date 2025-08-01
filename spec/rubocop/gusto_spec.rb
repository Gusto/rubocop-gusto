# frozen_string_literal: true

RSpec.describe RuboCop::Gusto do
  it "has a version number" do
    expect(RuboCop::Gusto::VERSION).not_to be_nil
  end

  describe "default configuration file" do
    subject(:config) { RuboCop::ConfigLoader.load_file("config/default.yml") }

    let(:registry) { RuboCop::Cop::Registry.global }

    let(:cop_names) do
      registry.with_department(:Gusto).cops.map(&:cop_name)
    end

    let(:configuration_keys) { config.keys }

    let(:version_regexp) { /\A\d+\.\d+\z|\A<<next>>\z/ }

    it "includes all gusto cops in the configuration" do
      missing_cops = cop_names - config.keys
      expect(missing_cops).to be_empty, "Cops not found in config/default.yml: #{missing_cops.inspect}"
    end

    it "has a nicely formatted description for all cops" do
      cop_names.each do |name|
        description = config.dig(name, "Description")
        expect(description).not_to be_nil, "`Description` for `#{name}` is missing."
        expect(description.include?("\n")).to be(false), "`Description` for `#{name}` should not include a newline."

        start_with_subject = description.match(/\AThis cop (?<verb>.+?) .*/)
        suggestion = start_with_subject[:verb]&.capitalize if start_with_subject
        suggestion ||= "a verb"
        expect(start_with_subject.nil?).to(
          be(true), "`Description` for `#{name}` should be started with `#{suggestion}` instead of `This cop ...`."
        )
      end
    end

    it "has a period at EOL of description" do
      cop_names.each do |name|
        description = config.dig(name, "Description")

        expect(description).to match(/\.\z/), "`Description` for `#{name}` should end with a period."
      end
    end

    it "sorts configuration keys alphabetically" do
      ["config/default.yml", "config/rails.yml"].each do |config_file|
        config_keys = RuboCop::ConfigLoader.load_file(config_file)
        expected = config_keys.keys.sort
        config_keys.each_key.with_index do |key, idx|
          expect(key).to eq(expected[idx]), "Cops should be sorted. Please sort with `bundle exec exe/rubocop-gusto sort #{config_file}`."
        end
      end
    end

    it "has a SupportedStyles for all EnforcedStyle and EnforcedStyle is valid" do
      errors = []
      cop_names.each do |name|
        enforced_styles = config[name]&.select { |key, _| key.start_with?("Enforced") } || {}
        enforced_styles.each do |style_name, style|
          supported_key = RuboCop::Cop::Util.to_supported_styles(style_name)
          valid = config[name][supported_key]
          unless valid
            errors.push("#{supported_key} is missing for #{name}")
            next
          end
          next if valid.include?(style)

          errors.push("invalid #{style_name} '#{style}' for #{name} found")
        end
      end

      expect(errors).to be_empty
    end

    it "does not have any duplication" do
      fname = File.expand_path("../../config/default.yml", __dir__)
      content = File.read(fname)
      errors = []
      RuboCop::YAMLDuplicationChecker.check(content, fname) do |key_1, key_2|
        errors.push("#{fname} has duplication of #{key_1.value} on line #{key_1.start_line} and line #{key_2.start_line}")
      end

      expect(errors).to be_empty
    end

    it "does not include `Safe: true`" do
      cop_names.each do |name|
        safe = config.dig(name, "Safe")
        expect(safe).not_to be(true), "`#{name}` has unnecessary `Safe: true` config."
      end
    end

    it "does not include unnecessary `SafeAutoCorrect: false`" do
      cop_names.each do |cop_name|
        next unless config.dig(cop_name, "Safe") == false

        safe_autocorrect = config.dig(cop_name, "SafeAutoCorrect")

        expect(safe_autocorrect).not_to(be(false), "`#{cop_name}` has unnecessary `SafeAutoCorrect: false` config.")
      end
    end

    it "sorts cop names alphabetically" do
      previous_key = ""
      config_default = YAML.load_file("config/default.yml")

      config_default.each_key do |key|
        next if %w(inherit_mode AllCops plugins).include?(key)

        expect(previous_key <= key).to be(true), "Cops should be sorted alphabetically. Please sort #{key} before #{previous_key}."
        previous_key = key
      end
    end
  end
end
