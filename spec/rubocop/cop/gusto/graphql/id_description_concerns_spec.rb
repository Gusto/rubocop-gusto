# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::Graphql::IdDescriptionConcerns do
  subject(:concern) { host_class.new }

  let(:host_class) do
    Class.new do
      include RuboCop::Cop::Gusto::Graphql::IdDescriptionConcerns
    end
  end

  def parse_source(source)
    RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
  end

  describe "#id_type?" do
    it "returns false when type node is nil" do
      expect(concern.__send__(:id_type?, nil)).to be(false)
    end

    it "returns false when type is not a const" do
      ast = parse_source("field :id, some_method, null: false").ast
      field = ast
      type_node = field.arguments[1]
      expect(concern.__send__(:id_type?, type_node)).to be(false)
    end

    it "returns false when const is neither ID nor GraphQL::Types::ID" do
      ast = parse_source("field :id, String, null: false").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:id_type?, type_node)).to be(false)
    end

    it "returns true for ID const" do
      ast = parse_source("field :id, ID, null: false").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:id_type?, type_node)).to be(true)
    end

    it "returns true for GraphQL::Types::ID" do
      ast = parse_source("field :id, GraphQL::Types::ID, null: false").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:id_type?, type_node)).to be(true)
    end
  end

  describe "#array_id_type?" do
    it "returns false when type node is nil" do
      expect(concern.__send__(:array_id_type?, nil)).to be(false)
    end

    it "returns true for array of ID" do
      ast = parse_source("argument :ids, [ID], required: true").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:array_id_type?, type_node)).to be(true)
    end

    it "returns false for non-array type" do
      ast = parse_source("argument :id, ID, required: true").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:array_id_type?, type_node)).to be(false)
    end

    it "returns false for array of non-ID types" do
      ast = parse_source("argument :names, [String], required: true").ast
      type_node = ast.arguments[1]
      expect(concern.__send__(:array_id_type?, type_node)).to be(false)
    end
  end

  describe "#description_from_block" do
    it "returns nil when parent is nil (safe navigation on parent)" do
      field = instance_double(RuboCop::AST::Node, parent: nil)
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end

    it "returns nil when parent is not the field block" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, 'The T identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end

    it "returns nil when the enclosing block is not the field block" do
      processed = parse_source(<<~RUBY)
        class T < Base
          outer do
            field :id, ID, 'The T identifier', null: false
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end

    it "returns nil when field block has no description string" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false do
            argument :x, String, required: false
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end

    it "returns nil when description call has no string argument" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false do
            description
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end

    it "reads description from block body" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false do
            description 'The T identifier'
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to eq("The T identifier")
    end

    it "returns nil when the field block body is empty" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false do
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:description_from_block, field)).to be_nil
    end
  end

  describe "#find_graphql_name_declaration" do
    it "returns nil when type body is empty" do
      type_node = parse_source("class T < Base; end").ast
      expect(type_node.body).to be_nil
      expect(concern.__send__(:find_graphql_name_declaration, type_node)).to be_nil
    end

    it "returns nil when module body is empty" do
      type_node = parse_source("module M; end").ast
      expect(type_node.body).to be_nil
      expect(concern.__send__(:find_graphql_name_declaration, type_node)).to be_nil
    end

    it "returns string from graphql_name call" do
      processed = parse_source(<<~RUBY)
        class T < Base
          graphql_name 'Renamed'
        end
      RUBY
      expect(concern.__send__(:find_graphql_name_declaration, processed.ast)).to eq("Renamed")
    end

    it "returns string from graphql_name inside a module" do
      processed = parse_source(<<~RUBY)
        module TaskInterface
          graphql_name 'Task'
        end
      RUBY
      expect(concern.__send__(:find_graphql_name_declaration, processed.ast)).to eq("Task")
    end

    it "returns nil when graphql_name has no string argument" do
      processed = parse_source(<<~RUBY)
        class T < Base
          graphql_name SOME_CONSTANT
        end
      RUBY
      expect(concern.__send__(:find_graphql_name_declaration, processed.ast)).to be_nil
    end

    it "returns nil when type body has no graphql_name send" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, 'x', null: false
        end
      RUBY
      expect(concern.__send__(:find_graphql_name_declaration, processed.ast)).to be_nil
    end
  end

  describe "#type_body_nodes" do
    it "wraps a single statement body in an array" do
      processed = parse_source(<<~RUBY)
        class T < Base
          graphql_name 'X'
        end
      RUBY
      body = processed.ast.body
      expect(concern.__send__(:type_body_nodes, body)).to eq([body])
    end

    it "expands a begin body into children" do
      processed = parse_source(<<~RUBY)
        class T < Base
          graphql_name 'X'
          field :id, ID, 'x', null: false
        end
      RUBY
      body = processed.ast.body
      expect(body.begin_type?).to be(true)
      nodes = concern.__send__(:type_body_nodes, body)
      expect(nodes.size).to eq(2)
    end
  end

  describe "#strip_graphql_suffix" do
    it "strips Type then Interface suffixes" do
      expect(concern.__send__(:strip_graphql_suffix, "EmployeeType")).to eq("Employee")
      expect(concern.__send__(:strip_graphql_suffix, "TaskInterface")).to eq("Task")
      expect(concern.__send__(:strip_graphql_suffix, "Plain")).to eq("Plain")
    end
  end

  describe "#find_graphql_type_name" do
    it "returns nil when class name const is missing" do
      field_node = instance_double(RuboCop::AST::Node)
      # RuboCop::AST::Node is frozen with complex initialization; verified doubles fail
      class_node = double("class_node") # rubocop:disable RSpec/VerifiedDoubles
      allow(class_node).to receive_messages(children: [nil, nil, nil], body: nil)
      allow(field_node).to receive(:each_ancestor).with(:class).and_return([class_node].each)

      expect(concern.__send__(:find_graphql_type_name, field_node)).to be_nil
    end

    it "returns nil when there is no enclosing class" do
      processed = parse_source('field :id, ID, "x", null: false')
      field = processed.ast
      expect(concern.__send__(:find_graphql_type_name, field)).to be_nil
    end

    it "returns graphql_name when present" do
      processed = parse_source(<<~RUBY)
        class T < Base
          graphql_name 'ApiName'
          field :id, ID, 'x', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:find_graphql_type_name, field)).to eq("ApiName")
    end

    it "falls back to Ruby class name" do
      processed = parse_source(<<~RUBY)
        class EmployeeType < BaseObject
          field :id, ID, 'x', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:find_graphql_type_name, field)).to eq("Employee")
    end

    it "uses the enclosing module when there is no class ancestor" do
      processed = parse_source(<<~RUBY)
        module TaskInterface
          field :id, ID, 'The Task identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:find_graphql_type_name, field)).to eq("Task")
    end

    it "prefers class over an outer module when both exist" do
      processed = parse_source(<<~RUBY)
        module Namespace
          class EmployeeType < BaseObject
            field :id, ID, 'The Employee identifier', null: false
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:find_graphql_type_name, field)).to eq("Employee")
    end

    it "reads graphql_name from a module body" do
      processed = parse_source(<<~RUBY)
        module WhoToPayInterface
          graphql_name 'DraftAccountantClientWhoToPay'
          field :id, ID, 'The DraftAccountantClientWhoToPay identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:find_graphql_type_name, field)).to eq("DraftAccountantClientWhoToPay")
    end
  end

  describe "#in_mutation_or_input_object?" do
    it "returns false when class has no superclass node" do
      processed = parse_source(<<~RUBY)
        class Bare
          field :id, ID, 'The Bare identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:in_mutation_or_input_object?, field)).to be(false)
    end

    it "returns false when superclass matches none of mutation/input heuristics" do
      processed = parse_source(<<~RUBY)
        class Q < BaseObject
          field :id, ID, 'The Q identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:in_mutation_or_input_object?, field)).to be(false)
    end

    it "returns true when superclass includes Mutation" do
      processed = parse_source(<<~RUBY)
        class M < BaseMutation
          field :id, ID, 'The M identifier', null: false
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:in_mutation_or_input_object?, field)).to be(true)
    end

    it "returns true when superclass includes InputObject" do
      processed = parse_source(<<~RUBY)
        class I < BaseInputObject
          argument :id, ID, 'The identifier of the I (`I.id`) to filter by', required: true
        end
      RUBY
      arg = processed.ast.each_node(:send).find { |n| n.method?(:argument) }
      expect(concern.__send__(:in_mutation_or_input_object?, arg)).to be(true)
    end

    it "returns true when superclass name ends with Input but has no InputObject substring" do
      processed = parse_source(<<~RUBY)
        class I < Foo::LedgerInput
          argument :id, ID, 'The identifier of the I (`I.id`) to update', required: true
        end
      RUBY
      arg = processed.ast.each_node(:send).find { |n| n.method?(:argument) }
      expect(concern.__send__(:in_mutation_or_input_object?, arg)).to be(true)
    end

    it "returns false when the superclass only contains a mutation/input word mid-name" do
      # Suffix match, not substring: `MutationHelper` ends in "Helper", so it is not a mutation.
      processed = parse_source(<<~RUBY)
        class T < Foo::MutationHelper
          argument :id, ID, 'Bad', required: true
        end
      RUBY
      arg = processed.ast.each_node(:send).find { |n| n.method?(:argument) }
      expect(concern.__send__(:in_mutation_or_input_object?, arg)).to be(false)
    end
  end

  describe "#extract_description" do
    it "prefers positional string over keyword and block" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, 'Positional', null: false, description: 'Keyword' do
            description 'Block'
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:extract_description, field)).to eq("Positional")
    end

    it "uses keyword when positional is absent" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false, description: 'Keyword only'
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:extract_description, field)).to eq("Keyword only")
    end

    it "uses block when positional and keyword are absent" do
      processed = parse_source(<<~RUBY)
        class T < Base
          field :id, ID, null: false do
            description 'From block'
          end
        end
      RUBY
      field = processed.ast.each_node(:send).find { |n| n.method?(:field) }
      expect(concern.__send__(:extract_description, field)).to eq("From block")
    end
  end

  describe "#description_from_keyword_argument" do
    it "skips non-hash arguments" do
      processed = parse_source("argument :id, ID, required: true").ast
      expect(concern.__send__(:description_from_keyword_argument, processed)).to be_nil
    end

    it "skips pairs that are not description string" do
      processed = parse_source("field :id, ID, null: false, resolver: R").ast
      expect(concern.__send__(:description_from_keyword_argument, processed)).to be_nil
    end
  end
end
