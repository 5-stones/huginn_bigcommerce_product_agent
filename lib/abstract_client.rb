
module BigcommerceProductAgent
    module Client
        class AbstractClient
            @client = nil
            @uri_base = ''

            def initialize(
                store_hash,
                client_id,
                access_token,
                params = {
                    endpoint: 'https://api.bigcommerce.com',
                    api_version: 'v3',
                }
            )
                @headers = {
                    'X-Auth-Client' => client_id,
                    'X-Auth-Token' => access_token,
                    'Content-Type' => 'application/json',
                    'Accept' => 'application/json'
                }
                @store_hash = store_hash
                @endpoint = params[:endpoint]
                @api_version = params[:api_version]
            end

            def self.uri_base
                @uri_base
            end

            def uri_base
                self.class.uri_base
            end

            def client
                if !@client
                    @client = Faraday.new({ url: @endpoint, headers: @headers }) do |conn|
                        conn.use Faraday::Response::RaiseError
                        conn.response :logger, nil, { headers: true, bodies: true }
                        conn.response :json, :content_type => 'application/json'
                        conn.adapter Faraday.default_adapter
                    end
                end

                return @client
            end

            def uri(params = {})
                u = "/stores/#{@store_hash}/#{@api_version}/#{uri_base}"

                params.each do |key,val|
                  u = u.gsub(":#{key.to_s}", val.to_s)
                end

                # remove params that weren't provided
                u = u.gsub(/(\/\:[^\/]+)/, '')

                return u
            end

            def index(params = {})
                response = client.get(uri, params)
                return response.body['data']
            end

            def create(payload)
                raise "not implemented yet."
            end

            def update(payload)
                raise "not implemented yet."
            end

            def delete(payload)
                raise "not implemented yet."
            end

            def upsert(payload)
                raise "not implemented yet."
            end

            def get(url_params = {}, params = {})
                response = client.get(uri(url_params), params)
                return response.body['data']
            end
        end
    end
end
