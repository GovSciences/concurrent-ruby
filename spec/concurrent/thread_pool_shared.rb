require 'spec_helper'

share_examples_for 'Thread Pool' do

  context '#running?' do

    it 'returns true when the thread pool is running' do
      subject.should be_running
    end

    it 'returns false when the thread pool is shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.should_not be_running
    end

    it 'returns false when the thread pool is shutdown' do
      subject.shutdown
      subject.should_not be_running
    end

    it 'returns false when the thread pool is killed' do
      subject.shutdown
      subject.should_not be_running
    end
  end

  context '#shutdown?' do

    it 'returns true if #shutdown is complete' do
      subject.shutdown
      sleep(0.1)
      subject.should be_shutdown
    end

    it 'returns false when running' do
      subject.should_not be_shutdown
    end
  end

  context '#killed?' do

    it 'returns true if tasks were killed at shutdown' do
      subject.post{ sleep(1) }
      subject.kill
      subject.should be_killed
    end

    it 'returns false when running' do
      subject.should_not be_killed
    end
  end

  context '#waiting' do

    it 'returns zero when the pool is empty' do
      subject.waiting.should eq 0
    end

    it 'returns the number of jobs waiting in the queue' do
      (subject.max_threads + 10).times{ sleep(0.1); subject << proc{ sleep } }
      sleep(0.1)
      subject.waiting.should eq 10
    end
  end

  context '#shutdown' do

    it 'stops accepting new tasks' do
      subject.post{ sleep(1) }
      subject.shutdown
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
    end

    it 'allows in-progress tasks to complete' do
      @expected = false
      subject.post{ sleep(0.5); @expected = true }
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end

    it 'allows pending tasks to complete' do
      @expected = false
      subject.post{ sleep(0.2) }
      subject.post{ sleep(0.2); @expected = true }
      subject.shutdown
      sleep(1)
      @expected.should be_true
    end

    it 'allows threads to exit normally' do
      subject.shutdown
      sleep(1)
      subject.status.should be_empty
    end
  end

  context '#kill' do

    it 'stops accepting new tasks' do
      subject.post{ sleep(1) }
      subject.kill
      @expected = false
      subject.post{ @expected = true }.should be_false
      sleep(1)
      @expected.should be_false
    end

    it 'attempts to kill all in-progress tasks' do
      @expected = false
      subject.post{ sleep(1); @expected = true }
      subject.kill
      sleep(1)
      @expected.should be_false
    end

    it 'rejects all pending tasks' do
      @expected = false
      subject.post{ sleep(0.5) }
      subject.post{ sleep(0.5); @expected = true }
      subject.kill
      sleep(1)
      @expected.should be_false
    end
  end

  context '#wait_for_termination' do

    it 'immediately returns true after shutdown has complete' do
      subject.shutdown
      subject.wait_for_termination.should be_true
    end

    it 'blocks indefinitely when timeout it nil' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.wait_for_termination(nil).should be_true
    end

    it 'returns true when shutdown sucessfully completes before timeout' do
      subject.post{ sleep(0.5) }
      subject.shutdown
      subject.wait_for_termination(1).should be_true
    end

    it 'returns false when shutdown fails to complete before timeout' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.wait_for_termination(0.5).should be_false
    end
  end

  context '#post' do

    it 'raises an exception if no block is given' do
      lambda {
        subject.post
      }.should raise_error(ArgumentError)
    end

    it 'returns true when the block is added to the queue' do
      subject.post{ nil }.should be_true
    end

    it 'calls the block with the given arguments' do
      @expected = nil
      subject.post(1, 2, 3)do |a, b, c|
        @expected = a + b + c
      end
      sleep(0.1)
      @expected.should eq 6
    end

    it 'rejects the block while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      @expected = nil
      subject.post(1, 2, 3)do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false while shutting down' do
      subject.post{ sleep(1) }
      subject.shutdown
      subject.post{ nil }.should be_false
    end

    it 'rejects the block once shutdown' do
      subject.shutdown
      @expected = nil
      subject.post(1, 2, 3)do |a, b, c|
        @expected = a + b + c
      end
      @expected.should be_nil
    end

    it 'returns false once shutdown' do
      subject.post{ nil }
      subject.shutdown
      sleep(0.1)
      subject.post{ nil }.should be_false
    end

    it 'aliases #<<' do
      @expected = false
      subject << proc { @expected = true }
      sleep(0.1)
      @expected.should be_true
    end
  end
end
