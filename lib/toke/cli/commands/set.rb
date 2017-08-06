
module Toke
  class CLI < Thor
    desc "set", "set configuration for oauth token generation"
    method_option :env, aliases: "-e", required: true, desc: "The target environment [dev|stg|prd]."
    method_option :tag, aliases: "-t", required: false, desc: "Tag for particular credential set."
    method_option :secret, aliases: "-s", desc: "Your client secret"
    method_option :client_id, aliases: "-i", desc: "Your client Id"
    method_option :callback, aliases: "-c", default: '', desc: "Oauth callback"
    method_option :url, aliases: "-u", desc: "Oauth endpoint to hit "
    method_option :verbose, aliases: "-v", desc: "Enables verbose logging"

    def set
      @env           = options[:env].downcase
      @client_id     = options[:client_id]
      @client_secret = options[:secret]
      @url           = options[:url]
      @callback      = options[:callback]
      @verbose       = options[:verbose]
      @tag           = options[:tag]
      @config        = fetch_config
      update_config
    end

    private

    def update_config
      @tag ? merge_tagged : merge_untagged

      File.open(config_file, "r+") do |f|
        f.write(Base64.encode64(@config.to_json))
      end

      FileUtils.chmod(0600, config_file)
      puts "---- Config Updated ----"
      puts @config if @verbose
    end

    def fetch_config
      unless File.exists?(config_file)
        File.new(config_file, "w+")
      end
      config = Base64.decode64(File.read(config_file))
      config.empty? ? {} : JSON.parse(config)
    end

    def merge_tagged
      merge_hash = @config.dig(@tag, @env) || {}
      @config[@tag] = {} unless @config[@tag]
      @config[@tag][@env] = merge_hash.merge(config_update_info)
    end

    def merge_untagged
      merge_hash = @config[@env] || {}
      @config[@env] = merge_hash.merge(config_update_info)
    end

    def config_update_info
      {
        'client_id'=> @client_id,
        'client_secret'=> @client_secret,
        'url'=> @url,
        'callback'=> @callback
      }
    end

    def config_file
      "#{ENV['HOME']}/.toke"
    end
  end
end
