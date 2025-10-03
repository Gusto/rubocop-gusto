# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::UsePaintNotColorize, :config do
  # This cop has SafeAutoCorrect: false because the autocorrection replaces
  # colorize gem methods with Paint gem methods. If the Paint gem is not
  # included in the project's dependencies, the corrected code will fail at
  # runtime with a NameError.

  it "registers an offense for basic color methods" do
    expect_offense(<<~RUBY)
      "string".cyan
      ^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :cyan]
    RUBY
  end

  it "registers an offense for color methods on interpolated strings" do
    expect_offense(<<~'RUBY')
      ring = 'ring'
      "st#{ring}".cyan
      ^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~'RUBY')
      ring = 'ring'
      Paint["st#{ring}", :cyan]
    RUBY
  end

  it "registers an offense for color methods on complex interpolated strings" do
    expect_offense(<<~'RUBY')
      "#{(1 + 2).to_s} items remaining".red
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~'RUBY')
      Paint["#{(1 + 2).to_s} items remaining", :red]
    RUBY
  end

  it "registers an offense for color methods on nested complex interpolated strings" do
    expect_offense(<<~'RUBY')
      "#{(Const.call.length || 0)} more".cyan
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~'RUBY')
      Paint["#{(Const.call.length || 0)} more", :cyan]
    RUBY
  end

  it "registers an offense for color methods on interpolated expressions in strings" do
    expect_offense(<<~'RUBY')
      ring = 'ring'
      "st#{ring.upcase}".cyan
      ^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~'RUBY')
      ring = 'ring'
      Paint["st#{ring.upcase}", :cyan]
    RUBY
  end

  it "registers an offense for light color methods" do
    expect_offense(<<~RUBY)
      "string".light_red
      ^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :bright, :red]
    RUBY
  end

  it "registers an offense for background color methods" do
    expect_offense(<<~RUBY)
      "string".on_blue
      ^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", nil, :blue]
    RUBY
  end

  it "registers an offense for colorize method" do
    expect_offense(<<~RUBY)
      "string".colorize(:red)
      ^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :red]
    RUBY
  end

  it "registers an offense for colorize with hash arguments" do
    expect_offense(<<~RUBY)
      "string".colorize(:color => :blue)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :blue]
    RUBY
  end

  it "registers an offense for colorize with color and background" do
    expect_offense(<<~RUBY)
      "string".colorize(:color => :green, :background => :red)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :green, :red]
    RUBY
  end

  it "registers an offense for colorize with mode" do
    expect_offense(<<~RUBY)
      "string".colorize(:color => :green, :mode => :bold)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :green, :bold]
    RUBY
  end

  it "registers an offense for blue color" do
    expect_offense(<<~RUBY)
      "string".blue
      ^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :blue]
    RUBY
  end

  it "registers an offense for chained methods including a non colorize method" do
    expect_offense(<<~RUBY)
      "string".downcase.blue
      ^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string".downcase, :blue]
    RUBY
  end

  it "registers an offense for on_red color" do
    expect_offense(<<~RUBY)
      "string".on_red
      ^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", nil, :red]
    RUBY
  end

  it "registers an offense for underline style" do
    expect_offense(<<~RUBY)
      "string".underline
      ^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint["string", :underline]
    RUBY
  end

  it "registers an offense for uncolorize method" do
    expect_offense(<<~RUBY)
      "string".uncolorize
      ^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      Paint.unpaint("string")
    RUBY
  end

  it "registers an offense for uncolorize method on variables" do
    expect_offense(<<~RUBY)
      str = "hello"
      str.uncolorize
      ^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      str = "hello"
      Paint.unpaint(str)
    RUBY
  end

  it "registers an offense for uncolorize method on interpolated strings" do
    expect_offense(<<~'RUBY')
      "#{user.name}'s profile".uncolorize
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~'RUBY')
      Paint.unpaint("#{user.name}'s profile")
    RUBY
  end

  it "registers an offense for string variables" do
    expect_offense(<<~RUBY)
      str = "hello"
      str.cyan
      ^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_correction(<<~RUBY)
      str = "hello"
      Paint[str, :cyan]
    RUBY
  end

  it "registers an offense but does not correct colorize with no arguments" do
    expect_offense(<<~RUBY)
      "string".colorize
      ^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_no_corrections
  end

  it "registers an offense but does not correct colorize with non-symbol arguments" do
    expect_offense(<<~RUBY)
      "string".colorize(background: "blue")
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_no_corrections
  end

  it "registers an offense but does not correct colorize with unknown key" do
    expect_offense(<<~RUBY)
      "string".colorize(unknown: :blue)
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_no_corrections
  end

  it "registers an offense but does not correct safe navigation" do
    expect_offense(<<~RUBY)
      str = nil
      str&.colorize(background: :blue)&.cyan
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Use Paint instead of colorize for terminal colors.
    RUBY

    expect_no_corrections
  end

  it "does not register an offense for plain strings" do
    expect_no_offenses(<<~RUBY)
      "string"
      'another string'
    RUBY
  end

  it "does not register an offense for non-string receivers" do
    expect_no_offenses(<<~RUBY)
      object.cyan
      variable.red
      123.green
    RUBY
  end

  it "does not register an offense for non-color methods on strings" do
    expect_no_offenses(<<~RUBY)
      "string".upcase
      "string".downcase
      "string".strip
    RUBY
  end

  it "does not register an offense for nil receiver" do
    expect_no_offenses(<<~RUBY)
      cyan
      red
      green
    RUBY
  end
end
