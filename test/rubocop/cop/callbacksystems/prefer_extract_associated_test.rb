require "test_helper"

class RuboCop::Cop::Callbacksystems::PreferExtractAssociatedTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::PreferExtractAssociated

  test "registers offense for mapping the preloaded association" do
    assert_offense "posts.preload(:author).map(&:author)", file: "app/models/post.rb"
  end

  test "autocorrects mapping the preloaded association" do
    assert_correction \
      "posts.preload(:author).map(&:author)",
      "posts.extract_associated(:author)",
      file: "app/models/post.rb"
  end

  test "autocorrects collecting the preloaded association" do
    assert_correction \
      "memberships.preload(:user).collect(&:user)",
      "memberships.extract_associated(:user)",
      file: "app/models/membership.rb"
  end

  test "autocorrects an implicit model receiver" do
    assert_correction \
      "preload(:author).map(&:author)",
      "extract_associated(:author)",
      file: "app/models/post.rb"
  end

  test "preserves safe navigation through the entire chain" do
    assert_correction \
      "posts&.preload(:author)&.map(&:author)",
      "posts&.extract_associated(:author)",
      file: "app/models/post.rb"
  end

  test "preserves an unguarded receiver when only map uses safe navigation" do
    assert_correction \
      "posts.preload(:author)&.map(&:author)",
      "posts.extract_associated(:author)",
      file: "app/models/post.rb"
  end

  test "keeps comments for human review" do
    assert_uncorrectable_offense <<~RUBY, file: "app/models/post.rb"
      posts.preload(
        :author # Authors are needed for the export.
      ).map(&:author)
    RUBY
  end

  test "leaves a guarded preload followed by an unguarded map alone" do
    assert_no_offense "posts&.preload(:author).map(&:author)", file: "app/models/post.rb"
  end

  test "leaves a different mapped association alone" do
    assert_no_offense "posts.preload(:author).map(&:editor)", file: "app/models/post.rb"
  end

  test "leaves multiple preloaded associations alone" do
    assert_no_offense "posts.preload(:author, :editor).map(&:author)", file: "app/models/post.rb"
  end

  test "leaves nested preload specifications alone" do
    assert_no_offense "posts.preload(author: :company).map(&:author)", file: "app/models/post.rb"
  end

  test "leaves includes queries alone" do
    assert_no_offense "posts.includes(:author).map(&:author)", file: "app/models/post.rb"
  end

  test "leaves eager load queries alone" do
    assert_no_offense "posts.eager_load(:author).map(&:author)", file: "app/models/post.rb"
  end

  test "leaves an explicit mapping block alone" do
    assert_no_offense "posts.preload(:author).map { |post| post.author }", file: "app/models/post.rb"
  end

  test "leaves a dynamic association alone" do
    assert_no_offense "posts.preload(association).map(&association)", file: "app/models/post.rb"
  end

  test "limits association extraction to model files" do
    cop = self.class.cop_class.new

    assert cop.relevant_file?("app/models/post.rb")
    assert_not cop.relevant_file?("app/services/export.rb")
  end
end
