require File.dirname(__FILE__) + '/helper'

class MiddlewareTest < Test::Unit::TestCase
  setup do
    @app = mock_app(Sinatra::Application) {
      get '/*' do
        response.headers['X-Tests'] = env['test.ran'].
          map { |n| n.split('::').last }.
          join(', ')
        env['PATH_INFO']
      end
    }
  end

  class MockMiddleware < Struct.new(:app)
    def call(env)
      (env['test.ran'] ||= []) << self.class.to_s
      app.call(env)
    end
  end

  class UpcaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].upcase
      super
    end
  end

  it "is added with Sinatra::Application.use" do
    @app.use UpcaseMiddleware
    get '/hello-world'
    assert ok?
    assert_equal '/HELLO-WORLD', body
  end

  class DowncaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].downcase
      super
    end
  end

  it "runs in the order defined" do
    @app.use UpcaseMiddleware
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "resets the prebuilt pipeline when new middleware is added" do
    @app.use UpcaseMiddleware
    get '/Foo'
    assert_equal "/FOO", body
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal '/foo', body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "works when app is used as middleware" do
    @app.use UpcaseMiddleware
    @app = @app.new
    get '/Foo'
    assert_equal "/FOO", body
    assert_equal "UpcaseMiddleware", response['X-Tests']
  end

  it "allowes defining middleware via #middleware { ... }" do
    @app.middleware do |app, env|
      env['test.ran'] ||= []
      env['PATH_INFO'] = env['PATH_INFO'].downcase
      status, header, body = app.call(env)
      [status, header, body.to_s.reverse]
    end
    get "/FOO"
    assert ok?
    assert_equal "oof/", body
  end
  
  it "takes an optional pattern for middleware, applying it only to requests matching it" do
    @app.use MockMiddleware
    @app.middleware("/foo/*") { |app, env| [200, {'Content-Type' => 'text/plain'}, "42"] }
    get '/bar'
    assert ok?
    assert_not_equal "42", body
    get '/foo/bar'
    assert ok?
    assert_equal "42", body
  end
  
  it "fills a hash called params for middleware dsl pattern matching" do
    @app.use MockMiddleware
    @app.middleware("/foo/:value") { |app, env| [200, {'Content-Type' => 'text/plain'}, params['value']] }
    get '/foo/bar'
    assert_equal 'bar', body
  end
end
