# The fixture sets a project defines, read from the yml files under the `test/fixtures` directory of the tree the test
# file sits in, since a project can hold more than one of those. Rails names the accessor after the path of the file, so
# `test/fixtures/webhook/deliveries.yml` answers `webhook_deliveries(:name)`, and what sits under `files` stays out
# because `file_fixture_path` points there.
class RuboCop::Callbacksystems::Testing::FixtureNames
  def initialize(test_file, lifetime: nil)
    @test_file = test_file
    @lifetime = lifetime
  end

  def include?(name)
    accessors.include?(name.to_s)
  end

  private
    TEST_DIRECTORY = "test"
    FIXTURE_DIRECTORY = "fixtures"
    FILE_FIXTURE_DIRECTORY = "files"

    # Calls made while one source is being investigated share a walk, while the weak lifetime makes the next
    # investigation read the project again and lets completed ones leave no cache behind.
    ACCESSORS_BY_LIFETIME = ObjectSpace::WeakMap.new
    ACCESSORS_LOCK = Mutex.new

    attr_reader :test_file, :lifetime

    def accessors
      @accessors ||= lifetime ? shared_accessors : discovered_accessors
    end

    def shared_accessors
      ACCESSORS_LOCK.synchronize { ACCESSORS_BY_LIFETIME[lifetime] ||= discovered_accessors }
    end

    def discovered_accessors
      directory ? accessors_in(directory) : Set[]
    end

    def directory
      @directory ||= test_directory&.join(FIXTURE_DIRECTORY)
    end

    def test_directory
      Pathname.new(test_file).ascend.find { it.basename.to_s == TEST_DIRECTORY } if test_file
    end

    def accessors_in(directory)
      Pathname.glob(directory.join("**/*.yml")).reject { file_fixture?(it) }.to_set { accessor_for(it) }
    end

    def file_fixture?(file)
      relative_path_of(file).each_filename.first == FILE_FIXTURE_DIRECTORY
    end

    def relative_path_of(file)
      file.relative_path_from(directory)
    end

    def accessor_for(file)
      relative_path_of(file).sub_ext("").to_s.tr("/", "_")
    end
end
