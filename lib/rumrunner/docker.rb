require "forwardable"

module Rum
  module Docker
    module AttrCallable
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

    module Executable
      include Enumerable

      attr_reader :options

      def initialize(options:nil, &block)
        @options = options || Options.new
        instance_eval(&block) if block_given?
      end

      def each
        self.class.name.split(/::/)[1..-1].each{|x| yield x.downcase }
        @options.each{|x| yield x }
      end

      def method_missing(m, *args, &block)
        @options.send(m, *args, &block)
        args.any? ? self : @options[m]
      end

      def to_s
        to_a.join(" ")
      end

      def with_defaults(options = {}, &block)
        options.reject{|k,v| @options.include? k }.each{|k,v| @options[k] << v }
        self
      end
    end

    class Options
      extend Forwardable
      include Enumerable

      def_delegators :@data, :[], :[]=, :include?, :to_h, :update

      def initialize(options = {}, &block)
        @data = Hash.new{|hash, key| hash[key] = [] }.update(options)
        instance_eval(&block) if block_given?
      end

      def method_missing(m, *args, &block)
        @data[m] += args unless args.empty?
        self
      end

      def each
        @data.each do |name, values|
          option = name.length == 1 ? "-#{name}" : "--#{name.to_s.gsub(/_/, "-")}"
          yield option if values.empty?
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

      def to_s
        to_a.join(" ")
      end
    end

    class Build
      extend AttrCallable
      include Executable

      attr_method_accessor :path

      def initialize(options:nil, path:nil, &block)
        @path = path
        super options: options, &block
      end

      def each
        super{|x| yield x }
        yield @path || "."
      end
    end

    class Run
      extend AttrCallable
      include Executable

      attr_method_accessor :image, :cmd

      def initialize(options:nil, image:nil, cmd:nil, &block)
        @image = image
        @cmd   = cmd
        super options: options, &block
      end

      def each
        super{|x| yield x }
        yield @image
        @cmd.is_a?(Array) ? @cmd.each{|x| yield x } : yield(@cmd) unless @cmd.nil?
      end
    end

    class Image
      extend AttrCallable
      include Enumerable

      attr_method_accessor :registry, :username, :name, :tag

      def initialize(name:, registry:nil, username:nil, tag:nil, &block)
        @registry = registry
        @username = username
        @name     = name
        @tag      = tag
        instance_eval(&block) if block_given?
      end

      def each
        [@registry, @username, @name, @tag].compact.each{|x| yield x }
      end

      def family
        File.join *[@registry, @username, @name].compact.map(&:to_s)
      end

      def to_s
        "#{family}:#{@tag || :latest}"
      end

      class << self
        def parse(string_or_symbol)
          string = string_or_symbol.to_s
          if string.count("/").zero? && string.count(":").zero?
            # image
            new name: string
          elsif string.count("/").zero?
            # image:tag
            name, tag = string.split(/:/)
            new name: name, tag: tag
          elsif string.count("/") == 1 && string.count(":").zero?
            # username/image
            username, name = string.split(/\//)
            new name: name, username: username
          elsif string.count("/") == 1
            # username/image:tag
            username, name_tag = string.split(/\//)
            name, tag          = name_tag.split(/:/)
            new name: name, username: username, tag: tag
          else
            # registry/username/image[:tag]
            registry, username, name_tag = string.split(/\//)
            name, tag                    = name_tag.split(/:/)
            new name: name, registry: registry, username: username, tag: tag
          end
        end
      end
    end
  end
end
