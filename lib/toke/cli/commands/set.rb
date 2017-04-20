
module Toke
  class CLI < Thor

    desc "set", "set configuration for oauth token generation"
    method_option :env, aliases: "-e", required: true, desc: "The target environment [dev|stg|prd]."
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
      update_config
    end

    private

    def configuration
      if File.exists?(config_file)
        JSON.parse(Base64.decode64(File.read(config_file)))
      else
        {}
      end
    end

    def update_config
      config_info = {
        'client_id'=> @client_id,
        'client_secret'=> @client_secret,
        'url'=> @url,
        'callback'=> @callback
      }

      unless File.exists?(config_file)
        File.new(config_file, "w+")
      end

      config = Base64.decode64(File.read(config_file))

      if config.empty?
        config = {}
      else
        config = JSON.parse(config)
      end

      merge_hash = config[@env] || {}
      config[@env] = merge_hash.merge(config_info)

      File.open(config_file, "r+") do |f|
        f.write(Base64.encode64(config.to_json))
      end

      FileUtils.chmod(0600, config_file)

      puts "---- Config Updated ----"

      if @verbose
        puts config
      end
    end

    def config_file
      "#{ENV['HOME']}/.toke"
    end

  end
end

