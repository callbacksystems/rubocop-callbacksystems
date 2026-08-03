require "test_helper"
require "audits/fixer_audit"
require "audits/clash_audit"

class FixerSafetyTest < ActiveSupport::TestCase
  test "no autocorrecting cop drops a comment or breaks the syntax" do
    audit = FixerAudit.new

    assert_empty audit.failures, audit.failure_report
  end

  test "correcting with the whole cop set introduces no lint offense" do
    audit = ClashAudit.new

    assert_empty audit.failures, audit.failure_report
  end

  test "every autocorrecting cop has a shape to probe" do
    assert_empty FixerAudit.new.unprobed, "add a heredoc example to the cop's test, or an entry to EXTRA_PROBES"
  end
end
