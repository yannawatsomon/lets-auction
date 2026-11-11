module Bidding
  # A bidding rule the user broke. `code` goes into `{ error:, message: }`; the message is Thai
  # and says what happened, whether the bid is safe, and what to do next (SPEC UX).
  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(code, message, http_status = :unprocessable_content)
      @code = code
      @http_status = http_status
      super(message)
    end
  end
end
