require 'sinatra/base'
require 'sinatra/mustache'
require 'sinatra/json'
require 'sinatra/reloader'
require 'sinatra/streaming'
require 'sinatra/assetpack'
require 'mongo'

require 'kahn/version'
require 'kahn/json'
require 'kahn/errors'
require 'kahn/models'
require 'kahn/helpers'


module Sinatra::JstPages
  class MustacheEngine < Engine
    def function
      "function (args) { return Mustache.render(#{contents.inspect}, args)}"
    end
  end

  register 'mustache', MustacheEngine
end

module Kahn
  class Server < Sinatra::Base
    set :root, File.join(File.dirname(__FILE__), '..', '..')
    set :environment, :development
    set :protection, :except => :path_traversal
    set :logging, true

    set :views, Proc.new { File.join(root, 'app', 'templates') }

    register Sinatra::AssetPack
    register Sinatra::JstPages

    serve_jst '/jst.js'

    assets {
      serve '/js',  from: 'app/js'
      serve '/css', from: 'app/css'
      serve '/img', from: 'app/img'

      js :app, '/app.js', [
        # vendor libraries
        '/js/vendor/modernizr/modernizr.js',
        '/js/vendor/jquery/jquery.js',
        '/js/vendor/jquery-hoverIntent/jquery.hoverIntent.js',
        '/js/vendor/tablesorter/jquery.tablesorter.js',
        '/js/vendor/underscore/underscore.js',
        '/js/vendor/backbone/backbone.js',
        '/js/vendor/codemirror/lib/codemirror.js',
        '/js/vendor/codemirror/addon/edit/matchbrackets.js',
        '/js/vendor/codemirror/mode/javascript/javascript.js',
        '/js/vendor/bootstrap/js/bootstrap-dropdown.js',
        '/js/vendor/bootstrap/js/bootstrap-tooltip.js',
        '/js/vendor/bootstrap/js/bootstrap-popover.js',
        '/js/vendor/bootstrap/js/bootstrap-modal.js',
        '/js/vendor/esprima/esprima.js',
        '/js/vendor/mousetrap/mousetrap.js',
        '/js/vendor/mustache/mustache.js',

        # extensions
        '/js/extensions.js',
        '/js/modernizr-detects.js',

        # templates
        '/jst.js',

        # the app
        '/js/kahn/bootstrap.js',
        '/js/kahn/util.js',
        '/js/kahn/json.js',
        '/js/kahn/base/**/*js',
        '/js/kahn/models/**/*js',
        '/js/kahn/collections/**/*js',
        '/js/kahn/views/**/*js',
        '/js/kahn/router.js'
      ]

      css :app, '/app.css', [
        '/css/style.css',
        '/js/vendor/codemirror/lib/codemirror.css'
      ]

      js_compression  :uglify   # :jsmin | :yui | :closure | :uglify
      css_compression :simple   # :simple | :sass | :yui | :sqwish

      cache_dynamic_assets true
    }

    before do
      @css = css :app
      @js  = js  :app
    end

    helpers Sinatra::Streaming
    helpers Sinatra::JSON

    set :json_encoder,      :to_json
    set :json_content_type, :json

    helpers Kahn::Helpers

    def self.version
      Kahn::VERSION
    end

    get '/check-status' do
      json alerts: []
    end

    ### Default route ###

    get /.+(?<!\.js|css|png)$/ do
      # Unless this is XHR, render index and let the client-side app handle routing
      pass if request.xhr?
      @kahn_version = Kahn::VERSION
      @base_url = request.env['SCRIPT_NAME']
      erb 'index.html'.intern
    end


    ### Kahn API ###

    get '/servers' do
      json servers.values
    end

    post '/servers' do
      json add_server request_json['name']
    end

    get '/servers/:server' do |server|
      raise Kahn::ServerNotFound.new(server) if servers[server].nil?
      json servers[server]
    end

    delete '/servers/:server' do |server|
      remove_server server
      json :success => true
    end

    get '/servers/:server/databases' do |server|
      json servers[server].databases
    end

    post '/servers/:server/databases' do |server|
      json servers[server].create_database request_json['name']
    end

    get '/servers/:server/databases/:database' do |server, database|
      json servers[server][database]
    end

    delete '/servers/:server/databases/:database' do |server, database|
      servers[server][database].drop!
      json :success => true
    end

    get '/servers/:server/databases/:database/collections' do |server, database|
      json servers[server][database].collections
    end

    post '/servers/:server/databases/:database/collections' do |server, database|
      json servers[server][database].create_collection request_json['name']
    end

    get '/servers/:server/databases/:database/collections/:collection' do |server, database, collection|
      json servers[server][database][collection]
    end

    delete '/servers/:server/databases/:database/collections/:collection' do |server, database, collection|
      servers[server][database][collection].drop!
      json :success => true
    end

    get '/servers/:server/databases/:database/collections/:collection/documents' do |server, database, collection|
      kahn_json servers[server][database][collection].documents(query_param)
    end

    post '/servers/:server/databases/:database/collections/:collection/documents' do |server, database, collection|
      document = servers[server][database][collection].insert request_kahn_json
      kahn_json document
    end

    get '/servers/:server/databases/:database/collections/:collection/documents/:document' do |server, database, collection, document|
      kahn_json servers[server][database][collection][document]
    end

    put '/servers/:server/databases/:database/collections/:collection/documents/:document' do |server, database, collection, document|
      document = servers[server][database][collection].update document, request_kahn_json
      kahn_json document
    end

    delete '/servers/:server/databases/:database/collections/:collection/documents/:document' do |server, database, collection, document|
      collection = servers[server][database][collection].remove document
      json :success => true
    end

    post '/servers/:server/databases/:database/collections/:collection/files' do |server, database, collection|
      document = servers[server][database][collection].put_file request_kahn_json
      kahn_json document
    end

    delete '/servers/:server/databases/:database/collections/:collection/files/:document' do |server, database, collection, document|
      servers[server][database][collection].delete_file document
      json :success => true
    end
  end
end
