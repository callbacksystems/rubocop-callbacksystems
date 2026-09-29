require "test_helper"

class CoverageReportTest < ActiveSupport::TestCase
  test "text reports every coverage kind without rounding a shortfall to one hundred percent" do
    report = CoverageReport.new({ "/project/lib/example.rb" => coverage_with(one: 1, missed: 0) }, "/project/lib")

    assert_includes report.text, "lines         1/2      50.00%  under"
    assert_includes report.text, "branches      1/2      50.00%  under"
    assert_includes report.text, "methods       1/2      50.00%  under"
    assert_includes report.text, "    1 lines     example.rb"
    assert_includes report.text, "    1 branches  example.rb"
  end

  test "text also identifies files with missed methods" do
    report = CoverageReport.new({ "/project/lib/example.rb" => coverage_with(one: 1, missed: 0) }, "/project/lib")

    assert_includes report.text, "    1 methods   example.rb"
  end

  test "met? requires the configured minimum for every kind" do
    complete = CoverageReport.new({ "/project/lib/example.rb" => coverage_with(one: 1, reached: 1) }, "/project/lib")
    incomplete = CoverageReport.new({ "/project/lib/example.rb" => coverage_with(one: 1, missed: 0) }, "/project/lib")

    assert_predicate complete, :met?
    assert_not_predicate incomplete, :met?
  end

  test "text excludes files whose directory merely shares the root prefix" do
    results = {
      "/project/lib/example.rb" => coverage_with(one: 1),
      "/project/library/uncovered.rb" => coverage_with(missed: 0)
    }

    report = CoverageReport.new(results, "/project/lib")

    assert_includes report.text, "lines         1/1     100.00%"
    assert_not_includes report.text, "uncovered.rb"
  end

  private
    def coverage_with(first)
      counters = first.values

      { lines: counters, branches: { branch: first }, methods: first }
    end
end
