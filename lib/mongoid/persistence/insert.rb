# encoding: utf-8
module Mongoid #:nodoc:
  module Persistence #:nodoc:
    # Insert is a persistence command responsible for taking a document that
    # has not been saved to the database and saving it.
    #
    # The underlying query resembles the following MongoDB query:
    #
    #   collection.insert(
    #     { "_id" : 1, "field" : "value" },
    #     false
    #   );
    class Insert < Command
      # Insert the new document in the database. This delegates to the standard
      # MongoDB collection's insert command.
      #
      # Example:
      #
      # <tt>Insert.persist</tt>
      #
      # Returns:
      #
      # The +Document+, whether the insert succeeded or not.
      def persist
        return @document if @validate && !@document.valid?
        @document.run_callbacks(:before_create)
        @document.run_callbacks(:before_save)
        if insert
          @document.new_record = false
          children.each {|child| child.new_record = false }
          @document.move_changes
          @document.run_callbacks(:after_create)
          @document.run_callbacks(:after_save)
        end
        @document
      end

      protected
      # Insert the document into the database.
      def insert
        if @document.embedded?
          Persistence::InsertEmbedded.new(@document, @validate).persist
        else
          @collection.insert(@document.raw_attributes, @options)
        end
      end

      def children
        children = []
        @document.associations.each do |name, metadata|
          if embedded_association?(metadata)
            child = @document.send(name)
            unless child.nil? || (child.respond_to?(:empty) && child.empty?)
              children.concat(child.to_a)
            end
          end
        end
        children
      end

      def embedded_association?(metadata)
        [Mongoid::Associations::EmbedsOne,
         Mongoid::Associations::EmbedsMany].include?(metadata.association)
      end
    end
  end
end
