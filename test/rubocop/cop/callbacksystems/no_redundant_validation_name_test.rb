require "test_helper"

class RuboCop::Cop::Callbacksystems::NoRedundantValidationNameTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::NoRedundantValidationName

  test "reports a validate prefix on the registered callback" do
    offenses = assert_offense <<~RUBY
      class Invoice < ApplicationRecord
        validate :validate_total
      end
    RUBY

    assert_equal ":validate_total", offenses.first.location.source
    assert_includes offenses.first.message, "Name the condition"
  end

  test "reports a valid prefix" do
    assert_offense <<~RUBY
      validate :valid_membership
    RUBY
  end

  test "reports each redundant callback while leaving options alone" do
    assert_offense <<~RUBY, count: 2
      validate :validate_email, :no_expired_membership, :valid_total, if: :valid_account?, on: :validate_import
    RUBY
  end

  test "reports explicitly registered callbacks on self" do
    assert_offense <<~RUBY
      self.validate :validate_total
    RUBY
  end

  test "reports safe navigation on self" do
    assert_offense <<~RUBY
      self&.validate :valid_total
    RUBY
  end

  test "reports callbacks registered in a concern" do
    assert_offense <<~RUBY
      module Billable
        extend ActiveSupport::Concern

        included do
          validate :validate_balance
        end
      end
    RUBY
  end

  test "reports bare validation names and predicate or bang suffixes" do
    assert_offense <<~RUBY, count: 6
      validate :valid, :validate, :valid?, :validate?, :valid!, :validate!
    RUBY
  end

  test "leaves descriptive conditions alone" do
    assert_no_offense <<~RUBY
      validate :ensure_deliverable_email, :no_expired_membership, :expiration_date_cannot_be_in_the_past
      validate :validity_period_has_not_expired, :validated_token_is_current, :invalid_state_is_rejected
    RUBY
  end

  test "leaves validation predicates in options alone" do
    assert_no_offense <<~RUBY
      validate :ensure_positive_total, if: :valid_account?, unless: :validate_later?, on: :validate_import
    RUBY
  end

  test "leaves attribute validators and other callbacks alone" do
    assert_no_offense <<~RUBY
      validates :valid_total, presence: true
      before_save :validate_total
    RUBY
  end

  test "leaves callback names on other receivers alone" do
    assert_no_offense <<~RUBY
      schema.validate :valid_total
      schema&.validate :validate_total
    RUBY
  end

  test "leaves method calls inside instance and singleton methods alone" do
    assert_no_offense <<~RUBY
      def process
        validate :valid_total
      end

      def self.process
        validate :validate_total
      end
    RUBY
  end

  test "leaves blocks dynamic callbacks and validator objects alone" do
    assert_no_offense <<~'RUBY'
      validate
      validate { errors.add(:base, "invalid") }
      validate callback_name
      validate :"validate_#{attribute}"
      validate DeliveryValidator.new
      validate *callbacks
      validate "validate_total"
    RUBY
  end

  test "does not invent a replacement or rename the method" do
    assert_uncorrectable_offense <<~RUBY
      class Invoice < ApplicationRecord
        validate :validate_total

        private
          def validate_total
            errors.add(:total, "must be positive") unless total.positive?
          end
      end
    RUBY
  end
end
