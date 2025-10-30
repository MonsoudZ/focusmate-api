require 'rails_helper'

RSpec.describe JwtHelper do
  let(:user) { create(:user) }

  describe '.access_for' do
    it 'generates a JWT token for the user' do
      token = described_class.access_for(user)

      expect(token).to be_present
      expect(token).to be_a(String)
    end

    it 'includes user_id in the payload' do
      token = described_class.access_for(user)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      payload = decoded.first

      expect(payload['user_id']).to eq(user.id)
    end

    it 'includes exp (expiration) in the payload' do
      before_time = Time.current
      token = described_class.access_for(user)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      payload = decoded.first

      expect(payload['exp']).to be_present
      expect(payload['exp']).to be > before_time.to_i
      expect(payload['exp']).to be <= 1.hour.from_now.to_i
    end

    it 'includes iat (issued at) in the payload' do
      before_time = Time.current
      token = described_class.access_for(user)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      payload = decoded.first

      expect(payload['iat']).to be_present
      expect(payload['iat']).to be >= before_time.to_i
      expect(payload['iat']).to be <= Time.current.to_i
    end

    it 'uses HS256 algorithm' do
      token = described_class.access_for(user)
      decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      header = decoded.last

      expect(header['alg']).to eq('HS256')
    end

    it 'encodes with the application secret key' do
      token = described_class.access_for(user)

      # Should decode successfully with the secret key
      expect {
        JWT.decode(token, Rails.application.secret_key_base, true, algorithm: 'HS256')
      }.not_to raise_error
    end

    it 'raises error when decoded with wrong secret' do
      token = described_class.access_for(user)

      expect {
        JWT.decode(token, 'wrong_secret', true, algorithm: 'HS256')
      }.to raise_error(JWT::VerificationError)
    end
  end
end
