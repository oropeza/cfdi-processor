require 'test_helper'

class DownloadsControllerTest < ActionDispatch::IntegrationTest
  test 'should get received' do
    get downloads_received_url
    assert_response :success
  end

  test 'should get sent' do
    get downloads_sent_url
    assert_response :success
  end
end
