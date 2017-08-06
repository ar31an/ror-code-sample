require 'rest-client'
require 'json'
require 'jsonpath'

class Followupboss
  attr_accessor :url, :api_key, :pass

  def initialize(resource, api_key, pass='')
    @url     = "https://api.followupboss.com/v1/#{resource}"
    @api_key = api_key
    @pass    = pass
  end

  def api_request(params, meth, link='')
    begin
      response = RestClient::Request.execute(method: meth.to_sym, url: "#{url}#{link}", user: api_key, password: pass, 
                                             header: { accept: :json, content_type: :json }, payload: params.to_param)
      JSON.parse(response.to_s)
    rescue RestClient::ExceptionWithResponse => e
      JSON.parse(e.response)
    end
  end
end
