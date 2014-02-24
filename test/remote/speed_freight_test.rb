require 'test_helper'

class SpeedFreightTest < Test::Unit::TestCase

  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations
    @options = fixtures(:speed_freight)
    @carrier = SpeedFreight.new(@options
    )
  end

  def test_find_rates_without_lines
    response = nil
    response = begin
      @carrier.find_rates(@locations[:real_home_as_residential],
                          @locations[:real_home_as_residential],
                          @packages[:declared_value])
    rescue ResponseError => e
      assert_equal "Please add at lease one line item details to handling unit 1 to generate shipment quote", e.message
    end
  end

  def test_find_rates_without_units
    response = nil
    response = begin
      @carrier.find_rates(@locations[:real_home_as_residential],
                          @locations[:real_home_as_residential],
                          @packages[:largest_gold_bar])
    rescue ResponseError => e
      assert_equal "Type of handling unit for Handling Unit #1 is required", e.message
    end
  end

  def test_find_rates_without_number

    response = nil
    response = begin
      @carrier.find_rates(@locations[:real_home_as_residential],
                          @locations[:real_home_as_residential],
                          @packages[ :big_half_pound ])
    rescue ResponseError => e
      assert_equal "Type of handling unit for Handling Unit #1 is required", e.message
    end

  end

  def test_response_remote
    assert_nothing_raised do
      @response = @carrier.find_rates(@locations[:real_home_as_residential],
                                      @locations[:real_home_as_residential],
                                      @packages.values_at(:chocolate_stuff))

      assert !@response.rates.blank?
      @response.rates.each do |rate|
        assert_instance_of String, rate.service_name[:name]
      end
    end
  end

  def test_book_shipment_remote
    response_rates = @carrier.find_rates(@locations[:real_home_as_residential],
                                         @locations[:real_home_as_residential],
                                         @packages.values_at(:chocolate_stuff))

    options = {:shipment_date => '03/22/2014', :shipment_ready_time => '08:00 am', :shipment_closing_time => '09:00 pm'}
    book_response = @carrier.book_shipment(@locations[:real_home_as_residential], @locations[:real_home_as_residential], response_rates.rates.first, options, @packages.values_at(:just_grams))


  end

  def test_void_shipment_remote
    response_rates = @carrier.find_rates(@locations[:real_home_as_residential],
                                         @locations[:real_home_as_residential],
                                         @packages.values_at(:chocolate_stuff))

    options = {:shipment_date => '03/22/2014', :shipment_ready_time => '08:00 am', :shipment_closing_time => '09:00 pm'}
    book_response = @carrier.book_shipment(@locations[:real_home_as_residential], @locations[:real_home_as_residential], response_rates.rates.first, options, @packages.values_at(:just_grams))

    nr = []
    book_response.each do |k, book|
      nr << k[:number]
    end
    void_response = @carrier.void_shipment(nr)
    nr.each do |number|
      assert_equal "true", void_response[number]
    end


  end
end