class Member::CampaignsController < Member::BaseController
  include Member::BaseHelper

  def index
    @campaigns = Campaign.get_campaigns(current_user.id, params[:search], params[:col], params[:o]).all

    all_time_data          = Click.filter_data(campaign_ids: @campaigns.map(&:id))
    @all_time_clicks_count = all_time_data.try(:total_counts).try(:value)
    @all_time_spendings    = all_time_data.try(:total_spendings).try(:value).try(:round, (2))
    @total_campaigns       = @campaigns.count

    @campaigns = populate_campaigns_stats(@campaigns)
  end

  def populate_graph
    campaigns = Campaign.get_campaigns(current_user.id, params[:search], params[:col], params[:o])
    compute_graph_data(start_date: @start_date, end_date: @end_date, type: "campaign_id", data: campaigns)
  end

  private

  def populate_campaigns_stats(campaigns)
    if campaigns.present?
      data               = Click.filter_data(start_date: @start_date, end_date: @end_date, campaign_ids: campaigns.map(&:id))
      campaign_countries = data.campaign_countries.buckets.map{|bucket| bucket.ids.buckets.map{|b| b.to_h["key"]}}.flatten.compact.uniq
      countries          = campaign_countries.present? ? Hash[Country.where(id: campaign_countries).select("id, name").map { |c| [c.id, c.name] }] : {}
      data.campaign_countries.buckets.each do |bucket|
        campaign = campaigns.detect { |c| c.id == bucket.to_h["key"] }
        if campaign
          country_ids                = bucket.ids.buckets.map{|b| b.to_h["key"]}
          campaign.row_country_names = country_ids.map{|c| countries[c]}
          campaign.row_clicks_count  = bucket.doc_count
          campaign.row_revenue_sum   = data.campaign_sum.buckets.detect{|x| x.to_h["key"] == bucket.to_h["key"]}.try(:revenue_sum).try(:value)
        end
      end

      @clicks_count = data.try(:total_counts).try(:value)
      @spendings = data.try(:total_spendings).try(:value).try(:round, (2))
    end
    campaigns || []
  end

  def populate_single_campaign_stats
    data                        = Click.filter_data(start_date: @start_date, end_date: @end_date, campaign_ids: [@campaign.id])
    country_ids                 = data.campaign_countries.buckets.map{|c| c.ids.buckets.map{|x| x.to_h["key"]}}.flatten.compact.uniq
    country_names               = country_ids.present? ? Country.where(id: country_ids).pluck(:name) : []
    @campaign.row_country_names = country_names
    @campaign.row_clicks_count  = data.try(:total_counts).try(:value)
    @campaign.row_revenue_sum   = data.try(:total_spendings).try(:value)
  end
end
