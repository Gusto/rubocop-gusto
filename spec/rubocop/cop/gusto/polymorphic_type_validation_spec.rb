# typed: false
# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::PolymorphicTypeValidation, :config do
  context "when there is no belongs_to" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyModel < ApplicationRecord
          validates :name, presence: true
        end
      RUBY
    end
  end

  context "when there is a non-polymorphic belongs_to" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyModel < ApplicationRecord
          belongs_to :user
        end
      RUBY
    end
  end

  context "when there is a polymorphic belongs_to with proper validation" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyModel < ApplicationRecord
          belongs_to :polymorphic_relation, polymorphic: true
          validates :polymorphic_relation_type, inclusion: { in: %w[User Post] }
        end
      RUBY
    end
  end

  context "when there is a polymorphic belongs_to using polymorphic_methods_for" do
    it "does not register an offense" do
      expect_no_offenses(<<~RUBY)
        class MyModel < ApplicationRecord
          belongs_to :polymorphic_relation, polymorphic: true
          polymorphic_methods_for :polymorphic_relation, types: %w[User Post]
        end
      RUBY
    end
  end

  context "when there is a polymorphic belongs_to without validation" do
    it "registers an offense with the main message" do
      source = <<~RUBY
        class MyModel < ApplicationRecord
          belongs_to :polymorphic_relation, polymorphic: true
        end
      RUBY
      offenses = inspect_source(source)
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include(
        'Polymorphic relations must validate their corresponding type field with "validates .. inclusion: { in: .. }", or using polymorphic_methods_for'
      )
    end
  end

  context "when there is a polymorphic belongs_to with wrong validation" do
    it "registers an offense with the main message" do
      source = <<~RUBY
        class MyModel < ApplicationRecord
          belongs_to :polymorphic_relation, polymorphic: true
          validates :polymorphic_relation_type, presence: true
        end
      RUBY
      offenses = inspect_source(source)
      expect(offenses.size).to eq(1)
      expect(offenses.first.message).to include(
        'Polymorphic relations must validate their corresponding type field with "validates .. inclusion: { in: .. }", or using polymorphic_methods_for'
      )
    end
  end

  context "with allow_blank: true" do
    shared_examples_for "registers an offense with the allow_blank message" do
      it "registers an offense with the allow_blank message" do
        offenses = inspect_source(source)
        expect(offenses.size).to eq(1)
        expect(offenses.first.message).to include(
          "Polymorphic type validations cannot use allow_blank: true"
        )
      end
    end

    context "when there is a non-polymorphic belongs_to" do
      it "does not register an offense" do
        expect_no_offenses(<<~RUBY)
          class MyModel < ApplicationRecord
            belongs_to :user, optional: true
            validates :user_id, presence: true, allow_blank: true
          end
        RUBY
      end
    end

    context "when there is a polymorphic belongs_to" do
      let(:source) do
        <<~RUBY
          class MyModel < ApplicationRecord
            belongs_to :polymorphic_relation, polymorphic: true
            validates :polymorphic_relation_type, inclusion: { in: %w[User Post] }, allow_blank: true
          end
        RUBY
      end

      it_behaves_like "registers an offense with the allow_blank message"
    end

    context "when there is a polymorphic belongs_to with optional: true" do
      let(:source) do
        <<~RUBY
          class MyModel < ApplicationRecord
            belongs_to :polymorphic_relation, polymorphic: true, optional: true
            validates :polymorphic_relation_type, allow_blank: true, inclusion: { in: %w[User Post] }
          end
        RUBY
      end

      it_behaves_like "registers an offense with the allow_blank message"
    end

    context "when there is a polymorphic belongs_to with presence: true" do
      let(:source) do
        <<~RUBY
          class MyModel < ApplicationRecord
            belongs_to :polymorphic_relation, polymorphic: true
            validates :polymorphic_relation_type, presence: true, allow_blank: true, inclusion: { in: %w[User Post] }
          end
        RUBY
      end

      it_behaves_like "registers an offense with the allow_blank message"
    end

    context "when allow_blank is inside the inclusion" do
      let(:source) do
        <<~RUBY
          class MyModel < ApplicationRecord
            belongs_to :polymorphic_relation, polymorphic: true
            validates :polymorphic_relation_type, inclusion: { in: %w[User Post], allow_blank: true }
          end
        RUBY
      end

      it_behaves_like "registers an offense with the allow_blank message"
    end
  end
end
