require 'mongo'
require 'json'

module Kahn
  module Helpers
    PAGE_LIMIT = 50


    ### Kahn JSON responses ###

    def kahn_json(doc, *args)
      json(::Kahn::JSON.as_json(doc), *args)
    end


    ### Misc request parsing helpers ###

    def query_param
      {
        query: ::Kahn::JSON.decode(params.fetch('query', '{}')),
        fields: ::Kahn::JSON.decode(params.fetch('fields', '{}')),
        limit: params.fetch(:limit, 10),
        skip: params.fetch(:skip, 0)
      }
    end

    def request_json
      @request_json ||= ::JSON.parse request.body.read
    rescue
      raise Kahn::MalformedDocument.new
    end

    def request_kahn_json
      @request_kahn_json ||= ::Kahn::JSON.decode request.body.read
    rescue
      raise Kahn::MalformedDocument.new
    end

    def thunk_mongo_id(id)
      id =~ /^[a-f0-9]{24}$/i ? BSON::ObjectId(id) : id
    end


    ### Server management ###

    def servers
      @servers ||= begin
        dsn_list = ::JSON.parse(request.cookies['kahn_rb_servers'] || '[]')
        servers  = default_servers.merge(init_servers(dsn_list))
        servers.empty? ? init_servers(['localhost']) : servers # fall back to 'localhost'
      end
    end

    def default_servers
      @default_servers ||= init_servers((ENV['kahn_SERVERS'] || '').split(';'), :default => true)
    end

    def init_servers(dsn_list, opts={})
      Hash[dsn_list.map { |dsn|
        server = Kahn::Models::Server.new(dsn)
        server.default = opts[:default] || false
        [server.name, server]
      }]
    end

    def add_server(dsn)
      server = Kahn::Models::Server.new(dsn)
      raise Kahn::MalformedDocument.new(server.error) if server.error
      raise Kahn::ServerAlreadyExists.new(server.name) unless servers[server.name].nil?
      servers[server.name] = server
      save_servers
      server
    end

    def remove_server(name)
      raise Kahn::ServerNotFound.new(name) if servers[name].nil?
      @servers.delete(name)
      save_servers
    end

    def save_servers
      dsn_list = servers.collect { |name, server| server.dsn unless server.default }.compact
      response.set_cookie(
        :kahn_rb_servers,
        :path    => '/',
        :value   => dsn_list.to_json,
        :expires => Time.now + 60 * 60 * 24 * 365
      )
    end

    def is_ruby?
      (defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby') || !(RUBY_PLATFORM =~ /java/)
    end

    def check_json_ext?
      !ENV['kahn_NO_JSON_CHECK'] && is_ruby? && !defined?(::JSON::Ext)
    end

    def check_bson_ext?
      !ENV['kahn_NO_BSON_CHECK'] && is_ruby? && !defined?(::BSON::BSON_C)
    end

  end
end
