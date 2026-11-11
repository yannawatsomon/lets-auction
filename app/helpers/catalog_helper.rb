module CatalogHelper
  def catalog_status_label(status)
    { ongoing: "กำลังประมูล", upcoming: "ยังไม่เริ่ม", ended: "จบแล้ว" }.fetch(status.to_sym)
  end

  def catalog_auction_label(auction_type)
    { "english" => "English", "sealed_first_price" => "First-price sealed-bid" }.fetch(auction_type)
  end

  def catalog_local_path(path)
    path if path.is_a?(String) && path.match?(%r{\A/(?!/)[^\s\\\x00-\x1f\x7f]*\z})
  end

  def catalog_navigation_url(url, filters, pages, anchor: nil)
    attributes = Catalog::Filters::FIELDS.to_h { |field| [ field, filters.public_send(field) ] }
    query = attributes.merge(pages).reject { |_key, value| value.empty? }.to_query
    "#{url}?#{query}#{anchor ? "##{anchor}" : ''}"
  end
end
