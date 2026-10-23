# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"
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

  context "with a department PiiMethods override" do
    let(:consumer_overrides) do
      {
        "plugins" => ["rubocop-gusto"],
        "Gusto/Logging" => { "PiiMethods" => ["custom_secret"] },
      }
    end

    it "uses the department's methods without a configuration warning" do
      source_path = File.join(project_directory, "app/models/example.rb")
      FileUtils.mkdir_p(File.dirname(source_path))
      File.write(source_path, "Rails.logger.info(user.custom_secret)\n")
      config

      output, error, status = Open3.capture3(
        RbConfig.ruby, "-S", "rubocop", "--config", File.join(project_directory, ".rubocop.yml"),
        "--only", "Gusto/Logging/PiiAccessor", "--format", "simple", "--cache", "false", source_path
      )

      expect(status.success?).to be(true), error
      expect(error).not_to include("does not support PiiMethods parameter")
      expect(output).to include("Avoid logging PII accessor .custom_secret.")
    end
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
