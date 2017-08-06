module DefaultElementId
  extend ActiveSupport::Concern

  included do
    def self.default_element_id(reset=false)
      (self.__elasticsearch__.search(self::DEFAULT_ELEMENT_NAME).results.try(:first).try(:_id).try(:to_i) rescue 0) || 0
    end
  end
end
