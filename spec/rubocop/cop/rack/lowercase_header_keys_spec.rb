# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Rack::LowercaseHeaderKeys, :config do
  # This cop relies on Include config to limit scope to controllers/middleware.
  # It flags headers['...'] and response.headers['...'] patterns.

  describe 'headers method call' do
    context 'with bare headers call' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          headers['Content-Type'] = 'application/json'
                  ^^^^^^^^^^^^^^ HTTP response header keys should be lowercase. Use `content-type` instead of `Content-Type`.
        RUBY

        expect_correction(<<~RUBY)
          headers['content-type'] = 'application/json'
        RUBY
      end
    end

    context 'with Content-Disposition' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          headers['Content-Disposition'] = 'attachment; filename="test.pdf"'
                  ^^^^^^^^^^^^^^^^^^^^^ HTTP response header keys should be lowercase. Use `content-disposition` instead of `Content-Disposition`.
        RUBY

        expect_correction(<<~RUBY)
          headers['content-disposition'] = 'attachment; filename="test.pdf"'
        RUBY
      end
    end
  end

  describe 'response.headers' do
    context 'with response method call' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          response.headers['Cache-Control'] = 'no-cache'
                           ^^^^^^^^^^^^^^^ HTTP response header keys should be lowercase. Use `cache-control` instead of `Cache-Control`.
        RUBY

        expect_correction(<<~RUBY)
          response.headers['cache-control'] = 'no-cache'
        RUBY
      end
    end

    context 'with response local variable' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          def set_header
            response = get_response
            response.headers['Location'] = '/redirect'
                             ^^^^^^^^^^ HTTP response header keys should be lowercase. Use `location` instead of `Location`.
          end
        RUBY

        expect_correction(<<~RUBY)
          def set_header
            response = get_response
            response.headers['location'] = '/redirect'
          end
        RUBY
      end
    end

    context 'with CORS headers' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          response.headers['Access-Control-Allow-Origin'] = origin
                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ HTTP response header keys should be lowercase. Use `access-control-allow-origin` instead of `Access-Control-Allow-Origin`.
        RUBY

        expect_correction(<<~RUBY)
          response.headers['access-control-allow-origin'] = origin
        RUBY
      end
    end

    context 'with CSP headers' do
      it 'registers an offense and corrects' do
        expect_offense(<<~RUBY)
          response.headers['Content-Security-Policy'] = policy
                           ^^^^^^^^^^^^^^^^^^^^^^^^^ HTTP response header keys should be lowercase. Use `content-security-policy` instead of `Content-Security-Policy`.
        RUBY

        expect_correction(<<~RUBY)
          response.headers['content-security-policy'] = policy
        RUBY
      end
    end
  end

  describe 'cases that should NOT be flagged' do
    context 'when headers are already lowercase' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          headers['content-type'] = 'application/json'
        RUBY
      end
    end

    context 'with unknown custom headers' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          headers['X-My-Custom-Header'] = 'value'
        RUBY
      end
    end

    context 'with outgoing HTTP client headers' do
      it 'does not register an offense for conn.headers' do
        expect_no_offenses(<<~RUBY)
          conn.headers['Content-Type'] = 'application/json'
        RUBY
      end

      it 'does not register an offense for client.headers' do
        expect_no_offenses(<<~RUBY)
          client.headers['Authorization'] = 'Bearer token'
        RUBY
      end

      it 'does not register an offense for request.headers' do
        expect_no_offenses(<<~RUBY)
          request.headers['Accept'] = 'application/json'
        RUBY
      end
    end

    context 'with arbitrary hash assignment' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          some_hash['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with non-string keys' do
      it 'does not register an offense for symbol keys' do
        expect_no_offenses(<<~RUBY)
          headers[:'Content-Type'] = 'application/json'
        RUBY
      end

      it 'does not register an offense for variable keys' do
        expect_no_offenses(<<~RUBY)
          key = 'Content-Type'
          headers[key] = 'value'
        RUBY
      end

      it 'does not register an offense for integer keys' do
        expect_no_offenses(<<~RUBY)
          headers[0] = 'value'
        RUBY
      end
    end

    context 'with empty string key' do
      it 'does not register an offense' do
        expect_no_offenses(<<~RUBY)
          headers[''] = 'value'
        RUBY
      end
    end

    context 'with non-headers method on receiver' do
      it 'does not register an offense for other methods' do
        expect_no_offenses(<<~RUBY)
          something.other_method['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with local variable not named response' do
      it 'does not register an offense for other local vars' do
        expect_no_offenses(<<~RUBY)
          my_obj = get_object
          my_obj.headers['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with chained receiver on response' do
      it 'does not register an offense for response.something.headers' do
        expect_no_offenses(<<~RUBY)
          response.body.headers['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with bare method call not named response' do
      it 'does not register an offense for other_method.headers' do
        expect_no_offenses(<<~RUBY)
          get_connection.headers['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with local variable receiver (not send type)' do
      it 'does not register an offense for lvar receiver' do
        expect_no_offenses(<<~RUBY)
          my_hash = {}
          my_hash['Content-Type'] = 'value'
        RUBY
      end
    end

    context 'with instance variable receiver' do
      it 'does not register an offense for ivar receiver' do
        expect_no_offenses(<<~RUBY)
          @headers['Content-Type'] = 'value'
        RUBY
      end
    end
  end
end
