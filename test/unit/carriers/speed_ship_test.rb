require 'test_helper'
class SpeedShipTest < Test::Unit::TestCase

  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier = SpeedShip.new(
        :loginId => '',
        :password => '',
        :licenseKey => '',
        :accountNumber => ''
    )

  end

  def test_response_parsing
    options = {'shipment_type' => 'For multi piece/package and single piece/package shipments'}
    mock_response = xml_fixture('speed_ship/find_rates_response')
    @carrier.expects(:commit).returns(mock_response)
    @response = @carrier.find_rates(@locations[:beverly_hills],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:just_grams), options)


    name = []
    price = []
    code =[]
    estimate_id=[]
    @response.rates.each do |w|
      puts w.inspect
      name << w.service_name[:service_name]
      price << w.service_name[:total_price]
      code << w.service_name[:service_code]
      estimate_id << w.service_name[:rate_estimate_id]
    end

    assert_equal ["UPS Next Day Air Early A.M.",
                  "UPS Next Day Air",
                  "UPS Next Day Air Saver",
                  "2nd Day Air A.M.",
                  "2nd Day Air",
                  "3 Day Select"
                 ], name

    assert_equal ["388.43", "194.03", "180.46", "182.76", "154.65", "146.24"], price
    assert_equal ["1DM", "1DA", "1DP", "2DM", "2DA", "3DS"], code
    assert_equal ["2042447-14",
                  "2042447-01",
                  "2042447-13",
                  "2042447-59",
                  "2042447-02",
                  "2042447-12"], estimate_id
    @rest = @response

  end


  def test_response_book_shipment_parsing
    opt = {'shipment_type' => 'For multi piece/package and single piece/package shipments'}
    mock_response = xml_fixture('speed_ship/find_rates_response')
    @carrier.expects(:commit).returns(mock_response)
    find_rates_response = @carrier.find_rates(@locations[:beverly_hills],
                                              @locations[:beverly_hills],
                                              @packages.values_at(:just_grams), opt)
    mock_response = xml_fixture('speed_ship/book_shipment_response')
    @carrier.expects(:commit).returns(mock_response)
    option= {:bill_to_country_code => 'us', :ups_account_number => 'E5A138', :billing_shipping_charge_to_option => 'Paid By Sender'}
    book_response = @carrier.book_shipment(@locations[:beverly_hills], @locations[:beverly_hills], find_rates_response.rates.first, option, @packages.values_at(:just_grams))

    book_response.each do |k, v|

      assert_equal "1ZE5A1381591431893", k[:air_bill_number]
    end

  end


  def test_void_response_parsing_return_success
    table = ['1ZE5A1381593412874']
    mock_response = xml_fixture('speed_ship/void_shipment_response')
    @carrier.expects(:commit).returns(mock_response)
    void = @carrier.void_shipment(table)
    assert_equal "This shipment is successfully voided", void['1ZE5A1381593412874']
  end
end