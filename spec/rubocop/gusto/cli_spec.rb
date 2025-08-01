# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tempfile"
require "fileutils"

RSpec.describe "rubocop-gusto CLI" do
  def run_cli(*command)
    cli_path = File.expand_path("../../../exe/rubocop-gusto", __dir__)
    stdout, status = Open3.capture2e(cli_path, *command)
    expect(status).to be_success, "Expected command #{command.join(' ')} to succeed, but it failed with status #{status.exitstatus}\n#{stdout}"
    stdout
  end

  describe "help command" do
    it "displays help" do
      stdout = run_cli("help")
      expect(stdout).to include("Commands:")
    end
  end

  describe "init command" do
    it "initializes rubocop-gusto in a new project" do
      Tempfile.create(["rubocop", ".yml"]) do |tmpfile|
        Dir.mktmpdir do |dir|
          yml_path = File.join(dir, ".rubocop.yml")
          FileUtils.cp(tmpfile.path, yml_path)
          Dir.chdir(dir) do
            stdout = run_cli("init")
            yml_contents = YAML.safe_load_file(yml_path)
            expect(yml_contents["plugins"]).to include("rubocop-gusto")
            expect(yml_contents["plugins"]).to include("rubocop-rspec")
            expect(yml_contents.dig("inherit_gem", "rubocop-gusto")).to eq(["config/default.yml"])
            expect(stdout).to include("bundle binstub rubocop")
            expect(stdout).to include(".rubocop.yml")
            expect(stdout).to include(".rubocop_todo.yml")

            stdout = run_cli("init")
            expect(stdout).to include("update")
          end
        end
      end
    end

    it "initializes rubocop-gusto in an existing project" do
      Tempfile.create(["rubocop", ".yml"]) do |tmpfile|
        Dir.mktmpdir do |dir|
          yml_path = File.join(dir, ".rubocop.yml")
          File.write(yml_path, "AllCops:\n  TargetRubyVersion: 3.0\n")

          yml_todo_path = File.join(dir, ".rubocop_todo.yml")
          File.write(yml_todo_path, "# nothing in this file yet, but it should stay that way\n")
          FileUtils.cp(tmpfile.path, yml_path)
          Dir.chdir(dir) do
            stdout = run_cli("init")
            expect(File.read(yml_path)).to include("rubocop-gusto")
            expect(stdout).to include("bundle binstub rubocop")
            expect(stdout).to include(".rubocop.yml")
            expect(stdout).to include(".rubocop_todo.yml")

            expect(File.read(yml_todo_path)).to eq("# nothing in this file yet, but it should stay that way\n")
          end
        end
      end
    end
  end

  describe "sort command" do
    it "sorts the cops in the file as expected" do
      unsorted_path = File.expand_path("../../fixtures/unsorted_rubocop.yml", __dir__)
      sorted_path   = File.expand_path("../../fixtures/sorted_rubocop.yml", __dir__)

      Tempfile.create(["rubocop", ".yml"]) do |tmpfile|
        FileUtils.cp(unsorted_path, tmpfile.path)
        tmpfile.flush

        stdout = run_cli("sort", tmpfile.path)

        result = File.read(tmpfile.path)
        sorted_lines = File.read(sorted_path)

        expect(result).to eq(sorted_lines)
        expect(stdout).to include("Sorting")
        expect(stdout).to include("Done!")
      end
    end
  end
end
