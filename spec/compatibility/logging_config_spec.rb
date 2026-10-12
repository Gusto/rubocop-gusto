# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "rubocop"

Dir[File.expand_path("../../lib/rubocop/cop/gusto/logging/*.rb", __dir__)].each { |file| require file }

RSpec.describe "Logging configuration compatibility" do
  let(:logging_config) do
    YAML.load_file(File.expand_path("../../config/gusto_cops.yml", __dir__)).select do |name, _|
      name == "Gusto/Logging" || name.start_with?("Gusto/Logging/")
    end
  end

  let(:project_directory) { File.realpath(Dir.mktmpdir) }
  let(:consumer_overrides) { {} }
  let(:todo_overrides) { {} }

  let(:config) do
    File.write(File.join(project_directory, ".rubocop_logging.yml"), logging_config.to_yaml)
    File.write(File.join(project_directory, ".rubocop_todo.yml"), todo_overrides.to_yaml)
    consumer_config = { "inherit_from" => [".rubocop_logging.yml", ".rubocop_todo.yml"] }.merge(consumer_overrides)
    config_path = File.join(project_directory, ".rubocop.yml")
    File.write(config_path, consumer_config.to_yaml)
    RuboCop::ConfigLoader.load_file(config_path)
  end

  around do |example|
    example.run
  ensure
    FileUtils.remove_entry(project_directory)
  end

  RuboCop::Cop::Registry.global.with_department(:"Gusto/Logging").each do |cop_class|
    describe cop_class.cop_name do
      let(:cop) { cop_class.new(config) }

      shared_examples "preserves default exclusions" do
        it "keeps spec and test files excluded while checking application files" do
          expect(cop.relevant_file?(File.join(project_directory, "spec/models/user_spec.rb"))).to be(false)
          expect(cop.relevant_file?(File.join(project_directory, "test/models/user_test.rb"))).to be(false)
          expect(cop.relevant_file?(File.join(project_directory, "app/models/user.rb"))).to be(true)
        end
      end

      context "with consumer exclusions" do
        let(:consumer_overrides) { { cop_class.cop_name => { "Exclude" => ["app/models/custom.rb"] } } }

        include_examples "preserves default exclusions"

        it "honors the consumer exclusion" do
          expect(cop.relevant_file?(File.join(project_directory, "app/models/custom.rb"))).to be(false)
        end
      end

      context "with generated todo exclusions" do
        let(:todo_overrides) { { cop_class.cop_name => { "Exclude" => ["app/models/legacy.rb"] } } }

        include_examples "preserves default exclusions"

        it "honors the todo exclusion" do
          expect(cop.relevant_file?(File.join(project_directory, "app/models/legacy.rb"))).to be(false)
        end
      end

      context "with consumer exclusions merged into generated todo exclusions" do
        let(:consumer_overrides) do
          {
            cop_class.cop_name => {
              "inherit_mode" => { "merge" => ["Exclude"] },
              "Exclude" => ["app/models/custom.rb"],
            },
          }
        end
        let(:todo_overrides) { { cop_class.cop_name => { "Exclude" => ["app/models/legacy.rb"] } } }

        include_examples "preserves default exclusions"

        it "honors both consumer and todo exclusions" do
          expect(cop.relevant_file?(File.join(project_directory, "app/models/custom.rb"))).to be(false)
          expect(cop.relevant_file?(File.join(project_directory, "app/models/legacy.rb"))).to be(false)
        end
      end
    end
  end
end
