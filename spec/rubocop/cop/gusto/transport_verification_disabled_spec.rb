# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::TransportVerificationDisabled, :config do
  context "with OpenSSL::SSL::VERIFY_NONE" do
    it "registers an offense when passed as a hash value" do
      expect_offense(<<~RUBY)
        Redis.new(url: url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
                                                       ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when passed as a keyword argument" do
      expect_offense(<<~RUBY)
        Net::HTTP.start(host, 443, use_ssl: true, verify_mode: ::OpenSSL::SSL::VERIFY_NONE)
                                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when assigned through a setter" do
      expect_offense(<<~RUBY)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
                           ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when assigned through a safe-navigation setter" do
      expect_offense(<<~RUBY)
        http&.verify_mode = OpenSSL::SSL::VERIFY_NONE
                            ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when it replaces VERIFY_PEER via const_set" do
      expect_offense(<<~RUBY)
        OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)
                                             ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when it is assigned to VERIFY_PEER" do
      expect_offense(<<~RUBY)
        OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense when compared against" do
      expect_no_offenses(<<~RUBY)
        raise "insecure" if context.verify_mode == OpenSSL::SSL::VERIFY_NONE
      RUBY
    end

    it "does not register an offense when chosen by a condition" do
      expect_no_offenses(<<~RUBY)
        http.verify_mode = local? ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
      RUBY
    end

    it "does not register an offense when assigned to an unrelated constant" do
      expect_no_offenses(<<~RUBY)
        INSECURE_MODE = OpenSSL::SSL::VERIFY_NONE
        Policy::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
      RUBY
    end

    it "does not register an offense when VERIFY_PEER is assigned a verifying value" do
      expect_no_offenses(<<~RUBY)
        OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      RUBY
    end

    it "does not register an offense when passed to const_set for another constant" do
      expect_no_offenses(<<~RUBY)
        OpenSSL::SSL.const_set(:LEGACY, OpenSSL::SSL::VERIFY_NONE)
      RUBY
    end

    it "does not register an offense for a VERIFY_NONE constant outside OpenSSL::SSL" do
      expect_no_offenses(<<~RUBY)
        http.verify_mode = Policy::VERIFY_NONE
      RUBY
    end
  end

  context "with Faraday ssl options" do
    it "registers an offense for `ssl: { verify: false }`" do
      expect_offense(<<~RUBY)
        Faraday.new(url: url, ssl: { verify: false })
                                     ^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense for `conn.ssl.verify = false`" do
      expect_offense(<<~RUBY)
        Faraday.new(url: url) do |conn|
          conn.ssl.verify = false
          ^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        end
      RUBY
    end

    it "does not register an offense for `ssl: { verify: true }`" do
      expect_no_offenses(<<~RUBY)
        Faraday.new(url: url, ssl: { verify: true })
      RUBY
    end

    it "does not register an offense for a non-literal verify value" do
      expect_no_offenses(<<~RUBY)
        Faraday.new(url: url, ssl: { verify: config.ssl_verify })
        conn.ssl.verify = config.ssl_verify
      RUBY
    end

    it "does not register an offense for `verify: false` outside an `ssl:` hash" do
      expect_no_offenses(<<~RUBY)
        HTTParty.get(url, verify: false)
        client.call(options: { verify: false })
      RUBY
    end

    it "does not register an offense for a bare top-level `{ verify: false }` hash" do
      expect_no_offenses(<<~RUBY)
        { verify: false }
      RUBY
    end

    it "does not register an offense for `verify = false` on a non-ssl receiver" do
      expect_no_offenses(<<~RUBY)
        form.verify = false
      RUBY
    end
  end

  context "with explicitly named TLS verification options" do
    it "registers an offense for each option set to false" do
      expect_offense(<<~RUBY)
        RestClient::Request.execute(url: url, verify_ssl: false)
                                              ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        ClickHouse::Config.new(url: url, ssl_verify: false)
                                         ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Excon.new(url, ssl_verify_peer: false)
                       ^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Typhoeus.get(url, ssl_verifypeer: false)
                          ^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense when the option is true or non-literal" do
      expect_no_offenses(<<~RUBY)
        RestClient::Request.execute(url: url, verify_ssl: true)
        ClickHouse::Config.new(url: url, ssl_verify: settings.verify)
      RUBY
    end
  end

  context "with Net::SSH host key verification" do
    it "registers an offense for `verify_host_key: :never`" do
      expect_offense(<<~RUBY)
        Net::SFTP.start(host, user, password: password, verify_host_key: :never)
                                                        ^^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
      RUBY
    end

    it "registers an offense for `verify_host_key: false`" do
      expect_offense(<<~RUBY)
        Net::SSH.start(host, user, verify_host_key: false)
                                   ^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
      RUBY
    end

    it "does not register an offense for verifying modes or a verifier object" do
      expect_no_offenses(<<~RUBY)
        Net::SFTP.start(host, user, verify_host_key: :always)
        Net::SFTP.start(host, user, verify_host_key: :accept_new)
        Net::SFTP.start(host, user, verify_host_key: Verifier.new(host))
      RUBY
    end
  end
end
