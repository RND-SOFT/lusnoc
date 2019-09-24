RSpec.describe Lusnoc::Guard do
  subject(:guard){ described_class.new('http://rspec.example.test') }

  it '#callbacks should be empty' do
    expect(guard.callbacks).to be_empty
  end

  it '#condition should store block' do
    guard.condition {}
    expect(guard.callbacks[:condition]).to be_a(Proc)
  end

  it '#then should store block' do
    guard.then {}
    expect(guard.callbacks[:then]).to be_a(Proc)
  end

  describe '#run' do
    let(:receiver){ double }

    it 'should start thread' do
      expect(guard).to receive(:start_thread).and_return(nil)
      guard.run {}
    end

    it 'should yield block' do
      expect(guard).to receive(:start_thread).and_return(nil)
      expect {|b| guard.run(&b) }.to yield_control.once
    end

    it 'should check url response with #condition' do
      stub_request(:get, /rspec.example.test/)
        .to_return(status: 200, body: 'testbody', headers: { 'x-consul-index': 1 })
      expect(receiver).to receive(:condition).with('testbody').twice
      expect(receiver).to receive(:fire).with(no_args).once

      count = 2
      guard.condition do |body|
        receiver.condition(body)
        (count -= 1) > 0
      end

      guard.then do |*arg|
        receiver.fire(*arg)
      end

      guard.run do
        sleep 1
      end
    end

    it 'should pass exception to #then' do
      stub_request(:get, /rspec.example.test/).to_return(status: 200, body: 'testbody', headers: { 'x-consul-index': 1 })
      expect(receiver).to receive(:condition).with('testbody').once
      expect(receiver).to receive(:fire).with(RuntimeError).once

      guard.condition do |body|
        receiver.condition(body)
        raise 'test exception'
      end

      guard.then do |*arg|
        receiver.fire(*arg)
      end

      guard.run do
        sleep 1
      end
    end
  end
end

