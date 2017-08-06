class Website < ActiveRecord::Base

  belongs_to :user
  
  has_many :clicks
  has_many :feedbacks, as: :feedable, dependent: :destroy
  has_many :campaigns, through: :flat_rate_campaigns
  has_many :flat_rate_campaigns, dependent: :destroy
  
  has_one :affiliated_link, dependent: :destroy
  
  attr_accessor :epv, :ecpm, :filter_pop_under_clicks, :filter_redirect_clicks, :filter_back_clicks, :filter_earning

  scope :my_websites, -> (user_id) {where(user_id: user_id)}
  scope :pending_websites, -> {where(status: Website::PENDING)}
  scope :approved_websites, -> {where(status: Website::APPROVED)}
  scope :created_this_month, -> {where('created_at > ?', Time.now.beginning_of_month)}

  validates_presence_of :name

  PENDING  = 1
  APPROVED = 2
  REJECTED = 3
  BLOCKED  = 4

  STATUSES = {PENDING => 'Pending', APPROVED => 'Approved',  REJECTED => 'Rejected', BLOCKED => 'Blocked' }

  [PENDING, APPROVED, REJECTED, BLOCKED].each do |attribute|
    define_method :"#{STATUSES[attribute].downcase}?" do
      self.status == attribute
    end
  end

  def generate_uuid
    self.update_attributes(site_uuid: Digest::SHA1.hexdigest("#{self.id}")[0,8], pub_uuid: Digest::SHA1.hexdigest("#{self.user_id}")[0,8], is_affiliate_link: true)
  end
end
