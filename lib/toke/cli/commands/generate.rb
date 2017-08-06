
module Toke
  class CLI < Thor

    VERSION_FORMATS = {
      'xml' => 'v1',
      'json' => 'v2',
    }

    desc "gen", "generate an apigee access token"
    method_option :env, aliases: "-e", required: true, desc: "The target environment [dev|stg|prd]."
    method_option :tag, aliases: "-t", required: false, desc: "Tag for particular credential set."
    method_option :secret, aliases: "-s", desc: "Your client secret"
    method_option :client_id, aliases: "-i", desc: "Your client Id"
    method_option :callback, aliases: "-c", default: '', desc: "Oauth callback"
    method_option :url, aliases: "-u", desc: "Oauth endpoint to hit "
    method_option :format, aliases: "-f", default: 'json', desc: "Oauth endpoint to hit (defaults to JSON) [xml|json]"
    method_option :verbose, aliases: "-v", type: :boolean, default: false, desc: "Verbose logging (prints the oauth server response)"

    def gen
      @env           = options[:env].downcase
      @version       = VERSION_FORMATS.fetch(options[:format], 'v2')
      @configuration = configuration

      fetch_tagged? ? fetch_tagged : fetch_untagged
      validate_config

      puts "Retrieving Token"
      pre_time = Time.now
      token = retrieve_token
      puts "Time elapsed: #{Time.now - pre_time}"
      token
    end

    private

    def fetch_tagged?
      options[:tag] ? true : false
    end

    def fetch_tagged
      @tag           = options[:tag]       || abort( 'No tag parameter provided' )
      @client_id     = options[:client_id] || @configuration.dig(@tag, @env, 'client_id')
      @client_secret = options[:secret]    || @configuration.dig(@tag, @env, 'client_secret')
      @url           = options[:url]       || @configuration.dig(@tag, @env, 'url')
      @callback      = options[:callback]  || @configuration.dig(@tag, @env, 'callback')
    end

    def fetch_untagged
      @client_id     = options[:client_id] || @configuration.dig(@env, 'client_id')
      @client_secret = options[:secret]    || @configuration.dig(@env, 'client_secret')
      @url           = options[:url]       || @configuration.dig(@env, 'url')
      @callback      = options[:callback]  || @configuration.dig(@env, 'callback')
      @tag           = options[:tag]       || @configuration.dig(@env, 'tag')
    end

    def validate_config
      abort('No client_id, use set to update config or pass as arg') unless @client_id
      abort('No client_secret, use set to update config or pass as arg') unless @client_secret
      abort('No url, use set to update config or pass as arg') unless @url
    end

    def configuration
      if File.exists?("#{ENV['HOME']}/.toke")
        JSON.parse(Base64.decode64(File.read("#{ENV['HOME']}/.toke")))
      else
        {}
      end
    end

    def retrieve_token
      time = Time.now.to_i.to_s
      # inner = @callback + @client_id + time.to_s
      key = @client_secret
      data = @callback + @client_id + time
      ssign = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)).strip()
      basicEncode = Base64.strict_encode64(@client_id + ':' + @client_secret).strip()

      headers =  {
        'Authorization' => "Basic #{basicEncode}",
        'timestamp' => time,
        'signature' => ssign
      }

      resp = RestClient::Request.execute(
        :method => :post,
        :url => @url,
        :headers => headers
      )

      puts "RESPONSE: \n\n #{resp.body} \n\n" if options[:verbose]

      tokens = parse_response(resp.body)
      access_token = tokens['access_token']

      puts "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
      puts "Access Token:\n#{access_token}"
      puts "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
    end

    def parse_response(body)
      if @version == 'v1'
        token = body.match(/<access_token>(.+)<\/access_token>/)[1]
        { 'access_token' => token }
      else
        JSON.parse(body)
      end
    end
  end
end
