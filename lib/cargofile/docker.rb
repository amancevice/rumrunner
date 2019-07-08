module Cargofile
  module Docker
    class Build
      include Enumerable

      attr_accessor :path, :options

      def initialize(path:nil, options:nil)
        @path    = path    || "."
        @options = options || {}
      end

      def each
        yield "docker"
        yield "build"
        @options.each do |name, values|
          values.each do |value|
            option = "--#{name.to_s.gsub(/_/, "-")}"
            if value.is_a?(Hash)
              value.map{|kv| kv.join("=") }.each do |val|
                yield option
                yield val
              end
            else
              yield option
              yield value.to_s
            end
          end
        end
        yield @path
      end

      def method_missing(m, *args, &block)
        @options[m] ||= []
        @options[m]  += args
        self
      end

      def clone
        Build.new to_h
      end

      def to_h
        {
          path:    @path.clone,
          options: @options.clone,
        }
      end

      def to_s
        to_a.join(" ")
      end
    end

    class Image
      attr_accessor :registry, :username, :name, :tag

      def initialize(name:, registry:nil, username:nil, tag:nil)
        @registry = registry
        @username = username
        @name     = name
        @tag      = tag
      end

      def clone
        Image.new to_h
      end

      def to_h
        {
          registry: @registry.clone,
          username: @username.clone,
          name:     @name.clone,
          tag:      @tag.clone,
        }
      end

      def to_s
        parts  = [@registry, @username, @name].compact.map(&:to_s)
        prefix = File.join(parts)
        @tag.nil? ? prefix : "#{prefix}:#{@tag}"
      end

      class << self
        def parse(string)
          if string.count("/").zero? && string.count(":").zero?
            # image
            options = {name: string}
          elsif string.count("/").zero?
            # image:tag
            name, tag = string.split(/:/)
            options = {name: name, tag: tag}
          elsif string.count("/") == 1 && string.count(":").zero?
            # username/image
            username, name = string.split(/\//)
            options = {username: username, name: name}
          elsif string.count("/") == 1
            # username/image:tag
            username, name_tag = string.split(/\//)
            name, tag          = name_tag.split(/:/)
            options = {username: username, name: name, tag: tag}
          elsif string.count("/") == 2 && string.count(":").zero?
            # registry/username/image
            registry, username, name = string.split(/\//)
            options = {registry: registry, username: username, name: name}
          else
            # registry/username/image:tag
            registry, username, name_tag = string.split(/\//)
            name, tag                    = name_tag.split(/:/)
            options = {registry: registry, username: username, name: name, tag: tag}
          end
          new options
        end
      end
    end
  end
end
