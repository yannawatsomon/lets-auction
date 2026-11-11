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
end
