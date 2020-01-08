# frozen_string_literal: true
require "forwardable"

module Rum

  ##
  # Docker-specific objects and mixins.
  module Docker

    ##
    # Mixin to enable adding instance methods to a class that
    # gets or sets-and-returns the given  attr of the instance.
    module AttrCallable

      ##
      # Method to define a method-accessor for each argument supplied.
      # When extended by a class
      #
      # Example:
      #  class Fizz
      #    extend AttrCallable
      #    attr_method_accessor :buzz
      #  end
      #
      #  fizz = Fizz.new
      #  fizz.buzz "foo"
      #  fizz.buzz
      #  # => "foo"
      #
      def attr_method_accessor(*args)
        args.each do |var|
          define_method var do |value = nil|
            if value.nil?
              instance_variable_get :"@#{var}"
            else
              instance_variable_set :"@#{var}", value
              self
            end
          end
        end
      end
    end

    ##
    # Mixin to enable runtime Docker command manipulation.
    class Command
      include Enumerable

      ##
      # The +OPTIONS+ portion of a Docker command.
      attr_reader :args, :options

      ##
      # Initialize Docker command with +OPTIONS+ and evaluate the
      # <tt>&block</tt> if given.
      def initialize(*args, **options, &block)
        @args = args
        @options = Options.new(**options)
        instance_eval(&block) if block_given?
      end

      ##
      # Yield Docker command word by word.
      def each
        self.class.name.split(/::/)[1..-1].each{|x| yield x.downcase }
        @options.each{|x| yield x }
        @args.each{|x| yield x }
      end

      ##
      # Interpret missing methods as +OPTION+.
      def method_missing(m, *args, &block)
        @options.send(m, *args, &block)
        args.empty? ? @options[m] : self
      end

      ##
      # Clear all @options
      def clear_options
        @options = Options.new
        self
      end

      ##
      # Convert Docker command to string.
      def to_s
        to_a.join(" ")
      end

      ##
      # Assign default values to Docker command if not explicitly set.
      #
      # Example:
      #   Run.new(&block).with_defaults(user: "fizz")
      #
      # Unless the <tt>&block</tt> contains a directive to set a value for +user+,
      # it will be set to "fizz".
      def with_defaults(**options)
        options.reject{|k,v| @options.include? k }.each{|k,v| @options[k] << v }
        self
      end
    end

    ##
    # Collection of Docker command options to be applied on execution.
    class Options
      extend Forwardable
      include Enumerable

      def_delegators :@data, :[], :[]=, :include?, :to_h, :update

      ##
      # Initialize a new +OPTIONS+ collection for Docker command.
      # Evaluates the <tt>&block</tt> if given.
      def initialize(**options, &block)
        @data = Hash.new{|hash, key| hash[key] = [] }
        options.each{|key,val| @data[key] = [val].flatten }
        instance_eval(&block) if block_given?
      end

      ##
      # Missing methods are interpreted as options to be added to the
      # underlying collection.
      #
      # Example:
      #   opts = Options.new
      #   opts.fizz "buzz"
      #   # => @data={:fizz=>["buzz"]}
      #
      def method_missing(m, *args, &block)
        @data[m] += args unless args.empty?
        self
      end

      ##
      # Yield each option as a CLI flag/option, with +-+ or +--+ prefix.
      #
      # Example:
      #   opts = Options.new
      #   opts.fizz "buzz"
      #   opts.to_a
      #   # => ["--fizz", "buzz"]
      #
      def each
        @data.each do |name, values|
          option = flagify name
          values.each do |value|
            if value.is_a?(Hash)
              value.map{|kv| kv.join("=") }.each do |val|
                yield option
                yield val
              end
            elsif [true, false].include? value
              yield "#{option}=#{value}"
            else
              yield option
              yield value.to_s
            end
          end
        end
      end

      ##
      # Convert options to string.
      #
      # Example:
      #   opts = Options.new
      #   opts.fizz "buzz"
      #   opts.to_s
      #   # => "--fizz buzz"
      #
      def to_s
        to_a.join(" ")
      end

      private

      ##
      # Convert +OPTION+ to +--option+
      def flagify(name)
        name.length == 1 ? "-#{name}" : "--#{name.to_s.gsub(/_/, "-")}"
      end
    end

    ##
    # Docker build command object.
    class Build < Command
      extend AttrCallable

      ##
      # Access +PATH+ with method.
      attr_method_accessor :path

      ##
      # Initialize Docker build command with +OPTIONS+ and +PATH+.
      # Evaluates the <tt>&block</tt> if given.
      def initialize(path, **options, &block)
        super(**options, &block)
        @path = path
      end

      ##
      # Yield the Docker build commmand word-by-word.
      def each
        super{|x| yield x }
        yield @path || "."
      end
    end

    ##
    # Docker run command object.
    class Run < Command
      extend AttrCallable

      ##
      # Access +IMAGE+ and +CMD+ with method.
      attr_method_accessor :image, :cmd

      ##
      # Initialize Docker run command with +OPTIONS+, +IMAGE+, and +CMD+.
      # Evaluates the <tt>&block</tt> if given.
      def initialize(image, cmd = nil, **options, &block)
        super(**options, &block)
        @image = image
        @cmd   = cmd
      end

      ##
      # Yield the Docker run commmand word-by-word.
      def each
        super {|x| yield x }
        yield @image
        [@cmd].flatten.each{|x| yield x } unless @cmd.nil?
      end
    end

    ##
    # Docker image object.
    class Image
      extend AttrCallable
      include Enumerable

      ##
      # Access components of the image reference by method.
      attr_method_accessor :registry, :username, :name, :tag

      ##
      # Initialize image by reference component.
      # Evaluates <tt>&block</tt> if given.
      def initialize(name, registry:nil, username:nil, tag:nil, &block)
        @registry = registry
        @username = username
        @name     = name
        @tag      = tag
        instance_eval(&block) if block_given?
      end

      ##
      # Yield each non-nil component of the image reference in order.
      def each
        [@registry, @username, @name, @tag || :latest].compact.each{|x| yield x.to_s }
      end

      ##
      # Get the image reference without the @tag component.
      def family
        [@registry, @username, @name].compact.map(&:to_s).join("/")
      end

      ##
      # Show handle
      def inspect
        handle = @tag.nil? || @tag.to_sym == :latest ? family : to_s
        "#<#{self.class.name}[#{handle}]>"
      end

      ##
      # Convert the image reference to string.
      def to_s
        "#{family}:#{@tag || :latest}"
      end

      class << self

        ##
        # Parse a string as a Docker image reference
        #
        # Example:
        #   Image.parse("image")
        #   Image.parse("image:tag")
        #   Image.parse("username/image")
        #   Image.parse("username/image:tag")
        #   Image.parse("registry:5000/username/image")
        #   Image.parse("registry:5000/username/image:tag")
        #
        def parse(string_or_symbol)
          string      = string_or_symbol.to_s
          slash_count = string.count("/")

          # image[:tag]
          if slash_count.zero?
            name, tag = string.split(/:/)
            new name, tag: tag

          # username/image[:tag]
          elsif slash_count == 1
            username, name_tag = string.split(/\//)
            name, tag          = name_tag.split(/:/)
            new name, username: username, tag: tag

          # registry/username/image[:tag]
          else
            registry, username, name_tag = string.split(/\//)
            name, tag                    = name_tag.split(/:/)
            new name, registry: registry, username: username, tag: tag
          end
        end
      end
    end
  end
end
