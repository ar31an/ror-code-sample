module Searchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Indexing

    after_touch() { __elasticsearch__.index_document }

    settings index: {
    } do
      mapping do
        indexes :name, type: 'string', analyzer: "english", fields: {
          raw: { 
            type:  "string",
            index: "not_analyzed"
          }
        }
        indexes :operating_system_id, type: 'integer'
        indexes :agent_id, type: 'integer'
        indexes :country_id, type: 'integer'
        indexes :total_budget, type: 'float'
        indexes :minimum_bid, type: 'float'
        indexes :views, type: 'integer'
        indexes :slug, type: 'string'
        indexes :is_active, type: 'boolean'
        indexes :is_flat_rate, type: 'boolean'
        indexes :active_all_day, type: 'boolean'
        indexes :status, type: 'integer'
        indexes :bid_rate, type: 'float'
        indexes :deleted_at, type: "date", format: "yyyy-MM-dd'T'HH:mm:ss.SSSZZ"
      end
    end

    def self.calculate_revenue(bid_rate)
      decimal_points = decimals(bid_rate) unless bid_rate.nil?
      return bid_rate + (get_number_string(decimal_points)+ "1").to_f unless decimal_points.nil?
    end

    def self.decimals(a)
      num = 0
      while(a != a.to_i)
          num += 1
          a *= 10
      end
      num   
    end

    def self.get_number_string(decimals_points)
      str = "."
      (decimals_points).times do 
        str = str + "0"
      end 
      str       
    end

    def self.search(options={}, name_query = nil)
      options = Hash[options.map { |k, v| [k.to_s, v] }]
      @proposed_campaign_definition = { query: {}, sort: {}}
      deleted_at_is_nil = { missing: { field: :deleted_at } }
      filter_traffic_type = { term: { traffic_type: options["traffic_type"]} }
      active_filter = { term: { is_active: true } }
      adult_landing_page_filter = { term: { adult_landing_page: options["website_content"] } }
      filter_q_4 = { term: { status: Campaign::APPROVED } }
      filter_q_0 = {}
      filter_q_0[:or] = []
      filter_q_0[:or] << { term: { "country_campaigns.country_id" => options["country_id"] }} if options["country_id"].present?
      filter_q_0[:or] << { term: { "country_campaigns.country_id" => Country.default_element_id }}
      filter_q_1 = { or: [ { term: { "campaign_operating_systems.operating_system_id" => options["operating_system_id"] } }, { term: { "campaign_operating_systems.operating_system_id" => OperatingSystem.default_element_id } } ] }
      filter_q_2 = { or: [ { term: { "campaign_agents.agent_id" => options["agent_id"] } }, { term: { "campaign_agents.agent_id" => Agent.default_element_id } } ] }
      filter_q_3 = { term: { "blacklist_websites.website_id" => options["blacklist_site_id"] } }
      non_flat_rate = { term: { is_flat_rate: false } }
      greater_than_website_bid_value =  { range: { minimum_bid: { gte: options["website_minimum_bid"] } } } 
      sort_q =  { minimum_bid: { order: "desc"} }
      @proposed_campaign_definition[:query] = { filtered: { filter: { bool: { must: [adult_landing_page_filter, deleted_at_is_nil, non_flat_rate, active_filter, filter_traffic_type, filter_q_0, filter_q_1, filter_q_2, filter_q_4, greater_than_website_bid_value],  must_not: [filter_q_3] } } } }
      @proposed_campaign_definition[:sort] = [sort_q]
      proposed_campaigns = __elasticsearch__.search(@proposed_campaign_definition).records
      if proposed_campaigns.results.present? && proposed_campaigns.to_a.present?
        highest_campaign = proposed_campaigns.to_a.first
        if proposed_campaigns.to_a.count > 1
          second_highest_campaigns = proposed_campaigns.to_a.second
          revenue = ( second_highest_campaigns.present? ? calculate_revenue(second_highest_campaigns.minimum_bid) : highest_campaign.minimum_bid )
          return highest_campaign, (second_highest_campaigns.present? ? second_highest_campaigns.minimum_bid : highest_campaign.minimum_bid), revenue
        else
          return highest_campaign, highest_campaign.minimum_bid, highest_campaign.minimum_bid
        end
      else
        return nil, nil, nil 
      end  
    end

    def self.get_campaigns(user_id, search, column_name, order)
      @campaign_definition = { query: { filtered: { query: { query_string: {} }, filter: { bool: { must: {} } } } }, sort: {} }
      sort_q = (column_name.present? && order.present?) ? { column_name => { "order" => order } } : {}
      @campaign_definition[:sort] = [sort_q, "_score"]
      @campaign_definition[:query][:filtered][:filter][:bool][:must] = { term: { user_id: user_id } }
      @campaign_definition[:query][:filtered][:query][:query_string] = { query: "*#{search}*", fields: ["name", "url"] }
      __elasticsearch__.search(@campaign_definition).page( 1 ).records
    end
  end

  module Indexing
    def as_indexed_json(options={})
      self.as_json(
        include: { 
          country_campaigns: { only: [:country_id] },
          campaign_agents: { only: [:agent_id] },
          campaign_operating_systems: { only: [:operating_system_id] },
          blacklist_websites: { only: [:website_id, :campaign_id] },
          flat_rate_campaigns: { only: [:website_id, :campaign_id] }
        })
    end
  end
end
