# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::SuddenAssociations, :config do
  it "registers an offense when defining has_one on another class" do
    expect_offense(<<~RUBY)
      Company.has_one :onboarding_benefits_survey
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense when defining has_many on another class" do
    expect_offense(<<~RUBY)
      User.has_many :posts
      ^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense when defining belongs_to on another class" do
    expect_offense(<<~RUBY)
      Post.belongs_to :user
      ^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense when defining has_and_belongs_to_many on another class" do
    expect_offense(<<~RUBY)
      Student.has_and_belongs_to_many :courses
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense when defining association on a namespaced constant" do
    expect_offense(<<~RUBY)
      MyModule::Company.has_one :onboarding_benefits_survey
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense when defining association with :: prefix" do
    expect_offense(<<~RUBY)
      ::Company.has_one :onboarding_benefits_survey
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense with association options" do
    expect_offense(<<~RUBY)
      Company.has_one :onboarding_benefits_survey, dependent: :destroy
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "registers an offense with association options and class_name" do
    expect_offense(<<~RUBY)
      User.belongs_to :company, class_name: "Organization"
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end

  it "does not register an offense when defining association within class body" do
    expect_no_offenses(<<~RUBY)
      class Company
        has_one :onboarding_benefits_survey
      end
    RUBY
  end

  it "does not register an offense when defining multiple associations within class body" do
    expect_no_offenses(<<~RUBY)
      class User
        has_many :posts
        belongs_to :company
        has_one :profile
      end
    RUBY
  end

  it "does not register an offense for association methods without a constant receiver" do
    expect_no_offenses(<<~RUBY)
      def some_method
        has_one :something
      end
    RUBY
  end

  it "does not register an offense when calling on a variable" do
    expect_no_offenses(<<~RUBY)
      klass = Company
      klass.has_one :onboarding_benefits_survey
    RUBY
  end

  it "does not register an offense when calling on self" do
    expect_no_offenses(<<~RUBY)
      class Company
        self.has_one :onboarding_benefits_survey
      end
    RUBY
  end

  it "does not register an offense for method calls on instances" do
    expect_no_offenses(<<~RUBY)
      company = Company.new
      company.has_one :something
    RUBY
  end

  it "does not register an offense for unrelated methods on constants" do
    expect_no_offenses(<<~RUBY)
      Company.find(1)
      User.where(name: "John")
    RUBY
  end

  # Edge cases
  it "registers an offense in a module context" do
    expect_offense(<<~RUBY)
      module MyModule
        Company.has_one :onboarding_benefits_survey
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
      end
    RUBY
  end

  it "registers an offense in a method context" do
    expect_offense(<<~RUBY)
      def setup_associations
        Company.has_one :onboarding_benefits_survey
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
      end
    RUBY
  end

  it "does not register an offense when called without a receiver inside a class" do
    expect_no_offenses(<<~RUBY)
      class Company
        has_one :onboarding_benefits_survey
        belongs_to :parent
      end
    RUBY
  end

  it "registers multiple offenses when multiple associations are defined externally" do
    expect_offense(<<~RUBY)
      Company.has_one :survey
      ^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
      User.belongs_to :company
      ^^^^^^^^^^^^^^^^^^^^^^^^ Do not define Rails associations on another class. Associations should only be defined within the class body of their model.
    RUBY
  end
end
