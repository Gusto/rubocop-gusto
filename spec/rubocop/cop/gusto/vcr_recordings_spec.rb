# frozen_string_literal: true

RSpec.describe(RuboCop::Cop::Gusto::VcrRecordings, :config) do
  it('registers an offense when VCR is set to record') do
    expect_offense(<<~RUBY)
      describe 'some test' do
        it 'does something', vcr: { record: :new_episodes } do
                                    ^^^^^^^^^^^^^^^^^^^^^ VCR should be set to not record in tests. Please use vcr: {record: :none}.
          # test code
        end
      end
    RUBY
  end

  it('does not register an offense when VCR is set to not record') do
    expect_no_offenses(<<~RUBY)
      describe 'some test' do
        it 'does something', vcr: { record: :none } do
          # test code
        end
      end
    RUBY
  end

  it('does not register an offense when VCR is not mentioned') do
    expect_no_offenses(<<~RUBY)
      describe 'some test' do
        it 'does something' do
          # test code
        end
      end

      {}
      { record: :none }
      { abc: { record: :none } }
    RUBY
  end

  it('registers an offense for other VCR recording modes') do
    expect_offense(<<~RUBY)
      describe 'some test' do
        it 'does something', vcr: { record: :once } do
                                    ^^^^^^^^^^^^^ VCR should be set to not record in tests. Please use vcr: {record: :none}.
          # test code
        end
      end
    RUBY
  end

  it('does not register an offense for other VCR options') do
    expect_no_offenses(<<~RUBY)
      describe 'some test' do
        it 'does something', vcr: { match_requests_on: [:method, :host, :path] } do
          # test code
        end
      end
    RUBY
  end

  describe('autocorrect') do
    it('corrects VCR recording mode to :none') do
      expect_offense(<<~RUBY)
        describe 'some test' do
          it 'does something', vcr: { record: :once } do
                                      ^^^^^^^^^^^^^ VCR should be set to not record in tests. Please use vcr: {record: :none}.
            # test code
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        describe 'some test' do
          it 'does something', vcr: { record: :none } do
            # test code
          end
        end
      RUBY
    end

    it('corrects VCR recording mode to :none when other options are present') do
      expect_offense(<<~RUBY)
        describe 'some test' do
          it 'does something', vcr: { record: :once, match_requests_on: [:method, :host] } do
                                      ^^^^^^^^^^^^^ VCR should be set to not record in tests. Please use vcr: {record: :none}.
            # test code
          end
        end
      RUBY

      expect_correction(<<~RUBY)
        describe 'some test' do
          it 'does something', vcr: { record: :none, match_requests_on: [:method, :host] } do
            # test code
          end
        end
      RUBY
    end
  end
end
