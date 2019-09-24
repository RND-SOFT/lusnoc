RSpec.describe Lusnoc::Session do
  subject(:session){ described_class.new('test', ttl: 5) }
  let(:receiver){ double }

  describe 'initialized' do
    it { is_expected.to be_expired }
    it { is_expected.not_to be_alive }

    it '#initialize call run when block passed' do
      expect(receiver).to receive(:call).with(Lusnoc::Session)
      described_class.any_instance.stub(:run) {|instance, &block| block.call(instance) }

      described_class.new('test', ttl: 5) {|s| receiver.call(s) }
    end

    it '#time_to_expiration should be nil' do
      expect(session.time_to_expiration).to be_nil
    end

    it '#need_renew? should be nil' do
      expect(session.need_renew?).to be_nil
    end

    it '#alive! should raise' do
      expect{ session.alive! }.to raise_error(Lusnoc::ExpiredError)
    end

    it '#renew! should raise' do
      expect{ session.renew }.to raise_error(Lusnoc::ExpiredError)
    end

    describe '#run' do
      let(:session_id){ rand(1_000_000_000).to_s }

      describe 'with healthy consul' do
        before do
          stub_request(:put, 'http://localhost:8500/v1/session/create')
            .to_return(status: 200, body: "{\"ID\": \"#{session_id}\"}", headers: {})
          stub_request(:put, "http://localhost:8500/v1/session/destroy/#{session_id}")
            .to_return(status: 200, body: 'true', headers: {})
          stub_request(:put, "http://localhost:8500/v1/session/renew/#{session_id}")
            .to_return(status: 200, body: 'true', headers: {})
          stub_request(:get, %r{http://localhost:8500/v1/session/info/#{session_id}})
            .to_return(status: 200, body: '[{}]', headers: { 'x-consul-index': 1 })
        end

        it 'should run smoothy' do
          expect(receiver).to receive(:run).with(session)
          expect(receiver).not_to receive(:die)

          session.on_session_die do |s|
            receiver.die(s)
          end

          is_expected.to be_expired
          is_expected.not_to be_alive

          session.run do |s|
            is_expected.not_to be_expired
            is_expected.to be_alive

            receiver.run(s)
            s.renew
            sleep 1
          end

          is_expected.to be_expired
          is_expected.not_to be_alive
        end
      end

      describe 'with broken consul' do
        before do
          @count = 0

          stub_request(:put, 'http://localhost:8500/v1/session/create').to_return(
            status: 200, body: "{\"ID\": \"#{session_id}\"}", headers: {}
          )

          stub_request(:put, "http://localhost:8500/v1/session/destroy/#{session_id}").to_return(
            status: 200, body: 'true', headers: {}
          )
          stub_request(:get, %r{http://localhost:8500/v1/session/info/#{session_id}}).to_return do |_request|
            if (@count += 1) < 2
              { status: 200,  body: '[{}]', headers: { 'x-consul-index': 1 } }
            else
              { status: 200,  body: '', headers: { 'x-consul-index': 1 } }
            end
          end
        end

        it 'should run smoothy' do
          expect(receiver).to receive(:run).with(session)
          expect(receiver).to receive(:die).with(session)

          session.on_session_die do |s|
            is_expected.to be_expired
            is_expected.not_to be_alive
            receiver.die(s)
          end

          is_expected.to be_expired
          is_expected.not_to be_alive

          session.run do |s|
            receiver.run(s)

            is_expected.not_to be_expired
            is_expected.to be_alive
            sleep 0.5
            is_expected.to be_expired
            is_expected.not_to be_alive
            sleep 0.5
          end

          is_expected.to be_expired
          is_expected.not_to be_alive
        end
      end
    end
  end
end

