# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::HardcodedId, :config do
  it "registers an offense for a hardcoded id: on a factory create" do
    expect_offense(<<~RUBY)
      create(:company, id: 123)
                       ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for a hardcoded id: with no factory argument" do
    expect_offense(<<~RUBY)
      create(id: 123)
             ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for id: on a create with an explicit receiver" do
    expect_offense(<<~RUBY)
      Company.create(id: 123)
                     ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for id: alongside other keyword arguments" do
    expect_offense(<<~RUBY)
      create(:company, name: 'Acme', id: 123)
                                     ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for id: passed via safe navigation" do
    expect_offense(<<~RUBY)
      model&.create(id: 123)
                    ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for a hardcoded id: on create!" do
    expect_offense(<<~RUBY)
      Company.create!(id: 123)
                      ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for a string literal id:" do
    expect_offense(<<~RUBY)
      create(:company, id: '123456789')
                       ^^^^^^^^^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for id: on create_list" do
    expect_offense(<<~RUBY)
      create_list(:company, 3, id: 123)
                               ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "registers an offense for a string 'id' hash-rocket key" do
    expect_offense(<<~RUBY)
      create(:company, 'id' => 123)
                       ^^^^^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
    RUBY
  end

  it "does not register an offense for create without an id:" do
    expect_no_offenses(<<~RUBY)
      create(:company)
    RUBY
  end

  it "does not register an offense for other keyword arguments" do
    expect_no_offenses(<<~RUBY)
      create(:company, name: 'Acme')
    RUBY
  end

  it "does not register an offense for a nested id: on a different builder" do
    expect_no_offenses(<<~RUBY)
      create(:company, owner: build(:user, id: 5))
    RUBY
  end

  it "does not register an offense for create_list without an id:" do
    expect_no_offenses(<<~RUBY)
      create_list(:company, 3)
    RUBY
  end

  it "does not register an offense for id: on non-persisting builders" do
    expect_no_offenses(<<~RUBY)
      build(:company, id: 123)
    RUBY
  end

  it "does not register an offense for id: on build_list" do
    expect_no_offenses(<<~RUBY)
      build_list(:company, 3, id: 123)
    RUBY
  end

  it "does not register an offense for a reference id: from a local variable" do
    expect_no_offenses(<<~RUBY)
      create(:employee, id: company_id)
    RUBY
  end

  it "does not register an offense for a reference id: read from another record" do
    expect_no_offenses(<<~RUBY)
      create(:employee, id: company.id)
    RUBY
  end

  it "does not register an offense for a bare create with no arguments" do
    expect_no_offenses(<<~RUBY)
      create
    RUBY
  end

  context "with AllowedFactories" do
    let(:cop_config) { { "AllowedFactories" => ["money"] } }

    it "does not register an offense for an allowed factory" do
      expect_no_offenses(<<~RUBY)
        create(:money, :usd, id: 123)
      RUBY
    end

    it "still registers an offense for a factory that is not allowed" do
      expect_offense(<<~RUBY)
        create(:company, id: 123)
                         ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
      RUBY
    end
  end

  context "with AllowedReceivers" do
    let(:cop_config) { { "AllowedReceivers" => ["Reporting::Row"] } }

    it "does not register an offense for an allowed receiver" do
      expect_no_offenses(<<~RUBY)
        Reporting::Row.create(id: 3, label: 'total')
      RUBY
    end

    it "does not register an offense for the same receiver with a leading scope operator" do
      expect_no_offenses(<<~RUBY)
        ::Reporting::Row.create(id: 3)
      RUBY
    end

    it "still registers an offense for a receiver that is not allowed" do
      expect_offense(<<~RUBY)
        Company.create(id: 123)
                       ^^^^^^^ Do not pass a hardcoded `id:` to `create`/`create!`/`create_list`; let the database assign it.
      RUBY
    end
  end
end
