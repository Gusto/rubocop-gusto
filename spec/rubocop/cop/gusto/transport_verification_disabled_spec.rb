# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Gusto::TransportVerificationDisabled, :config do
  context "with a verify-mode option set to none" do
    it "registers an offense for OpenSSL::SSL::VERIFY_NONE under a verify-mode key" do
      expect_offense(<<~RUBY)
        Redis.new(url: url, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
                                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Net::HTTP.start(host, 443, use_ssl: true, verify_mode: ::OpenSSL::SSL::VERIFY_NONE)
                                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Savon.client(wsdl: wsdl, ssl_verify_mode: :none)
                                 ^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        config.action_mailer.smtp_settings = { openssl_verify_mode: "none" }
                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        config.action_mailer.smtp_settings = { openssl_verify_mode: "NONE" }
                                               ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Net::HTTP.start(host, 443, use_ssl: true, ssl_verify_mode: 0)
                                                  ^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        RestClient::Request.execute(url: url, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
                                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        client.request(url, { "verify_mode" => OpenSSL::SSL::VERIFY_NONE })
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when assigned into a hash index" do
      expect_offense(<<~RUBY)
        OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:verify_mode] = OpenSSL::SSL::VERIFY_NONE
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when assigned through a setter" do
      expect_offense(<<~RUBY)
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        http&.verify_mode = OpenSSL::SSL::VERIFY_NONE
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        conn.ssl.verify_mode = 0
        ^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        httpi_request.auth.ssl.verify_mode = :none
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense for a VERIFY_NONE value under another key" do
      expect_no_offenses(<<~RUBY)
        MODES = { none: OpenSSL::SSL::VERIFY_NONE, peer: OpenSSL::SSL::VERIFY_PEER }
      RUBY
    end

    it "does not register an offense for a domain attribute named verify_mode set to a non-OpenSSL value" do
      expect_no_offenses(<<~RUBY)
        identity_check.verify_mode = :none
        record.verify_mode = 0
        IdentityCheck.create(verify_mode: :none)
        Record.where(verify_mode: 0)
        options[:verify_mode] = "none"
      RUBY
    end

    it "does not register an offense for a setter with no argument" do
      expect_no_offenses(<<~RUBY)
        a.verify_mode, b = OpenSSL::SSL::VERIFY_NONE, 1
        a.verify_hostname, b = false, 1
        conn.ssl.verify, b = false, 1
        for a.verify_hostname in [false]; end
      RUBY
    end

    it "does not register an offense for a verifying or non-literal mode" do
      expect_no_offenses(<<~RUBY)
        Net::HTTP.start(host, 443, verify_mode: OpenSSL::SSL::VERIFY_PEER)
        Net::HTTP.start(host, 443, verify_mode: settings.verify_mode)
        Savon.client(wsdl: wsdl, ssl_verify_mode: :peer)
        http.verify_mode = local? ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER
        options[:verify_mode] = OpenSSL::SSL::VERIFY_PEER
      RUBY
    end

    it "does not register an offense when compared against or stored in a constant" do
      expect_no_offenses(<<~RUBY)
        raise "insecure" if context.verify_mode == OpenSSL::SSL::VERIFY_NONE
        INSECURE_MODE = OpenSSL::SSL::VERIFY_NONE
      RUBY
    end

    it "does not register an offense for a VERIFY_NONE constant outside OpenSSL::SSL" do
      expect_no_offenses(<<~RUBY)
        http.verify_mode = Policy::VERIFY_NONE
      RUBY
    end

    it "does not register an offense for a `[]=` with no value" do
      expect_no_offenses(<<~RUBY)
        options.[]=(:verify_mode)
      RUBY
    end

    it "does not register an offense for a non-literal key" do
      expect_no_offenses(<<~RUBY)
        options[key] = OpenSSL::SSL::VERIFY_NONE
        client.request(url, { key => false })
      RUBY
    end
  end

  context "with OpenSSL::SSL::VERIFY_PEER overridden" do
    it "registers an offense for const_set with a symbol or string name" do
      expect_offense(<<~RUBY)
        OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        ::OpenSSL::SSL.const_set("VERIFY_PEER", OpenSSL::SSL::VERIFY_NONE)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense for a constant assignment" do
      expect_offense(<<~RUBY)
        OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        OpenSSL::SSL::VERIFY_PEER = 0
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        OpenSSL::SSL.const_set(:VERIFY_PEER, 0)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense inside a reopened OpenSSL::SSL module" do
      expect_offense(<<~RUBY)
        module OpenSSL
          module SSL
            VERIFY_PEER = VERIFY_NONE
            ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
            const_set(:VERIFY_PEER, VERIFY_NONE)
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
          end
        end
        module ::OpenSSL::SSL
          remove_const(:VERIFY_PEER)
          VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        end
      RUBY
    end

    it "does not register an offense for a non-literal const_set name or a multiple assignment" do
      expect_no_offenses(<<~RUBY)
        OpenSSL::SSL.const_set(name, OpenSSL::SSL::VERIFY_NONE)
        module OpenSSL::SSL
          VERIFY_PEER, other = 0, 1
        end
      RUBY
    end

    it "does not register an offense for VERIFY_PEER in a module that is not OpenSSL::SSL" do
      expect_no_offenses(<<~RUBY)
        module Vendor
          module OpenSSL
            module SSL
              VERIFY_PEER = VERIFY_NONE
              const_set(:VERIFY_PEER, VERIFY_NONE)
            end
          end
        end
        class OpenSSL::SSL::Wrapper
          VERIFY_PEER = VERIFY_NONE
        end
        VERIFY_PEER = VERIFY_NONE
        const_set(:VERIFY_PEER, 0)
      RUBY
    end

    it "does not register an offense outside the OpenSSL::SSL namespace" do
      expect_no_offenses(<<~RUBY)
        Policy.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)
        Policy::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
      RUBY
    end

    it "does not register an offense for another constant or a verifying value" do
      expect_no_offenses(<<~RUBY)
        OpenSSL::SSL.const_set(:LEGACY, OpenSSL::SSL::VERIFY_NONE)
        OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
      RUBY
    end
  end

  context "with an explicitly named TLS verification option set to off" do
    it "registers an offense for each option" do
      expect_offense(<<~RUBY)
        RestClient::Request.execute(url: url, verify_ssl: false)
                                              ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        ClickHouse::Config.new(url: url, ssl_verify: false)
                                         ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Excon.new(url, ssl_verify_peer: false)
                       ^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Typhoeus.get(url, ssl_verifypeer: false, ssl_verifyhost: 0)
                          ^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
                                                 ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Net::HTTP.start(host, 443, use_ssl: true, verify_hostname: false)
                                                  ^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Mongo::Client.new(hosts, ssl: true, ssl_verify_certificate: false, ssl_verify_hostname: false)
                                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
                                                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        RestClient::Resource.new(url, verify_ssl: 0)
                                      ^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Ethon::Easy.new(ssl_verifypeer: OpenSSL::SSL::VERIFY_NONE)
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        client.request(url, { "verify_ssl" => false })
                              ^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense when assigned into a hash index" do
      expect_offense(<<~RUBY)
        Excon.defaults[:ssl_verify_peer] = false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense for setter forms" do
      expect_offense(<<~RUBY)
        context.verify_hostname = false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Typhoeus::Config.ssl_verifypeer = false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        client.ssl_verify_peer = false
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        resource.verify_ssl = 0
        ^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        mailer.openssl_verify_mode = "none"
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense for VERIFY_NONE or 0 under a boolean option, since both are truthy" do
      expect_no_offenses(<<~RUBY)
        Net::HTTP.start(host, 443, verify_hostname: OpenSSL::SSL::VERIFY_NONE)
        ClickHouse::Config.new(url: url, ssl_verify: 0)
        Excon.new(url, ssl_verify_peer: OpenSSL::SSL::VERIFY_NONE)
        Mongo::Client.new(hosts, ssl_verify_certificate: 0)
        context.verify_hostname = 0
        client.ssl_verify_peer = OpenSSL::SSL::VERIFY_NONE
      RUBY
    end

    it "does not register an offense for an argument-less option setter" do
      expect_no_offenses(<<~RUBY)
        a.verify_ssl, b = false, 1
      RUBY
    end

    it "does not register an offense when the option is on or non-literal" do
      expect_no_offenses(<<~RUBY)
        RestClient::Request.execute(url: url, verify_ssl: true)
        ClickHouse::Config.new(url: url, ssl_verify: settings.verify)
        Typhoeus.get(url, ssl_verifyhost: 2)
        context.verify_hostname = true
        Excon.defaults[:ssl_verify_peer] = true
      RUBY
    end
  end

  context "with Faraday ssl options" do
    it "registers an offense for `ssl: { verify: false }`" do
      expect_offense(<<~RUBY)
        Faraday.new(url: url, ssl: { verify: false, ca_file: ca_file })
                                     ^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense for `conn.ssl.verify = false` and `conn.ssl[:verify] = false`" do
      expect_offense(<<~RUBY)
        Faraday.new(url: url) do |conn|
          conn.ssl.verify = false
          ^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
          conn.ssl[:verify] = false
          ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
          conn.ssl["verify"] = false
          ^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        end
        Faraday.new(url, "ssl" => { "verify" => false })
                                    ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "registers an offense for a none-literal verify_mode in Faraday ssl options" do
      expect_offense(<<~RUBY)
        Faraday.new(url, ssl: { verify_mode: :none })
                                ^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        Faraday.new(url, ssl: { verify_mode: 0 })
                                ^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        conn.ssl[:verify_mode] = :none
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense for a verifying or non-literal value" do
      expect_no_offenses(<<~RUBY)
        Faraday.new(url: url, ssl: { verify: true })
        Faraday.new(url: url, ssl: { verify: config.ssl_verify })
        Faraday.new(url: url, ssl: ssl_options)
        conn.ssl.verify = config.ssl_verify
        conn.ssl[:verify] = true
      RUBY
    end

    it "does not register an offense for a lone top-level hash" do
      expect_no_offenses(<<~RUBY)
        { verify: false }
      RUBY
    end

    it "does not register an offense under a non-literal options key" do
      expect_no_offenses(<<~RUBY)
        Faraday.new(url, key => { verify: false })
      RUBY
    end

    it "does not register an offense for `verify` on a non-ssl receiver" do
      expect_no_offenses(<<~RUBY)
        client.call(options: { verify: false })
        form.verify = false
        options[:verify] = false
        { verify: false }
      RUBY
    end
  end

  context "with HTTParty" do
    it "registers an offense for `verify: false` or `verify_peer: false` on an HTTParty call" do
      expect_offense(<<~RUBY)
        HTTParty.get(url, verify: false)
                          ^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        ::HTTParty.post(url, body: body, verify_peer: false)
                                         ^^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
        HTTParty.get(url, "verify" => false)
                          ^^^^^^^^^^^^^^^^^ Do not disable TLS certificate verification.
      RUBY
    end

    it "does not register an offense for other receivers or verifying values" do
      expect_no_offenses(<<~RUBY)
        HTTParty.get(url, verify: true)
        Client.get(url, verify: false)
        get(url, verify_peer: false)
      RUBY
    end
  end

  context "with Net::SSH host key verification" do
    it "registers an offense for `verify_host_key: :never` or `false`" do
      expect_offense(<<~RUBY)
        Net::SFTP.start(host, user, password: password, verify_host_key: :never)
                                                        ^^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
        Net::SSH.start(host, user, verify_host_key: false)
                                   ^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
      RUBY
    end

    it "registers an offense for the disabling verifier classes" do
      expect_offense(<<~RUBY)
        Net::SSH.start(host, user, verify_host_key: Net::SSH::Verifiers::Never.new)
                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
        Net::SSH.start(host, user, verify_host_key: ::Net::SSH::Verifiers::Null.new)
                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
        Net::SFTP.start(host, user, paranoid: Net::SSH::Verifiers::Null.new)
                                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
      RUBY
    end

    it "registers an offense for `paranoid: false` on a Net::SSH-family start" do
      expect_offense(<<~RUBY)
        Net::SSH.start(host, user, paranoid: false)
                                   ^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
        ::Net::SCP.start(host, user, paranoid: false)
                                     ^^^^^^^^^^^^^^^ Do not disable SSH host key verification.
      RUBY
    end

    it "does not register an offense for verifying modes, a verifier object, or `paranoid` elsewhere" do
      expect_no_offenses(<<~RUBY)
        Net::SFTP.start(host, user, verify_host_key: :always)
        Net::SFTP.start(host, user, verify_host_key: :accept_new)
        Net::SFTP.start(host, user, verify_host_key: Verifier.new(host))
        Net::SFTP.start(host, user, verify_host_key: Net::SSH::Verifiers::Always.new)
        Net::SSH.start(host, user, paranoid: true)
        Net::SSH.connect(host, user, paranoid: false)
        Model.where(paranoid: false)
      RUBY
    end
  end
end
