module UserSearchable
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
    include Indexing

    after_commit on: [:create] do
      __elasticsearch__.index_document
    end

    after_commit on: [:update] do
      begin 
        __elasticsearch__.update_document
      rescue Elasticsearch::Transport::Transport::Errors::Conflict => e
        begin
          retries ||= 0
          user = { query: { filtered: { filter: { term: { id: self.id } } } } }
          old_record = self.class.__elasticsearch__.search(user).records.to_a.first
          old_record.advertiser_balance = self.advertiser_balance if self.advertiser_balance.to_f != old_record.advertiser_balance.to_f
          old_record.publisher_balance = self.publisher_balance if self.publisher_balance.to_f != old_record.publisher_balance.to_f
          old_record.admin_earning = self.admin_earning if self.admin_earning.to_f != old_record.admin_earning.to_f
          old_record.__elasticsearch__.update_document
        rescue Elasticsearch::Transport::Transport::Errors::Conflict => e
          retry if (retries += 1) < 3
        end  
      end
    end

    after_commit on: [:destroy] do
      __elasticsearch__.delete_document
    end

    settings index: {
      analysis: {
        filter: {
          autocomplete_filter: { 
            type: 'ngram',
            min_gram: 2,
            max_gram: 10
          }
        },
        analyzer: {
          autocomplete: {
            type: "custom",
            tokenizer: "standard",
            filter: [
              "lowercase",
              "autocomplete_filter" 
            ]
          }
        }
      }
    } do
      mapping do
        indexes :name, type: 'string', analyzer: "autocomplete"
        indexes :user_name, type: 'string', analyzer: "autocomplete"
        indexes :approve, type: 'boolean'
        indexes :email_verified, type: 'boolean'
      end
    end

    def self.all_users(options)
      @users = { query: { wildcard: { user_name: options.downcase } }}
      return __elasticsearch__.search(@users).records.to_a
    end

    def self.get_user_by_id(options)
      @users = { query: { filtered: { filter: { term: { id: options } } } } }
      return self.class.elasticsearch__.search(@users).records.to_a
    end
  end
end
