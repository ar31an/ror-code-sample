class Click < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Indexing
  
  after_touch() { __elasticsearch__.index_document }

  belongs_to :country
  belongs_to :website
  belongs_to :campaign
  belongs_to :operating_system
  
  validates_presence_of :country_id, :campaign_id, :website_id, :operating_system_id

  index_name  "clicks_table"
  settings index: {
  } do
    mapping do
      indexes :id, type: 'integer'
      indexes :revenue, type: 'float'
      indexes :traffic_type, type: 'integer'
      indexes :website_id, type: 'integer'
      indexes :campaign_id, type: 'integer'
      indexes :country_id, type: 'integer'
      indexes :updated_at, type: "date", format: "yyyy-MM-dd'T'HH:mm:ss.SSSZZ"
    end
  end

  def as_indexed_json(options={})
    self.as_json({
      only: [:id, :website_id, :country_id, :campaign_id, :revenue, :traffic_type, :updated_at]
    })
  end

  ### ELASTICSEARCH METHODS ###
  class << self
    def count_all
      @clicks_definition = { size: 0, aggs: { counts: { value_count: { field: :_type } } } }
      __elasticsearch__.search(@clicks_definition).aggregations.try(:counts).try(:value).to_i
    end

    def impressions_revenue_stats
      agg = { size: 0, aggs: { stats_ranges: { date_range: {
              field: :updated_at, keyed: true, format: "yyyy-MM-dd HH:mm:ss",
              ranges: [ { key: "1 day ago", from: "now-1d" },
              { key: "7 days ago", from: "now-7d" },
              { key: "1 month ago", from: "now-1M" } ] },
              aggs: { revenue_stats: { sum: { field: :revenue } } } } } }
      response = __elasticsearch__.search(agg).aggregations.try(:stats_ranges).try(:buckets).to_h
      return response["1 month ago"], response["7 days ago"], response["1 day ago"]
    end

    def filter_data(options={})
      @clicks_definition = { size: 0, query: { filtered: { filter: { bool: { must: [] } } } }, aggs: {} }
      if options[:campaign_ids].present?
        @clicks_definition[:query][:filtered][:filter][:bool][:must][0] ||= {}
        @clicks_definition[:query][:filtered][:filter][:bool][:must][0][:terms] = { campaign_id: options[:campaign_ids] }
        @clicks_definition[:aggs] = { total_spendings: { sum: { field: :revenue } },
                                      total_counts: { value_count: { field: :_type } },
                                      campaign_sum: { terms: { field: :campaign_id },
                                      aggs: { revenue_sum: { sum: { field: :revenue } } } },
                                      campaign_countries: { terms: { field: :campaign_id },
                                      aggs: { ids: { terms: { field: :country_id } } } } }
      elsif options[:website_ids].present?
        @clicks_definition[:query][:filtered][:filter][:bool][:must][0] ||= {}
        @clicks_definition[:query][:filtered][:filter][:bool][:must][0][:terms] = { website_id: options[:website_ids] }
        @clicks_definition[:aggs] = { total_spendings: { sum: { field: :revenue } },
                                      total_counts: { value_count: { field: :_type } },
                                      website_sum: { terms: { field: :website_id },
                                      aggs: { revenue_sum: { sum: { field: :revenue } } } },
                                      website_traffic_types: { terms: { field: :website_id },
                                      aggs: { types: { terms: { field: :traffic_type } } } } }
      end

      if options[:start_date].present? && options[:end_date].present?
        @clicks_definition[:query][:filtered][:filter][:bool][:must][1] ||= {}
        @clicks_definition[:query][:filtered][:filter][:bool][:must][1][:range] = { updated_at: { gte:  options[:start_date], lte: options[:end_date], format: "dd/MM/yyyy"} }
      end
      __elasticsearch__.search(@clicks_definition).aggregations
    end
  end
end
