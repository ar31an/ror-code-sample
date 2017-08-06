require 'rest-client'
require 'json'
require 'jsonpath'

class Sharpspring
  attr_accessor :has_more, :post_uri

  GET_OBJECT_METHOD = {
    'lead' => 'getLeads',
    'campaign' => 'getCampaigns',
    'account' => 'getAccounts',
    'opportunity' => 'getOpportunities'
  }

  def initialize(account_id, secret_key)
    @post_uri = "https://api.sharpspring.com/pubapi/v1/?accountID=#{account_id}&secretKey=#{secret_key}"
  end

  def cleanup
    @has_more = false
  end

  def get_objects(object_name, page, query_params)
    api_method = GET_OBJECT_METHOD[object_name]
    limit = 200
    params = {
      where: query_params,
      limit: limit,
      offset: limit * page
    }
    return_field = object_name
    response = make_api_call(api_method, params)
    result = JsonPath.on(response, "$.result.#{return_field}[:]")
    @has_more = result.count == limit
    return result
  end

  def make_api_call(method, params)
    request_id = (0...20).map { ('a'..'z').to_a[rand(26)] }.join
    data = { method: method, params: params, id: request_id }.to_json
    response = RestClient.post post_uri, data, content_type: :json, accept: :json
    JSON.parse(response.to_s)
  end
end
