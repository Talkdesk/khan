require 'base64'

module Kahn
  module Models
    class Collection
      def initialize(collection)
        @collection = collection
      end

      def name
        @collection.name
      end

      def drop!
        @collection.drop
      end

      def insert(data)
        begin
          id = @collection.insert data
        rescue Mongo::OperationFailure => e
          # going out on a limb here and assuming all of these are malformed...
          raise Kahn::MalformedDocument.new(e.result['errmsg'])
        end

        @collection.find_one('_id' => id)
      end

      def remove(doc_id)
        query = {'_id' => thunk_mongo_id(doc_id)}
        raise Kahn::DocumentNotFound.new(self, doc_id) unless @collection.find_one(query)
        @collection.remove query
      end

      def update(doc_id, data)
        begin
          document = @collection.find_and_modify \
            :query  => {'_id' => thunk_mongo_id(doc_id)},
            :update => data,
            :new    => true
        rescue Mongo::OperationFailure => e
          # going out on a limb here and assuming all of these are malformed...
          raise Kahn::MalformedDocument.new(e.result['errmsg'])
        end

        raise Kahn::DocumentNotFound.new(self, doc_id) unless document
        document
      end

      def documents(query={})
        Query.new(@collection, query)
      end

      def [](doc_id)
        doc = @collection.find_one('_id' => thunk_mongo_id(doc_id))
        raise Kahn::DocumentNotFound.new(self, doc_id) unless doc
        doc
      end

      def put_file(data)
        file = data.delete('file') or raise Kahn::MalformedDocument.new 'Missing file.'

        opts = {}
        data.each do |k, v|
          case k
          when 'filename'
            opts[:filename] = v
          when 'metadata'
            opts[:metadata] = v unless v.empty?
          when '_id'
            opts[:_id]      = v
          when 'contentType'
            opts[:content_type] = v
          else
            raise Kahn::MalformedDocument.new "Unexpected property: '#{k}'"
          end
        end

        id = grid.put(decode_file(file), opts)
        self[id]
      end

      def get_file(doc_id)
        begin
          doc = grid.get(thunk_mongo_id(doc_id))
        rescue Mongo::GridFileNotFound
          raise Kahn::GridFileNotFound.new(self, doc_id)
        end

        raise Kahn::DocumentNotFound.new(self, doc_id) unless doc
        raise Kahn::GridFileNotFound.new(self, doc_id) unless is_grid_file?(doc)

        doc
      end

      def delete_file(doc_id)
        begin
          grid.get(thunk_mongo_id(doc_id))
        rescue Mongo::GridFileNotFound
          raise Kahn::GridFileNotFound.new(self, doc_id)
        end

        res = grid.delete(thunk_mongo_id(doc_id))

        raise Kahn::Exception.new res['err'] unless res['ok']
      end

      def as_json(*)
        {
          :id      => @collection.name,
          :name    => @collection.name,
          :count   => @collection.count,
          :indexes => @collection.index_information.values,
          :stats   => @collection.stats,
        }
      end

      def to_json(*)
        as_json.to_json
      end

      private

      def thunk_mongo_id(doc_id)
        if doc_id.is_a? BSON::ObjectId
          doc_id
        elsif (doc_id[0..0] == '~')
          doc_id = Base64.decode64(doc_id[1..-1])
          ::Kahn::JSON.decode("{\"_id\":#{doc_id}}")['_id']
        else
          doc_id =~ /^[a-f0-9]{24}$/i ? BSON::ObjectId(doc_id) : doc_id
        end
      end

      def is_grid_collection?
        name.end_with? '.files'
      end

      def grid
        Kahn::GridFSNotFound.new(@collection.db, name) unless is_grid_collection?
        @grid ||= Mongo::Grid.new(@collection.db, name.sub(/\.files$/, ''))
      end

      def is_grid_file?(doc)
        !! doc['chunkSize']
      end

      def decode_file(data)
        unless data =~ /^data:[^;]+;base64,/
          raise Kahn::MalformedDocument.new 'File must be a base64 encoded data: URI'
        end

        Base64.strict_decode64(data.sub(/^data:[^;]+;base64,/, '').strip)
      rescue ArgumentError
        raise Kahn::MalformedDocument.new 'File must be a base64 encoded data: URI'
      end
    end
  end
end
