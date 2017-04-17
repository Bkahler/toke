
module Toke
  class CLI < Thor

    VERSION_FORMATS = {
      'xml' => 'v1',
      'json' => 'v2',
    }

    desc "generate", "generate an apigee access token"
    method_option :env, aliases: "-e", required: true, desc: "The target environment [dev|stg|prd]."
    method_option :secret, aliases: "-s", required: true, desc: "Your client secret"
    method_option :client_id, aliases: "-i", required: true, desc: "Your client Id"
    method_option :callback, aliases: "-c", default: '', desc: "Oauth endpoint to hit (defaults to JSON) [xml|json]"
    method_option :format, aliases: "-f", default: 'json', desc: "Oauth endpoint to hit (defaults to JSON) [xml|json]"
    method_option :verbose, aliases: "-v", type: :boolean, default: false, desc: "Verbose logging (prints the oauth server response)"

    def generate
      @env           = options[:env].downcase
      @client_id     = options[:client_id] || configuration[:apigee_client_id]
      @client_secret = options[:secret]    || configuration[:apigee_client_secret]
      @version       = VERSION_FORMATS.fetch(options[:format], 'v2')
      puts "Retrieving Token"
      retrieve_token
    end

    private

    def retrieve_token
      url = oauth_url(@env)
      callback = options[:callback]
      time = Time.now.to_i.to_s
      inner = callback + @client_id + time.to_s


      key = @client_secret
      data = callback + @client_id + time
      ssign = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)).strip()
      basicEncode = Base64.strict_encode64(@client_id + ':' + @client_secret).strip()

      headers =  {
        'Authorization' => "Basic #{basicEncode}",
        'timestamp' => time,
        'signature' => ssign
      }

      resp = RestClient::Request.execute(
        :method => :post,
        :url => url,
        :headers => headers
      )

      puts "RESPONSE: \n\n #{resp.body} \n\n" if options[:verbose]

      tokens = parse_response(resp.body)

      access_token = tokens["access_token"]

      puts "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
      puts "Access Token:\n#{access_token}"
      puts "-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+"
    end

    def oauth_url(env)
      case env.to_s
      when 'dev'
        "https://enterprise-api-dev.autodesk.com/#{@version}/oauth/generateaccesstoken?grant_type=client_credentials"
      when 'stg'
        "https://enterprise-api-stg.autodesk.com/#{@version}/oauth/generateaccesstoken?grant_type=client_credentials"
      when 'prd'
        "https://enterprise-api.autodesk.com/#{@version}/oauth/generateaccesstoken?grant_type=client_credentials"
      else
      end
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

