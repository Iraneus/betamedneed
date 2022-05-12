
# /Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/cache.rb:171:in `load': incompatible marshal file format (can't be read) (TypeError)
format version 4.8 required; 0.0 given
$ jekyll serve  --verbose
  Logging at level: debug
    Jekyll Version: 4.2.2
Configuration file: C:/Users/HP/repos/betamedneed/_config.yml
  Logging at level: debug
    Jekyll Version: 4.2.2
                    ------------------------------------------------
      Jekyll 4.2.2   Please append `--trace` to the `serve` command 
                     for any additional information or backtrace. 
                    ------------------------------------------------
Traceback (most recent call last):
        19: from C:/Ruby27-x64/bin/jekyll:25:in `<main>'
        18: from C:/Ruby27-x64/bin/jekyll:25:in `load'
        17: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/exe/jekyll:15:in `<top (required)>'
        16: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/mercenary-0.4.0/lib/mercenary.rb:21:in `program'
        15: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/mercenary-0.4.0/lib/mercenary/program.rb:44:in `go'
        14: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/mercenary-0.4.0/lib/mercenary/command.rb:221:in `execute'
        13: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/mercenary-0.4.0/lib/mercenary/command.rb:221:in `each'
        12: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/mercenary-0.4.0/lib/mercenary/command.rb:221:in `block in execute'
        11: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/commands/serve.rb:86:in `block (2 levels) in init_with_program'     
        10: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/command.rb:91:in `process_with_graceful_fail'
         9: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/command.rb:91:in `each'
         8: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/command.rb:91:in `block in process_with_graceful_fail'
         7: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/commands/build.rb:30:in `process'
         6: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/commands/build.rb:30:in `new'
         5: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/site.rb:35:in `initialize'
         4: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/site.rb:118:in `reset'
         3: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/cache.rb:41:in `clear_if_config_changed'
         2: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/cache.rb:86:in `[]'
         1: from C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/cache.rb:171:in `load'
C:/Ruby27-x64/lib/ruby/gems/2.7.0/gems/jekyll-4.2.2/lib/jekyll/cache.rb:171:in `load': incompatible marshal file format (can't be read) (TypeError)
        format version 4.8 required; 0.0 given



# frozen_string_literal: true

require "digest"

module Jekyll
  class Cache
    # class-wide base cache
    @base_cache = {}

    # class-wide directive to write cache to disk is enabled by default
    @disk_cache_enabled = true

    class << self
      # class-wide cache location
      attr_accessor :cache_dir

      # class-wide directive to write cache to disk
      attr_reader :disk_cache_enabled

      # class-wide base cache reader
      attr_reader :base_cache

      # Disable Marshaling cached items to disk
      def disable_disk_cache!
        @disk_cache_enabled = false
      end

      # Clear all caches
      def clear
        delete_cache_files
        base_cache.each_value(&:clear)
      end

      # Compare the current config to the cached config
      # If they are different, clear all caches
      #
      # Returns nothing.
      def clear_if_config_changed(config)
        config = config.inspect
        cache = Jekyll::Cache.new "Jekyll::Cache"
        return if cache.key?("config") && cache["config"] == config

        clear
        cache = Jekyll::Cache.new "Jekyll::Cache"
        cache["config"] = config
        nil
      end

      private

      # Delete all cached items from all caches
      #
      # Returns nothing.
      def delete_cache_files
        FileUtils.rm_rf(@cache_dir) if disk_cache_enabled
      end
    end

    #

    # Get an existing named cache, or create a new one if none exists
    #
    # name - name of the cache
    #
    # Returns nothing.
    def initialize(name)
      @cache = Jekyll::Cache.base_cache[name] ||= {}
      @name = name.gsub(%r![^\w\s-]!, "-")
    end

    # Clear this particular cache
    def clear
      delete_cache_files
      @cache.clear
    end

    # Retrieve a cached item
    # Raises if key does not exist in cache
    #
    # Returns cached value
    def [](key)
      return @cache[key] if @cache.key?(key)

      path = path_to(hash(key))
      if disk_cache_enabled? && File.file?(path) && File.readable?(path)
        @cache[key] = load(path)
      else
        raise
      end
    end

    # Add an item to cache
    #
    # Returns nothing.
    def []=(key, value)
      @cache[key] = value
      return unless disk_cache_enabled?

      path = path_to(hash(key))
      value = new Hash(value) if value.is_a?(Hash) && !value.default.nil?
      dump(path, value)
    rescue TypeError
      Jekyll.logger.debug "Cache:", "Cannot dump object #{key}"
    end

    # If an item already exists in the cache, retrieve it.
    # Else execute code block, and add the result to the cache, and return that result.
    def getset(key)
      self[key]
    rescue StandardError
      value = yield
      self[key] = value
      value
    end

    # Remove one particular item from the cache
    #
    # Returns nothing.
    def delete(key)
      @cache.delete(key)
      File.delete(path_to(hash(key))) if disk_cache_enabled?
    end

    # Check if `key` already exists in this cache
    #
    # Returns true if key exists in the cache, false otherwise
    def key?(key)
      # First, check if item is already cached in memory
      return true if @cache.key?(key)
      # Otherwise, it might be cached on disk
      # but we should not consider the disk cache if it is disabled
      return false unless disk_cache_enabled?

      path = path_to(hash(key))
      File.file?(path) && File.readable?(path)
    end

    def disk_cache_enabled?
      !!Jekyll::Cache.disk_cache_enabled
    end

    private

    # Given a hashed key, return the path to where this item would be saved on disk.
    def path_to(hash = nil)
      @base_dir ||= File.join(Jekyll::Cache.cache_dir, @name)
      return @base_dir if hash.nil?

      File.join(@base_dir, hash[0..1], hash[2..-1]).freeze
    end

    # Given a key, return a SHA2 hash that can be used for caching this item to disk.
    def hash(key)
      Digest::SHA2.hexdigest(key).freeze
    end

    # Remove all this caches items from disk
    #
    # Returns nothing.
    def delete_cache_files
      FileUtils.rm_rf(path_to) if disk_cache_enabled?
    end

    # Load `path` from disk and return the result.
    # This MUST NEVER be called in Safe Mode
    # rubocop:disable Security/MarshalLoad
    def load(path)
      raise unless disk_cache_enabled?

      cached_file = File.open(path, "rb")
      value = Marshal.load(cached_file)
      cached_file.close
      value
    end
    # rubocop:enable Security/MarshalLoad

    # Given a path and a value, save value to disk at path.
    # This should NEVER be called in Safe Mode
    #
    # Returns nothing.
    def dump(path, value)
      return unless disk_cache_enabled?

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "wb") do |cached_file|
        Marshal.dump(value, cached_file)
      end
    end
  end
end
