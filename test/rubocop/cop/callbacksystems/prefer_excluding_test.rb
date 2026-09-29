require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferExcludingTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferExcluding

  test "quotes an element taken from a percent literal" do
    assert_correction <<~BAD, <<~GOOD
      names = %w[ one two ] - %w[one]
    BAD
      names = %w[ one two ].excluding("one")
    GOOD
  end

  test "keeps a symbol element taken from a percent literal" do
    assert_correction <<~BAD, <<~GOOD
      names = %i[ one two ] - %i[one]
    BAD
      names = %i[ one two ].excluding(:one)
    GOOD
  end

  test "registers offense for array minus single element array" do
    assert_offense <<~RUBY
      users - [admin]
    RUBY
  end

  test "autocorrects to excluding" do
    assert_correction "[ 1, 2 ] - [1]", "[ 1, 2 ].excluding(1)"
  end

  test "leaves an unknown receiver and element for a human" do
    assert_uncorrectable_offense "users.active - [admin]"
  end

  test "leaves a lone parameter receiver for a human" do
    assert_uncorrectable_offense <<~RUBY
      def filtered(users)
        users - [:admin]
      end
    RUBY
  end

  test "leaves a parameter receiver in the first statement for a human" do
    assert_uncorrectable_offense <<~RUBY
      def filtered(users)
        users - [:admin]
        nil
      end
    RUBY
  end

  test "autocorrects an adjacent local known to hold an Array" do
    assert_correction <<~BAD, <<~GOOD
      users = Array.new
      users - [:admin]
    BAD
      users = Array.new
      users.excluding(:admin)
    GOOD
  end

  test "autocorrects while preserving safe navigation on a known Array" do
    assert_correction <<~BAD, <<~GOOD
      users = []
      users&.-([:admin])
    BAD
      users = []
      users&.excluding(:admin)
    GOOD
  end

  test "leaves a complex element for a human because it may itself be an Array" do
    assert_uncorrectable_offense "[ 1, 2 ] - [items.first]"
  end

  test "leaves a nested array for a human because excluding would flatten it" do
    assert_uncorrectable_offense "[ [ entry ] ] - [[entry]]"
  end

  test "leaves an Array-valued local for a human because excluding would flatten it" do
    assert_uncorrectable_offense <<~RUBY
      entry = [ 1 ]
      [ entry ] - [entry]
    RUBY
  end

  test "leaves a known Set receiver for a human because Enumerable excluding changes its result type" do
    assert_uncorrectable_offense <<~RUBY
      items = Set.new
      items - [:entry]
    RUBY
  end

  test "leaves a correction carrying a comment for a human" do
    assert_uncorrectable_offense <<~RUBY
      [ 1, 2 ] - [
        1 # The sentinel is intentional.
      ]
    RUBY
  end

  test "leaves an interpolated percent word for a human because it has no standalone source" do
    assert_uncorrectable_offense <<~'RUBY'
      items - %W[#{entry}]
    RUBY
  end

  test "leaves an interpolated percent symbol for a human instead of reading a missing literal value" do
    assert_uncorrectable_offense <<~'RUBY'
      items - %I[#{entry}]
    RUBY
  end

  test "does not register offense for multi-element array" do
    assert_no_offense <<~RUBY
      users - [admin, guest]
    RUBY
  end

  test "does not register offense for empty array" do
    assert_no_offense <<~RUBY
      users - []
    RUBY
  end

  test "does not register offense for variable subtraction" do
    assert_no_offense <<~RUBY
      users - excluded
    RUBY
  end

  test "does not register offense for numeric subtraction" do
    assert_no_offense <<~RUBY
      total - 1
    RUBY
  end

  test "suggests excluding a record from a relation for human review" do
    offenses = assert_uncorrectable_offense "User.where.not(id: user.id)"

    assert_includes offenses.first.message, "excluding(user)"
  end

  test "suggests excluding a record from an association" do
    assert_uncorrectable_offense "account.users.where.not(id: user.id)"
  end

  test "accepts an explicit string id key" do
    assert_uncorrectable_offense 'User.where.not("id" => user.id)'
  end

  test "suggests excluding in an implicit model scope" do
    assert_uncorrectable_offense <<~RUBY
      class User < ApplicationRecord
        scope :other_than, ->(user) { where.not(id: user.id) }
      end
    RUBY
  end

  test "accepts an explicitly configured default primary key" do
    assert_uncorrectable_offense <<~RUBY
      class User < ApplicationRecord
        self.primary_key = "id"
      end
      User.where.not(id: ::User.find(1).id)
    RUBY
  end

  test "keeps relation exclusion comments for human review" do
    assert_uncorrectable_offense <<~RUBY
      User.where.not(
        id: user.id # This user already has access.
      )
    RUBY
  end

  test "does not change relation exclusion source" do
    assert_no_correction "User.where.not(id: user.id)"
  end

  test "leaves visibly different models alone" do
    assert_no_offense "User.active.where.not(id: Account.find(1).id)"
  end

  test "leaves an adjacent local assigned a different model alone" do
    assert_no_offense <<~RUBY
      account = Account.find(1)
      User.where.not(id: account.id)
    RUBY
  end

  test "leaves an adjacent nil record alone" do
    assert_no_offense <<~RUBY
      user = nil
      User.where.not(id: user.id)
    RUBY
  end

  test "leaves a class object in place of a record alone" do
    assert_no_offense "User.where.not(id: Account.id)"
  end

  test "leaves a literal receiver alone" do
    assert_no_offense "[].where.not(id: user.id)"
  end

  test "leaves a nil record alone" do
    assert_no_offense "User.where.not(id: nil.id)"
  end

  test "leaves a safe navigation id read alone" do
    assert_no_offense "User.where.not(id: user&.id)"
  end

  test "leaves safe navigation in an association chain alone" do
    assert_no_offense "account&.users.where.not(id: user.id)"
  end

  test "leaves a safe navigation where chain alone" do
    assert_no_offense "users&.where&.not(id: user.id)"
  end

  test "leaves an implicit id read alone" do
    assert_no_offense "User.where.not(id: id)"
  end

  test "leaves compound negative conditions alone" do
    assert_no_offense "User.where.not(id: user.id, active: false)"
  end

  test "leaves association id conditions alone" do
    assert_no_offense "User.where.not(account_id: account.id)"
  end

  test "leaves unrelated hash conditions alone" do
    assert_no_offense "User.where.not(id: user.uuid)"
  end

  test "leaves arrays of record ids alone" do
    assert_no_offense "User.where.not(id: [ user.id, admin.id ])"
  end

  test "leaves a custom primary key alone" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        self.primary_key = :uuid
      end
      User.where.not(id: user.id)
    RUBY
  end

  test "leaves a composite primary key alone" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        self.primary_key = [ :account_id, :user_id ]
      end
      User.where.not(id: user.id)
    RUBY
  end

  test "leaves an overridden primary key getter alone" do
    assert_no_offense <<~RUBY
      class User < ApplicationRecord
        def self.primary_key = configured_key
      end
      User.where.not(id: user.id)
    RUBY
  end
end
