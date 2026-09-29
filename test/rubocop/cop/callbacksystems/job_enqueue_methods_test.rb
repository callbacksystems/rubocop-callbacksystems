require "test_helper"

class RuboCop::Cop::Callbacksystems::JobEnqueueMethodsTest < CopTestCase
  self.cop_class = RuboCop::Cop::Callbacksystems::JobEnqueueMethods

  test "allows a method defined outside any class" do
    assert_no_offense <<~RUBY
      def deliver
        OrderJob.perform_later(order)
      end
    RUBY
  end

  test "allows a perform_later with no receiver to name a job after" do
    assert_no_offense <<~RUBY
      class Order
        def deliver
          perform_later(order)
        end
      end
    RUBY
  end

  test "reads a perform_later whose receiver is a method call" do
    assert_no_offense <<~RUBY
      class Order
        def deliver
          job_for(order).perform_later(order)
        end
      end
    RUBY
  end

  test "reads a safely navigated perform_later" do
    assert_offense <<~RUBY
      class Import
        def enqueue_processing
          ProcessJob&.perform_later(self)
        end

        def process
        end
      end
    RUBY
  end

  test "allows a perform_later on a class that does not end in Job" do
    assert_no_offense <<~RUBY
      class Order
        def deliver
          Mailer.perform_later(order)
        end
      end
    RUBY
  end

  test "registers offense when work method exists and job method not named correctly" do
    assert_offense <<~RUBY
      class Import
        def enqueue_processing
          ProcessJob.perform_later(self)
        end

        def process
          # actual work
        end
      end
    RUBY
  end

  test "allows method with _later suffix when work method exists" do
    assert_no_offense <<~RUBY
      class Import
        def process_later
          ProcessJob.perform_later(self)
        end

        def process
          # actual work
        end
      end
    RUBY
  end

  test "allows job method when no corresponding work method exists" do
    assert_no_offense <<~RUBY
      class Notifier
        def notify
          NotificationJob.perform_later(self)
        end
      end
    RUBY
  end

  test "allows method without perform_later" do
    assert_no_offense <<~RUBY
      class Import
        def process
          do_something
        end
      end
    RUBY
  end

  test "ignores perform_later hidden in a deferred callable" do
    assert_no_offense <<~RUBY
      class Import
        def callback
          proc { ProcessJob.perform_later(self) }
        end

        def process
        end
      end
    RUBY
  end

  test "handles namespaced job classes" do
    assert_offense <<~RUBY
      module Order::Fulfillment::Processable
        def enqueue
          Order::Fulfillment::ProcessJob.perform_later(self)
        end

        def process
          # work
        end
      end
    RUBY
  end

  test "allows namespaced job with correct naming" do
    assert_no_offense <<~RUBY
      module Order::Fulfillment::Processable
        def process_later
          Order::Fulfillment::ProcessJob.perform_later(self)
        end

        def process
          # work
        end
      end
    RUBY
  end

  test "handles camel case job names" do
    assert_offense <<~RUBY
      class Reminder
        def schedule
          SendReminderJob.perform_later(self)
        end

        def send_reminder
          # work
        end
      end
    RUBY
  end

  test "allows empty method" do
    assert_no_offense <<~RUBY
      class Import
        def process
        end
      end
    RUBY
  end

  test "handles job in conditional" do
    assert_no_offense <<~RUBY
      class Import
        def maybe_process
          if should_process?
            ProcessJob.perform_later(self)
          end
        end
      end
    RUBY
  end

  test "flags job in conditional when work method exists" do
    assert_offense <<~RUBY
      class Import
        def maybe_enqueue
          if should_process?
            ProcessJob.perform_later(self)
          end
        end

        def process
          # work
        end
      end
    RUBY
  end

  test "does not consider methods from nested classes" do
    assert_no_offense <<~RUBY
      class Outer
        def notify
          NotificationJob.perform_later(self)
        end

        private
          class Inner
            def notification
              # work in inner class
            end
          end
      end
    RUBY
  end

  test "does not flag when work method only exists in nested class" do
    assert_no_offense <<~RUBY
      class Outer
        def enqueue_processing
          ProcessJob.perform_later(self)
        end

        private
          class Helper
            def process
              # work in helper
            end
          end
      end
    RUBY
  end

  test "still flags when work method exists in same class with nested classes" do
    assert_offense <<~RUBY
      class Outer
        def enqueue_processing
          ProcessJob.perform_later(self)
        end

        def process
          # actual work in Outer
        end

        private
          class Inner
            def other
            end
          end
      end
    RUBY
  end

  test "flags correctly in nested class with its own methods" do
    assert_offense <<~RUBY
      class Outer
        private
          class Inner
            def enqueue_processing
              ProcessJob.perform_later(self)
            end

            def process
              # work
            end
          end
      end
    RUBY
  end

  test "flags enqueue defined after a nested class in the outer scope" do
    assert_offense <<~RUBY
      class Outer
        class Inner
          def helper; end
        end

        def enqueue
          ProcessJob.perform_later(self)
        end

        def process
          # actual work in Outer
        end
      end
    RUBY
  end

  test "allows an enqueue whose receiver is a local variable" do
    assert_no_offense <<~RUBY
      class Report
        def notify
          job = pick_job
          job.perform_later
        end
      end
    RUBY
  end

  test "does not pair an instance enqueue with singleton work" do
    assert_no_offense <<~RUBY
      class Import
        def enqueue_processing
          ProcessJob.perform_later(self)
        end

        def self.process
        end
      end
    RUBY
  end

  test "does not pair a singleton enqueue with instance work" do
    assert_no_offense <<~RUBY
      class Import
        def self.enqueue_processing
          ProcessJob.perform_later(self)
        end

        def process
        end
      end
    RUBY
  end

  test "does not pair methods from singleton classes for different expressions" do
    assert_no_offense <<~RUBY
      class Import
        class << FIRST
          def process
          end
        end

        class << SECOND
          def enqueue_processing
            ProcessJob.perform_later(self)
          end
        end
      end
    RUBY
  end
end
