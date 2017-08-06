class OperatingSystem < ActiveRecord::Base
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks
  include Indexing
    after_touch() { __elasticsearch__.index_document }

  has_many :campaign_operating_systems, dependent: :destroy
  has_many :campaigns, through: :campaign_operating_systems
  has_many :clicks, dependent: :destroy

  DEFAULT_ELEMENT_NAME = 'All Operating Systems'
  include ::DefaultElementId

  settings do
    mapping do
      indexes :id, type: 'integer'
      indexes :name, type: 'string'
    end
  end

  def as_indexed_json(options={})
    self.as_json({
      only: [:id, :name]
    })
  end
  ### ELASTICSEARCH ###

  class << self
    def pick(options={})
      query_hash = {
        query: {
          match: {
            name: "*#{options}*"
          }
        }
      }
      response = self.__elasticsearch__.search(query_hash)
      response.records.to_a
    end
  end
end
