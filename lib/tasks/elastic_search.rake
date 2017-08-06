namespace :elastic_search do

  task reindex_clicks: :environment do
    start_time = Time.now
    puts "Starting Reindexing for Clicks at: #{start_time}"
    Click.__elasticsearch__.client.indices.delete index: Click.index_name rescue nil
    Click.__elasticsearch__.client.indices.create index: Click.index_name, body: { settings: Click.settings.to_hash, mappings: Click.mappings.to_hash }
    Click.includes(:campaign, :website, :country, :operating_system, :agent).import
    puts "Completed Reindexing for Clicks at: #{Time.now} in #{Time.now - start_time}"
  end

  task reindex_dependencies: :environment do
    elastic_classes = [OperatingSystem, Agent, Country]
    elastic_classes.each do | klass |
      index_name = "#{klass}_#{Rails.env}"
      client = klass.__elasticsearch__.client
      klass.__elasticsearch__.create_index! force: true
      klass.find_in_batches(batch_size: 1000) do |group|
        group_for_bulk = group.map do |a|
          { index: { _id: a.id, data: a.as_indexed_json } }
        end
        klass.__elasticsearch__.client.bulk(index: index_name, type: klass, body: group_for_bulk)
      end
    end
  end

  task createindexes_dependencies: :environment do
    elastic_classes = [OperatingSystem, Agent, Country]
    elastic_classes.each do | klass |
      index_name = "#{klass}_#{Rails.env}"
      client = klass.__elasticsearch__.client
      klass.__elasticsearch__.create_index! force: true
      klass.import
    end
  end
end
