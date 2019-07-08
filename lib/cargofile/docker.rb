module Cargofile
  module Docker
    class Base
      include Enumerable

      attr_accessor :options

      def initialize(options:nil, &block)
        @options = options || {}
        yield self if block_given?
      end

      def each
        @options.each do |name, values|
          option = name.length == 1 ? "-#{name}" : "--#{name.to_s.gsub(/_/, "-")}"
          yield option if values.empty?
          values.each do |value|
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
      end

      def method_missing(m, *args, &block)
        @options ||= {}
        @options[m] ||= []
        @options[m]  += args
        self
      end

      def to_h
        {options: options.clone}
      end

      def to_s
        to_a.join(" ")
      end
    end

    class Build < Base
      attr_accessor :path

      def initialize(path:nil, options:nil)
        @path = path
        super options: options
      end

      def each
        yield "docker"
        yield "build"
        super{|x| yield x }
        yield @path || "."
      end

      def clone
        Build.new to_h
      end

      def to_h
        super.update path: @path.clone
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

      def tag(value = nil)
        @tag = value || @tag
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
          else
            # registry/username/image[:tag]
            registry, username, name_tag = string.split(/\//)
            name, tag                    = name_tag.split(/:/)
            options = {registry: registry, username: username, name: name, tag: tag}
          end
          new options
        end
      end
    end

    class Run < Base
      attr_accessor :image, :cmd, :options

      def initialize(image:nil, cmd:nil, options:nil)
        @image = image
        @cmd   = cmd
        super options: options
      end

      def each
        yield "docker"
        yield "run"
        super{|x| yield x }
        yield @image
        cmd.is_a?(Array) ? cmd.each{|x| yield x } : yield(cmd) unless cmd.nil?
      end

      def clone
        Run.new to_h
      end

      def cmd(*values)
        @cmd = values.any? ? values : @cmd
      end

      def image(value = nil)
        @image = value || @image
      end

      def to_h
        super.update image: @image.clone, cmd: @cmd.clone
      end
    end
  end
end
