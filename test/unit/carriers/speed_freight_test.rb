require 'test_helper'
class SpeedFreightTest < Test::Unit::TestCase
  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations

    @carrier = SpeedFreight.new(
        :loginId => '',
        :password => '',
        :licenseKey => '',
        :accountNumber => ''
    )

  end

  def test_response_parsing

    mock_response = xml_fixture('speed_freight/find_rates_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates(@locations[:beverly_hills],
                                   @locations[:beverly_hills],
                                   @packages.values_at(:chocolate_stuff))
    name = []
    price = []
    id = []
    response.rates.each do |w|

      name << w.service_name[:name]
      price << w.service_name[:total_price]
      id << w.service_name[:shipment_quote_id]
    end
    assert_equal ["Cal State Express",
                  "Central Transport",
                  "Dependable Highway Express",
                  "Best Overnite Express",
                  "Old Dominion",
                  "Daylight Transport",
                  "SAIA",
                  "Towne Air Freight, Inc.",
                  "Central Freight Lines, Inc",
                  "Estes Express Lines",
                  "USF Reddaway",
                  "SAIA",
                  "Old Dominion",
                  "Con-Way",
                  "YRC",
                  "UPS Freight"
                 ], name
    assert_equal ["106.24",
                  "107.36",
                  "110.2",
                  "113.96",
                  "120.64",
                  "135.93",
                  "138.14",
                  "141.97",
                  "145.56",
                  "149.5",
                  "154.38",
                  "160.36",
                  "172.19",
                  "183.54",
                  "203.6",
                  "230.49"], price
    assert_equal ["1860848-001",
                  "1860848-002",
                  "1860848-003",
                  "1860848-004",
                  "1860848-005",
                  "1860848-006",
                  "1860848-007",
                  "1860848-008",
                  "1860848-009",
                  "1860848-010",
                  "1860848-011",
                  "1860848-012",
                  "1860848-013",
                  "1860848-014",
                  "1860848-015",
                  "1860848-016"], id
  end


  def test_response_book_shipment_parsing
    mock_response = xml_fixture('speed_freight/find_rates_response')
    @carrier.expects(:commit).returns(mock_response)
    find_rates_response = @carrier.find_rates(@locations[:beverly_hills],
                                              @locations[:beverly_hills],
                                              @packages.values_at(:chocolate_stuff))
    mock_response = xml_fixture('speed_freight/book_shipment_response')
    @carrier.expects(:commit).returns(mock_response)
    options = {:shipment_date => '03/22/2014', :shipment_ready_time => '08:00 am', :shipment_closing_time => '09:00 pm'}
    book_response = @carrier.book_shipment(@locations[:beverly_hills], @locations[:beverly_hills], find_rates_response.rates.first, options, @packages.values_at(:just_grams))

    book_response.each do |book|
      assert_equal "42651718", book[:number]
    end
  end


  def test_void_response_parsing_should_return_true
    table = ['42695609', '42695618']
    mock_response = xml_fixture('speed_freight/void_shipment_response')
    @carrier.expects(:commit).returns(mock_response)
    void = @carrier.void_shipment(table)
    void.each do |k, v|
      assert_equal "true", v
    end
  end

  def test_pro_number_parsing
    table = ['42695609', '42695618']
    mock_response = xml_fixture('speed_freight/pro_number_response')
    @carrier.expects(:commit).returns(mock_response)
    pro_number_response = @carrier.pro_number(table)
    pro_number_response.each do |k, v|
      assert_equal "N/A", v
    end

  end

end