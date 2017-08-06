class AdsController < ApplicationController
  layout false
  protect_from_forgery except: :bt_ads
  before_filter :validate_api_key, only: [:bt_ads, :pub_af_redirect]
  before_filter :set_query_params, only: [:pub_af_redirect]

  def bt_ads
    if is_not_a_bot
      if is_mobile_request?
        render js: Uglifier.compile(render_to_string), formats: [:mobile]
      else
        render js: Uglifier.compile(render_to_string)
      end
    else
      render nothing: true
    end
  end

  def pub_af_redirect
    @query.merge!(traffic_type: Campaign::PAGE_REDIRECT)
    check_campaign
  end

  def compute_campaign
    @campaign, bid_rate, revenue = Campaign.search(@query)
    compute_campaign_and_redirect(bid_rate, revenue)
  end

  private

  def validate_api_key
    referer = request.env["HTTP_REFERER"] && URI.parse(request.env["HTTP_REFERER"])
    domain = (referer && referer.host) || request.referrer
    _runtime_web = Benchmark.ms {
      if params[:action] == 'pub_af_redirect'
        @website = Website.website_by_site_uuid(params[:siteid])
        if @website.blank?
          puts "Invalid Affiliate url #{params[:siteid]} for domain #{domain}"
          render text: { error: "Invalid Affiliate url #{params[:siteid]} for domain #{domain}", status: "404" }
        end
      else
        @website = Website.website_by_publisher_key(params[:key])
        unless @website
          puts "Invalid API key #{params[:key]} for domain #{domain}"
          render text: { error: "Invalid API key #{params[:key]} for domain #{domain}", status: "404" }
        else
          unless @website.approved?
            if @website.blocked?
              render text: { error: "The web affiliate url is currently blocked, kindly contact the web admin", status: "403" }
            else
              puts "Invalid domain #{domain}"
              render text: { error: "Invalid domain #{domain}", status: "500" }
            end
          else
            render text: { error: "Please validate your website first!", status: "403" } unless @website.is_valid?
          end
        end
      end
    }
    @my_logger ||= Logger.new("#{Rails.root}/log/campaign_redirects_log.log")  
    @my_logger.info("Website Validation time for #{@campaign.name} with Url: #{@campaign.url} is #{(sprintf "%.4f", _runtime_web)} ms.") if @campaign.present?
  end

  def is_not_a_bot
    browser = Browser.new(request.user_agent, accept_language: "en-us")
    !browser.bot?
  end

  def check_campaign
    _runtime = Benchmark.ms {
      options = { website_id: @website.id }
      flat_rate_campaigns = FlatRateCampaign.pick(options)
      if flat_rate_campaigns.count > 0
        campaigns = Campaign.fetch_flat_rate_campaigns(flat_rate_campaigns, @website.minimum_bid)
        if campaigns.present?
          @campaign = campaigns[rand(0..(campaigns.length-1))]
          @campaign.delay.update_attributes(status: Campaign::INACTIVE) if @campaign.views >= @campaign.impressions_cap
          compute_flat_rate_campaign
        else
          compute_campaign
        end
      else
        compute_campaign
      end
    }
    @my_logger ||= Logger.new("#{Rails.root}/log/campaign_redirects_log.log")
    @my_logger.info("Redirect time of #{@campaign.name} with Url: #{@campaign.url} is #{(sprintf "%.4f", _runtime)} ms.") if @campaign.present?
  end

  def set_query_params
    @country, @agent, @os, @query, @isp_info = Campaign.set_query_params(request)
    @isp = @isp_info.present? ? ServiceProvider.find_or_create_by(name: @isp_info.downcase) : ServiceProvider.find_or_create_by(name: "Not Specified".downcase)
    @query.merge!(blacklist_site_id: @website.id, website_content: @website.adult_content, website_minimum_bid: @website.minimum_bid)
  end

  def compute_campaign_and_redirect(bid_rate, revenue)
    browser = @agent.try(:name)
    os = @os.try(:name)
    if @campaign.present? && @campaign.url.present?
      @campaign.update_campaign_clicks(params[:action], @website, bid_rate, revenue, @country, @isp, @os, @agent)
      campaign_url = @campaign.url.sub(/#?\{site_id\}/, @website.publisher_key).sub(/#?\{geo\}/, @country.try(:name)||'').sub(/#?\{browser\}/, browser)
                      .sub(/#?\{os\}/, os).sub(/#?\{isp\}/, @isp.try(:name)||'').sub(/#?\{campaign_id\}/, @campaign.campaign_key)
                      .sub(/#?\{traffic_type\}/, @query[:traffic_type].to_s).sub(/#?\{carrier\}/, @isp.try(:name)||'')
      redirect_to campaign_url
    else
      voluum_campaign = VoluumCampaign.serve_rtb_campaign(@website.adult_content)
      voluum_campaign.update_voluum_clicks(params[:action], @website, @country, @isp, @os, @agent) if voluum_campaign.present?
      redirect_to (voluum_campaign.present? ? voluum_campaign.url : root_url )
    end
  end
end
