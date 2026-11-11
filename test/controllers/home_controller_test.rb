require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "root renders auction landing page" do
    get root_url
    assert_response :success
    assert_select "h1", /Lets Auction/
    assert_select "h2", /ประมูลที่กำลังเปิด/
    assert_select "a", /ดูประมูลทั้งหมด/
  end
end
