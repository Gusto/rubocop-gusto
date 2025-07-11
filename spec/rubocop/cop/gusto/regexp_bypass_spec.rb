# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::RegexpBypass, :config do
  context 'when using ^' do
    it 'adds offense' do
      expect_offense(<<~RUBY)
        regex = /^some/
                 ^^^^^ Regular expressions matching a single line [...]
      RUBY
    end

    context 'when using ^ in a capturing group' do
      it('adds offense') do
        expect_offense(<<~RUBY)
          regex = /(^some)/
                   ^^^^^^^ Regular expressions matching a single line [...]
        RUBY
      end
    end

    context 'with multiline option' do
      it 'does not add offense' do
        expect_no_offenses(<<~RUBY)
          regex = /^some/mi
        RUBY
      end
    end
  end

  context 'when using $' do
    it 'adds offense' do
      expect_offense(<<~RUBY)
        regex = /some$/
                 ^^^^^ Regular expressions matching a single line [...]
      RUBY
    end

    context 'with multiline option' do
      it 'does not add offense' do
        expect_no_offenses(<<~RUBY)
          regex = /some$/m
        RUBY
      end
    end
  end

  context 'when regexp has only options and no pattern' do
    it 'does not add offense' do
      expect_no_offenses(<<~RUBY)
        regex = //i
      RUBY
    end
  end

  context 'when using both ^ and $' do
    it 'adds offense for the whole range' do
      expect_offense(<<~RUBY)
        regex = /^some$/
                 ^^^^^^ Regular expressions matching a single line [...]
      RUBY
    end
  end

  context 'when using ^ or $ in the middle' do
    it 'does not add offense' do
      expect_no_offenses(<<~RUBY)
        regex = /some^thing/
        /foo$bar/
      RUBY
    end
  end

  context 'when using ^ for negation' do
    it 'does not add offense' do
      expect_no_offenses(<<~RUBY)
        regex = /[^some]/
      RUBY
    end
  end

  context 'when using multiline option with different placements' do
    it 'does not add offense when m option is at the end' do
      expect_no_offenses(<<~RUBY)
        regex = /^some$/m
      RUBY
    end

    it 'does not add offense when m option is combined with other options' do
      expect_no_offenses(<<~RUBY)
        regex = /^some$/im
      RUBY
    end
  end

  context 'when regexp is blank' do
    it 'does not add offense' do
      expect_no_offenses(<<~RUBY)
        regex = //
        regex2 = %r{}i
        regex = Regexp.new('')
      RUBY
    end
  end

  context 'when there is no regexp present' do
    it 'does not add offense' do
      expect_no_offenses(<<~RUBY)
        regex = "actually_a_string"
      RUBY
    end
  end

  context 'when completing branch coverage for guard clauses that might be impossible in normal parsing' do
    context 'when regexp has no source' do
      it 'does not add offense' do
        # We need to mock the AST node to simulate a regexp without source
        regexp_node = instance_double(RuboCop::AST::RegexpNode)
        allow(regexp_node).to receive(:children).and_return([])

        # Create a processed source with our mocked node
        processed_source = instance_double(RuboCop::ProcessedSource)
        allow(processed_source).to receive(:ast).and_return(regexp_node)

        # Create an instance of our cop
        cop = described_class.new

        # Mock the add_offense method to allow message spying
        allow(cop).to receive(:add_offense)

        # Call on_regexp to verify our expectation
        cop.on_regexp(regexp_node)

        # Assert that the cop didn't try to add an offense
        expect(cop).not_to have_received(:add_offense)
      end
    end

    context 'when regopt exists but has no source' do
      it 'does not add offense' do
        # Set up dummy content
        initial_content = "# This is a dummy 2 line string\n/regex/"

        # Create a processed source with our content
        processed_source = RuboCop::ProcessedSource.new(initial_content, RUBY_VERSION.to_f)

        # Mock the RegexpNode
        regexp_node = instance_double(RuboCop::AST::RegexpNode)

        # Mock a regopt with no source
        regopt = instance_double(RuboCop::AST::RegexpNode)
        allow(regopt).to receive(:source).and_return(nil)

        # Set up the regexp_node to return our mocked regopt
        allow(regexp_node).to receive(:children).and_return([regopt])

        # Create an instance of our cop
        cop = described_class.new(config)

        # Create a team with only our cop
        team = RuboCop::Cop::Team.new([cop], config, raise_error: true)

        # Run the investigation
        report, = team.investigate(processed_source)

        # Expect no offenses to be added
        expect(report.offenses).to be_empty
      end
    end
  end

  it 'autocorrects ^ to \A at the start of a pattern' do
    expect_offense(<<~RUBY)
      /^foo/
       ^^^^ Regular expressions matching a single line [...]
    RUBY

    expect_correction(<<~RUBY)
      /\\Afoo/
    RUBY
  end

  it 'autocorrects $ to \z at the end of a pattern' do
    expect_offense(<<~RUBY)
      /foo$/
       ^^^^ Regular expressions matching a single line [...]
    RUBY

    expect_correction(<<~RUBY)
      /foo\\z/
    RUBY
  end

  it 'autocorrects both ^ and $ in the same pattern' do
    expect_offense(<<~RUBY)
      /^foo$/
       ^^^^^ Regular expressions matching a single line [...]
    RUBY

    expect_correction(<<~RUBY)
      /\\Afoo\\z/
    RUBY
  end

  it 'does not autocorrect when multiline mode is enabled' do
    expect_no_offenses(<<~RUBY)
      /^foo$/m
    RUBY
  end

  it 'handles patterns with escaped characters' do
    expect_offense(<<~'RUBY')
      /^foo\sbar$/
       ^^^^^^^^^^ Regular expressions matching a single line [...]
    RUBY

    expect_correction(<<~'RUBY')
      /\Afoo\sbar\z/
    RUBY
  end
end
