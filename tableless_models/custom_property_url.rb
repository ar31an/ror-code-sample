class CustomPropertyUrl < Struct.new(:id, :name)
  CUSTOM_URLS = [
    { id: 1, name: "properties" },
    { id: 2, name: "luxury-homes" }
  ]

  class << self
    def find(id)
      if _d = CUSTOM_URLS.find{ |d| d[:id] == id.to_i }
        hash_to_object(_d)
      end
    end

    def all
      CUSTOM_URLS.map do |d|
        hash_to_object(d)
      end
    end

    private

    def hash_to_object(_d)
      self.new(_d[:id], _d[:name])
    end
  end
end