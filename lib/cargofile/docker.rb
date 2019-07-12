module Cargofile
  module Docker
    module Executable
      include Enumerable

      attr_accessor :options

      def initialize(options:nil, &block)
        @options = OptionCollection.new(options || {})
        instance_eval(&block) if block_given?
      end

      def each
        self.class.name.split(/::/)[1..-1].each{|x| yield x.downcase }
        @options.each{|x| yield x }
      end

      def clone(&block)
        self.class.new to_h, &block
      end

      def method_missing(m, *args, &block)
        @options.send(m, *args, &block)
        args.any? ? self : @options[m]
      end

      def to_h
        {options: @options.to_h}
      end

      def to_s
        to_a.join(" ")
      end
    end

    class OptionCollection
      extend Forwardable
      include Enumerable

      def_delegators :@options, :[], :[]=, :update

      def initialize(options = {}, &block)
        @options = options
        instance_eval(&block) if block_given?
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
            elsif [true, false].include? value
              yield option
            else
              yield option
              yield value.to_s
            end
          end
        end
      end

      def method_missing(m, *args, &block)
        unless args.empty?
          @options[m] ||= []
          @options[m]  += args
        end
        self
      end

      def clone(&block)
        OptionCollection.new @options.clone, &block
      end

      def to_h
        @options.clone
      end

      def to_s
        to_a.join " "
      end
    end

    class Build
      extend AttrCallable
      include Executable

      attr_writer :path

      attr_method_accessor :path

      def initialize(path:nil, options:nil, &block)
        @path = path
        super options: options, &block
      end

      def each
        super{|x| yield x }
        yield @path || "."
      end

      def to_h
        super.update path: @path.clone
      end
    end

    class Run
      extend AttrCallable
      include Executable

      attr_writer :image, :cmd

      attr_method_accessor :image

      def initialize(image:nil, cmd:nil, options:nil)
        @image = image
        @cmd   = cmd
        super options: options
      end

      def each
        super{|x| yield x }
        yield @image
        cmd.is_a?(Array) ? cmd.each{|x| yield x } : yield(cmd) unless cmd.nil?
      end

      def cmd(*values)
        @cmd = values.any? ? values : @cmd
      end

      def to_h
        super.update image: @image.clone,
                     cmd:   @cmd.clone
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

      def clone(&block)
        Image.new to_h, &block
      end

      def family
        File.join *[@registry, @username, @name].compact.map(&:to_s)
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
        "#{family}:#{@tag || :latest}"
      end

      def update(options = {})
        options.each{|k,v| send k, v }
        self
      end

      class << self
        def parse(string_or_symbol)
          string = string_or_symbol.to_s
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
  end
end
