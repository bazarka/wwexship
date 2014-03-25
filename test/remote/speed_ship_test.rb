require 'test_helper'

class SpeedShipTest < Test::Unit::TestCase

  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations
    @options = fixtures(:speed_ship)
    @carrier = SpeedShip.new(@options)
  end

  def test_find_rates_without_package_number
    response = nil
    response = begin
      @carrier.find_rates(@locations[:real_home_as_residential],
                          @locations[:real_home_as_residential],
                          @packages[:just_ounces])
    rescue ResponseError => e
      assert_equal "Shipment type is required", e.message
    end
  end

  def test_find_rates_without_package_type
    response = nil
    response = begin
      @carrier.find_rates(@locations[:real_home_as_residential],
                          @locations[:real_home_as_residential],
                          @packages[:just_zero_grams])
    rescue ResponseError => e
      assert_equal "Shipment type is required", e.message
    end
  end


  def test_response_parsing
    options = {:shipment_type => 'R'}
    assert_nothing_raised do
      find_rates_response = @carrier.find_rates(@locations[:real_home_as_commercial],
                                                @locations[:real_home_as_commercial],
                                                @packages[:just_grams], options)

      assert !find_rates_response.rates.blank?
      find_rates_response.rates.each do |rate|
        assert_instance_of String, rate.service_name[:service_name]
      end
    end
  end


  def test_book_shipment_remote
    options = {}
    find_rates_response = @carrier.find_rates(@locations[:real_home_as_commercial],
                                              @locations[:real_home_as_commercial],
                                              @packages[:just_grams], options)
    option= {:bill_to_country_code => 'us', :ups_account_number => 'E5A138', :billing_shipping_charge_to_options => 'Paid By Sender'}
    book_response = @carrier.book_shipment(@locations[:beverly_hills], @locations[:beverly_hills], find_rates_response.rates.first, option, @packages.values_at(:just_grams))
  end

  def test_void_shipment_remote
    options = {:shipment_type => 'R'}
    find_rates_response = @carrier.find_rates(@locations[:real_home_as_commercial],
                                              @locations[:real_home_as_commercial],
                                              @packages[:just_grams], options)
    option= {:bill_to_country_code => 'us', :ups_account_number => 'E5A138', :billing_shipping_charge_to_options => 'Paid By Sender'}
    book_response = @carrier.book_shipment(@locations[:real_home_as_residential], @locations[:real_home_as_residential], find_rates_response.rates.first, option, @packages.values_at(:just_grams))
    nr = []
    book_response.each do |k, book|
      nr << k[:air_bill_number]
    end
    void_response = @carrier.void_shipment(nr)
    nr.each do |number|
      assert_equal "This shipment is successfully voided", void_response[number]
    end


  end

end