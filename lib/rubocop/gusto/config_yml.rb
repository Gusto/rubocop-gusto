# frozen_string_literal: true

require 'pathname'

module RuboCop
  module Gusto
    # A class for reading and writing a .rubocop.yml file.
    #
    # You may rightly ask why we don't just use the standard library's YAML.load_file
    # and YAML.dump. Simple, we want to preserve the comments.
    class ConfigYml
      COMMENT_REGEX = /\A\s*#.*\z/
      COP_HEADER_REGEX = /\A[A-Z0-9][A-Za-z0-9\/:]+:(\s*#.*)?\z/
      KEY_REGEX = /\A\w[\w\/]+:(\s*#.*)?\z/i # case insensitive
      PREAMBLE_KEYS = %w(inherit_mode inherit_gem inherit_from plugins require).freeze
      INDENT_REGEX = /\A(  |- )/

      # @param [String] file_path the path to the .rubocop.yml file
      def self.load_file(file_path = '.rubocop.yml')
        new(File.readlines(file_path))
      rescue Errno::ENOENT
        new([])
      end

      attr_reader :preamble, :cops

      # @param [Array<String>] lines the lines of the .rubocop.yml file
      def initialize(lines)
        @preamble, @cops = chunk_blocks(lines).partition do |block|
          block.none? { |line| line.rstrip.match?(COP_HEADER_REGEX) }
        end
      end

      # Find if there's already an inherit_gem section and add the gem to it if needed
      def add_inherit_gem(gem_name, *config_paths)
        update_section_data('inherit_gem') do |data|
          data ||= {}
          data[gem_name.to_s] = config_paths.flatten
          data
        end
      end

      # Add a plugin to the plugins section or create it if it doesn't exist
      def add_plugin(plugins)
        update_section_data('plugins') do |data|
          data ||= []
          data.concat(plugins).uniq
        end
      end

      def update_section_data(section_name, &)
        # Look for an existing section in the preamble
        section = preamble.find { |chunk| chunk_name(chunk) == section_name }

        if section
          comments = section.select { |line| line.match?(COMMENT_REGEX) }
          data = YAML.load(section.join)[section_name.to_s] # it can be present and nil
        else
          comments = []
          data = nil
        end

        data = yield data

        section_lines = YAML.dump({ section_name.to_s => data }).lines.drop(1) # drop the ---
        section_lines.map! { |line| line.sub(/\A(\s*)-/, '\1  -') } # prefer indented lists
        section_lines.insert(0, *comments) # add the comments back in at the top
        section_lines << "\n" # ensure there's a trailing newline

        section ? section.replace(section_lines) : preamble.unshift(section_lines)

        self
      end

      def sort!
        # Sort the preamble chunks by our preferred order, falling back to key name
        preamble.sort_by! do |chunk|
          key = chunk_name(chunk)
          PREAMBLE_KEYS.index(key)&.to_s || key
        end

        # Sort the cops by their key name, putting comments at the top
        cops.sort_by! { |cop| chunk_name(cop) || 'AAAAA/Comment?' }

        self
      end

      def empty?
        cops.empty? && preamble.empty?
      end

      def lines
        combined = (preamble + cops).flatten
        combined.pop # there's always one empty newline because of how we parse
        combined
      end

      def to_s
        lines.join
      end

      def write(file_path)
        File.write(file_path, to_s)
      end

      private

      # Return the name of a chunk by finding the root key
      def chunk_name(chunk)
        # Try to find a line that exactly matches KEY_REGEX
        # Use rstrip, not strip, to preserve indentation
        name_line = chunk.find { |line| line.rstrip.match?(KEY_REGEX) }
        name_line&.rstrip&.delete_suffix(':')
      end

      # Splits the lines into blocks whenever we drop from indented to unindented
      def chunk_blocks(lines)
        # slice whenever we drop from indented to unindented
        chunks = lines.slice_when do |prev, line|
          prev.match?(INDENT_REGEX) && !prev.strip.empty? && !line.match?(INDENT_REGEX)
        end

        # Process each chunk to remove leading newlines and add 1 trailing newline
        chunks.filter_map do |chunk|
          # Remove leading and trailing empty lines
          chunk.shift while chunk.first.to_s.strip.empty?
          chunk.pop while chunk.last.to_s.strip.empty?

          # Ensure each chunk ends with a blank newline
          chunk << "\n"
        end
      end
    end
  end
end
