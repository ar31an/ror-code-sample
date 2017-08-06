module ApplicationHelper

  def google_tag_manager_head
    render partial: 'shared/google_tag_manager_head' if Rails.env.production?
  end

  def google_tag_manager_body
    render partial: 'shared/google_tag_manager_body' if Rails.env.production?
  end

  def get_property_detail_path(address, muid)
    "/#{@current_company.custom_property_url.name.singularize}/#{address}/#{muid}"
  end

  def get_categories_redirect_path(url)
    "/#{@current_company.custom_property_url.name}/#{url}"
  end

  def get_properties_path(params={})
    if params.blank?
      "/#{@current_company.custom_property_url.name}"
    else
      neighbourhood_slug = params[:neighbourhood_slug].present? ? "/#{params[:neighbourhood_slug]}" : ''
      subdivision_slug   = params[:subdivision_slug].present? ? "/#{params[:subdivision_slug]}" : ''

      property_type_slug = params[:property_type_slug].present? ? "?property_type_slug=#{params[:property_type_slug]}" : ''
      range_slug         = params[:range].present? ? "?range=#{params[:range]}" : ''

      "/#{@current_company.custom_property_url.name}#{neighbourhood_slug}#{subdivision_slug}/#{property_type_slug}#{range_slug}"
    end
  end

end
