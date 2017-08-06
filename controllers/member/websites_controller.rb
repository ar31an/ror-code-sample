class Member::WebsitesController < Member::BaseController
  include Member::BaseHelper

  def index
    @websites = Website.get_websites(current_user.id, params[:search], params[:col], params[:o]).all

    all_time_data = Click.filter_data(website_ids: @websites.map(&:id))
    @all_time_clicks_count = all_time_data.try(:total_counts).try(:value)
    @all_time_spendings = all_time_data.try(:total_spendings).try(:value).try(:round, (2))
    @total_websites = @websites.count

    @websites = populate_websites_stats(@websites)
  end

  private

  def populate_websites_stats(websites)
    if websites.present?
      cost = Cost.first
      server_cost_per_click = cost.server + cost.location_api
      publisher_percentage = (cost.publisher_percentage / 100)

      website_ids = websites.map(&:id)
      data        = Click.filter_data(start_date: @start_date, end_date: @end_date, website_ids: website_ids)

      data.website_sum.buckets.each do |bucket|
        website = websites.detect { |w| w.id == bucket.to_h["key"] }
        if website.present?
          clicks                          = bucket.doc_count
          sum                             = bucket.try(:revenue_sum).try(:value)
          earning_per_click               = ((sum.to_f - (clicks.to_f * server_cost_per_click) ) * publisher_percentage) / clicks.to_f
          website.epv                     = (earning_per_click).finite? ? (earning_per_click) : 0.0
          website.ecpm                    = (earning_per_click).finite? ? (earning_per_click) * 1000 : 0.0
          website.filter_earning          = sum.to_f

          traffic_types = data.website_traffic_types.buckets.detect{|b| b.to_h["key"] == bucket.to_h["key"]}.try(:types).try(:buckets)
          if traffic_types.present?
            website.filter_pop_under_clicks = traffic_types.detect{|t| t.to_h["key"] == Campaign::POP_UNDER}.try(:doc_count)
            website.filter_redirect_clicks  = traffic_types.detect{|t| t.to_h["key"] == Campaign::PAGE_REDIRECT}.try(:doc_count)
            website.filter_back_clicks      = traffic_types.detect{|t| t.to_h["key"] == Campaign::BACK_BUTTON}.try(:doc_count)
          end            
        end
      end

      @clicks_count = data.try(:total_counts).try(:value)
      @earnings = data.try(:total_spendings).try(:value).try(:round, (2))
    end
    websites || []
  end
end
