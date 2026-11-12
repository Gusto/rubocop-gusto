# frozen_string_literal: true

require "bundler"
require "digest"

module RuboCop
  module Cop
    module Gusto
      # Flag installation of discouraged gems (e.g. ostruct) in Gemfiles and gemspecs. The
      # discouraged gems and advice about alternatives are configured under `Gems:`.
      #
      # When a Gemfile has a lockfile beside it, discouraged gems pulled in transitively are
      # flagged on the line of the Gemfile dependency that pulls them in, so each existing case
      # can be exempted with its own inline `rubocop:todo` and any new one still fails.
      #
      # @example Gems: { ostruct: "Use Struct or Data instead of OpenStruct." }
      #   # bad
      #   gem "ostruct"
      #
      #   # bad - Gemfile.lock resolves slack-ruby-client -> gli -> ostruct
      #   gem "slack-ruby-client"
      class DiscouragedGem < Base
        MSG = "Avoid using the '%{gem}' gem. %{advice}"
        MSG_TRANSITIVE = "Avoid using the '%{gem}' gem, pulled in via %{path}. %{advice}"
        MSG_UNREADABLE_LOCKFILE = "Could not parse %{lockfile} to check for discouraged gems."
        LOCKFILES = { "Gemfile" => "Gemfile.lock", "gems.rb" => "gems.locked" }.freeze

        RESTRICT_ON_SEND = %i(gem add_dependency add_development_dependency).freeze

        # @!method gem_declaration(node)
        def_node_matcher :gem_declaration, "(send nil? :gem ({str sym} $_) ...)"

        # @!method gemspec_declaration?(node)
        def_node_matcher :gemspec_declaration?, "(send nil? :gemspec ...)"

        def on_new_investigation
          return if discouraged_gems.empty? || processed_source.ast.nil?

          lockfile = lockfile_path
          check_lockfile(lockfile) if lockfile && ::File.file?(lockfile)
        end

        def on_send(node)
          check_gem_usage(node)
        end

        # Asked once per run, so only a lockfile-only change at the project root busts the cache.
        def external_dependency_checksum
          lockfiles = LOCKFILES.values.select { |path| ::File.file?(path) }
          return if lockfiles.empty?

          Digest::SHA256.hexdigest(lockfiles.map { |path| ::File.read(path) }.join)
        end

        private

        def check_gem_usage(node)
          return unless node.first_argument&.type?(:str, :sym)
          return unless discouraged_gems.include?(node.first_argument.value.to_s)

          add_offense(node, message: message_for(node.first_argument.value.to_s))
          # No autocorrect: removing dependencies is a project decision.
        end

        def lockfile_path
          file_path = processed_source.file_path.to_s
          lockfile = LOCKFILES[::File.basename(file_path)]
          ::File.join(::File.dirname(file_path), lockfile) if lockfile
        end

        def check_lockfile(lockfile)
          parser = ::Bundler::LockfileParser.new(::File.read(lockfile))
        rescue ::Bundler::LockfileError
          add_offense(fallback_location, message: format(MSG_UNREADABLE_LOCKFILE, lockfile: ::File.basename(lockfile)))
        else
          graph = dependency_graph(parser.specs)
          declared = declared_gems
          paths_by_location = Hash.new { |hash, location| hash[location] = [] }
          parser.dependencies.each_key do |root|
            discouraged_paths(root, graph).each do |path|
              # A declared discouraged gem is already flagged by on_send.
              next if path.one? && declared.key?(root)

              paths_by_location[declared.fetch(root) { fallback_location }] << path
            end
          end
          # RuboCop keeps only the first offense per location, so they are combined.
          paths_by_location.each do |location, paths|
            add_offense(location, message: paths.map { |path| message_for_path(path) }.join(" "))
          end
        end

        # Platform-specific specs share a name, so their dependencies are merged.
        def dependency_graph(specs)
          specs.each_with_object({}) do |spec, graph|
            (graph[spec.name] ||= []).concat(spec.dependencies.map(&:name)).uniq!
          end
        end

        # Breadth-first, so each discouraged gem is reported via its shortest path from root.
        def discouraged_paths(root, graph)
          parents = { root => nil }
          queue = [root]
          found = []
          until queue.empty?
            name = queue.shift
            found << name if discouraged_gems.include?(name)
            graph.fetch(name, []).each do |dependency|
              next if parents.key?(dependency)

              parents[dependency] = name
              queue << dependency
            end
          end
          found.map { |name| path_to(name, parents) }
        end

        def path_to(name, parents)
          path = [name]
          path.unshift(parents[path.first]) while parents[path.first]
          path
        end

        def declared_gems
          processed_source.ast.each_node(:send).with_object({}) do |node, declared|
            name = gem_declaration(node)
            declared[name.to_s] ||= node if name
          end
        end

        # Dependencies that come from a gemspec, eval_gemfile, or similar have no `gem` line.
        def fallback_location
          processed_source.ast.each_node(:send).find { |node| gemspec_declaration?(node) } ||
            processed_source.buffer.line_range(1)
        end

        def message_for_path(path)
          return message_for(path.first) if path.one?

          format(MSG_TRANSITIVE, gem: path.last, path: path.join(" -> "), advice: advice_for(path.last))
        end

        def discouraged_gems
          @discouraged_gems ||= gems_config.keys.map(&:to_s)
        end

        def message_for(gem)
          format(MSG, gem:, advice: advice_for(gem))
        end

        def advice_for(gem)
          gems_config[gem]
        end

        def gems_config
          cop_config["Gems"] || {}
        end
      end
    end
  end
end
