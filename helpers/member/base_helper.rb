module Member::BaseHelper

  def compute_graph_data(options={})
    approved_type_dates = Click.between_dates(options[:start_date], options[:end_date]).where("#{options[:type]}": options[:data].map(&:id)).group("#{options[:type]}", 'DATE(created_at)')
    bid_rate = approved_type_dates.sum(:bid_rate)
    @click_revenues = {}
    approved_type_dates.count.map do |data, click_counts|
      approved_type = options[:data].detect { |d| d.id == data[0] }
      @click_revenues[[approved_type.try(:name), data[1]]] = [click_counts, bid_rate.select{|k, v| (k[0] == data[0]) && (k[1] == data[1])}.values[0]]
    end
  end
end
