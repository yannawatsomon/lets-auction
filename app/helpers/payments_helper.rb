module PaymentsHelper
  # MOCK QR picture for #55: three finder squares and a pattern seeded by the reference, so each
  # QR looks different. It is NOT a scannable PromptPay code, on purpose: nobody can pay a demo.
  def mock_qr_svg(reference, size: 25)
    rng = Random.new(reference.bytes.sum * 7919)
    finder = ->(x, y) { [ [ x, y, 7, "#15171C" ], [ x + 1, y + 1, 5, "#FFFFFF" ], [ x + 2, y + 2, 3, "#15171C" ] ] }
    in_finder = ->(x, y) { (x < 8 && y < 8) || (x >= size - 8 && y < 8) || (x < 8 && y >= size - 8) }

    cells = []
    size.times do |y|
      size.times do |x|
        cells << tag.rect(x:, y:, width: 1, height: 1) if !in_finder.call(x, y) && rng.rand < 0.48
      end
    end
    squares = (finder.call(0, 0) + finder.call(size - 7, 0) + finder.call(0, size - 7)).map do |x, y, w, fill|
      tag.rect(x:, y:, width: w, height: w, fill:)
    end

    tag.svg(safe_join(cells + squares), viewBox: "-2 -2 #{size + 4} #{size + 4}", class: "payment-qr-code",
      fill: "#15171C", role: "img", "aria-label": "QR ตัวอย่าง สแกนไม่ได้", "shape-rendering": "crispEdges")
  end

  def mm_ss(seconds) = format("%<m>02d:%<s>02d", m: seconds / 60, s: seconds % 60)
end
