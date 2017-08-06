class Campaign < ActiveRecord::Base
  require 'open-uri'
  include Searchable
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged
  
  is_impressionable
  index_name  "campaigns"
  
  belongs_to :user
  
  has_many :clicks
  has_many :country_campaigns, dependent: :destroy
  has_many :countries, through: :country_campaigns
  has_many :campaign_operating_systems, dependent: :destroy
  has_many :operating_systems, through: :campaign_operating_systems 
  has_many :feedbacks, as: :feedable, dependent: :destroy
  has_many :campaign_agents, dependent: :destroy
  has_many :agents, through: :campaign_agents   
  has_many :blacklist_websites, dependent: :destroy
  has_many :websites, through: :blacklist_websites

  validates_uniqueness_of :name, scope: :slug, message: "Must be Unique."
  validates_presence_of :name, :url, :traffic_type, :total_budget, :minimum_bid
  validates :url, format: { with: URI::regexp(%w(http https)), message: 'is not valid. Please enter a valid domain with http or https.' }, on: :create
  
  attr_accessor :row_country_names, :row_clicks_count, :row_revenue_sum
  accepts_nested_attributes_for :countries, reject_if: :all_blank, allow_destroy: true
  serialize :active_hours, Hash

  scope :my_campaigns, -> (user_id) {where(user_id: user_id)}
  scope :pending_campaigns, -> {where(status: Campaign::PENDING)}
  scope :approved_campaigns, -> {where(status: Campaign::APPROVED)}
  scope :created_this_month, -> {where('created_at > ?', Time.now.beginning_of_month)}
  scope :with_funds, -> {where('total_budget > minimum_bid')}
  
  MINIMUM_BID = 0.001

  FIREFOX      = 1
  CHROME       = 2
  SAFARI       = 3
  OPERA        = 4
  EXPLORER     = 5

  BROWSERS = {FIREFOX => 'Firefox', CHROME => 'Chrome', SAFARI => 'Safari',  OPERA => 'Opera', EXPLORER => 'Explorer'}

  def slug_candidates
    [:name, [:name, :id_for_slug]]
  end

  def id_for_slug
    generated_slug = normalize_friendly_id(name)
    campaigns = self.class.where('slug REGEXP :pattern', pattern: "#{generated_slug}(-[0-9]+)?$")
    campaigns = campaigns.where.not(id: id) unless new_record?
    campaigns.count + 1
  end

  def browser_name
    BROWSERS[self.browser]
  end

  [FIREFOX, CHROME, SAFARI, OPERA, EXPLORER].each do |attribute|
    define_method :"#{BROWSERS[attribute].downcase}?" do
      self.agent == attribute
    end
  end

  def update_campaign_clicks(action, website, bid_rate, revenue, country, isp, os, agent)
    if self.user_id.present? && website.user_id.present?
      pub_share = 0.0
      advertiser_balance = 0.0
      if (self.user.advertiser_balance.to_f >= self.minimum_bid) && ((self.spent + revenue) <= self.total_budget)
        Campaign.update_counters(self.id, { spent: revenue, views: 1 })
        pub_share = publisher_share(revenue, website.user_id)
        admin_share(revenue, pub_share)
        if (self.user.advertiser_balance.to_f - revenue.to_f) >= 0
          self.user.update_attributes(advertiser_balance: self.user.advertiser_balance.to_f - revenue.to_f)
        else
          self.user.update_attributes(advertiser_balance: 0)
        end

        if action == "redirect"
          Website.update_counters(website.id, { back_clicks: 1, earning: pub_share })
          traffic_type = BACK_BUTTON
        elsif action == "pop_under"
          Website.update_counters(website.id, { pop_under_clicks: 1, earning: pub_share })
          traffic_type = POP_UNDER
        else
          Website.update_counters(website.id, { redirect_clicks: 1, earning: pub_share })
          traffic_type = PAGE_REDIRECT
        end
        Click.create(bid_rate: bid_rate, revenue: revenue, website_id: website.id, campaign_id: self.id, country_id: country.try(:id), operating_system_id: os.try(:id), service_provider_id: isp.try(:id), agent_id: agent.try(:id), traffic_type: traffic_type)
      else
        self.update_attributes(is_active: false, status: OUT_OF_FUND)
      end
    end
  end

  def publisher_share(revenue, user_id)
    Rails.logger.info "AAAAAAAA: #{revenue} #{user_id}"
    cost = Cost.first
    share = 0.0
    if cost.present?
      revenue_with_cost = revenue - (cost.server + cost.location_api)
      share =  revenue_with_cost * (cost.publisher_percentage / 100)
    else
      share =  revenue * 0.5
    end  
    user = User.find(user_id)
    user.update_attributes(publisher_balance: user.publisher_balance + share) if user.present?
    share
  end

  def admin_share(revenue, pub_share)
    user = User.find_by_admin(true)
    admin_earning = revenue.to_f - pub_share.to_f
    if user.present? 
      user.update_attributes(admin_earning: user.admin_earning + admin_earning)
    end
  end

  private

  def self.get_isp_info(request)
    begin
      ip_info = Rails.cache.fetch("isp_details_ip_info_#{request.remote_ip}", expires_in: 12.hours) do
        current_ip_address = request.remote_ip && request.remote_ip !~ /\A(127.0.0.1)|(\:\:1)\z/ ? request.remote_ip : '119.160.103.254'
        if current_ip_address.present? 
          ipinfo = Geoip2.city_isp_org("#{current_ip_address}") rescue nil
          ipinfo
        end  
      end
      [ip_info.try(:traits).try(:isp), ip_info.try(:country).try(:names).try(:en)]
    rescue
      ['', '']
    end
  end
end
