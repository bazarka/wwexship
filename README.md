# WWEXSHIP - Worldwide Express carrier


This library extends Active Shipping and adds support for Worldwide Express carrier. This carrier provides two services Speed Freight and Speed Ship that this library implements.

Comparing to the Active Shipping the library adds additionally to find rates and track packages also a possibility to book and void shipments. Because of that the requests are more complex.

To understand all options available please have a look in the documentation provided by the carrier.


## Supported Shipping Carrier

* [Worldwide Express](http://wwex.com/)

## Installation

    add it to your [Gemfile](http://gembundler.com/).

## Sample Usage

### Speed Freight service

    require 'active_shipping'
    require 'wwexship'

    # Initialize Speed Freight

    speed_freight  = ActiveMerchant::Shipping::SpeedFreight.new(loginId: 'login', password: 'secret', licenseKey: 'your license', accountNumber: 'your account #')

    # Create a new package. In case of this service package is meant to be a container containing packages (here lines) inside.
    packages = [
        ActiveMerchant::Shipping::Package.new(   100,
                                                [93, 10],
                                                cylinder: true,
                                                'units' => 'Pallet',
                                                'number' => 2 ,  [number of packages (lines) inside]
                                                'lines' => {'line1' =>
                                                                {:class_type => 50,
                                                                :weight => 4,
                                                                :description => 'desc',
                                                                :piece_type => 'TBE',
                                                                :number_pieces => 4},
                                                            'line2' =>
                                                                {:class_type => 55,
                                                                :weight => 4,
                                                                :description => 'desc',
                                                                :piece_type => 'BAL',
                                                                :number_pieces => 4}})
    ]


    origin = ActiveMerchant::Shipping::Location.new(        country: 'US',
                                                            state: 'CA',
                                                            city: 'Beverly Hills',
                                                            zip: '90210', address1:
                                                            '455 N. Rexford Dr.',
                                                            address2: '3rd Floor',
                                                            phone: '1-310-285-1013',
                                                            company: 'WebWizard')

    destination = ActiveMerchant::Shipping::Location.new(   :country => 'US',
                                                            :city => 'New York',
                                                            :state => 'NY',
                                                            :company => 'micro',
                                                            :phone => '1-613-580-2400',
                                                            :address1 => '780 3rd Avenue',
                                                            :address2 => 'Suite  2601',
                                                            :zip => '10017')


    # Find out how much it'll be.
    response = speed_freight.find_rates(origin, destination, packages, {})

    # Get the rates from the carrier
    rates_response =  response.rates

    # Book Shipment
    shipment = speed_freight.book_shipment(origin, destination, rates_response[selected rate from array], {:shipment_date => '03/22/2014', :shipment_ready_time => '08:00 am', :shipment_closing_time => '09:00 pm'}, packages)

    # Get the shipment confirmation from an array
    confirmation = shipment[0]

    # Void Shipment
    void = speed_freight.void_shipment([confirmation[:number]])

    # Get PRO number
    pro = speed_freight.pro_number([confirmation[:number]])


### Speed Ship service

    require 'active_shipping'
    require 'wwexship'

    # initialize speed ship

    speed_ship  = ActiveMerchant::Shipping::SpeedShip.new(loginId: 'login', password: 'secret', licenseKey: 'your license', accountNumber: 'your account #')

    # Create a new package. In case of this service package is meant to be a container containing packages (here lines) inside.
    packages = [
        ActiveMerchant::Shipping::Package.new(   100,
                                                [93, 10],
                                                cylinder: true,
                                                package_number: '1',
                                                package_type: 'UPS Letter')
    ]


    origin = ActiveMerchant::Shipping::Location.new(        country: 'US',
                                                            state: 'CA',
                                                            city: 'Beverly Hills',
                                                            zip: '90210', address1:
                                                            '455 N. Rexford Dr.',
                                                            address2: '3rd Floor',
                                                            phone: '1-310-285-1013',
                                                            company: 'WebWizard')

    destination = ActiveMerchant::Shipping::Location.new(   country: 'US',
                                                            city: 'New York',
                                                            state: 'NY',
                                                            company: 'micro',
                                                            phone: '1-613-580-2400',
                                                            address1: '780 3rd Avenue',
                                                            address2: 'Suite  2601',
                                                            zip: '10017')


    # Find out how much it'll be.
    response = speed_ship.find_rates(origin, destination, packages, {})

    # Get the rates from the carrier
    rates_response =  response.rates

    # Book Shipment
    shipments = speed_ship.book_shipment(origin, destination, rates_response[selected rate from array], {:bill_to_country_code => 'us', :ups_account_number => 'E5A138', :billing_shipping_charge_to_options => 'Paid By Sender'}, packages)

    # Get the shipment confirmation from an array
    shipment_confirmation = shipments[0]

    # Void Shipment
    void = speed_ship.void_shipment([shipment_confirmation[:air_bill_number]])




## Running the tests

After installing dependencies with `bundle install`, you can run the unit tests with `rake test:units` and the remote tests with `rake test:remote`. The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in ~/test/fixtures.yml, and the format of that file can be seen in the included [fixtures.yml](https://github.com/Shopify/active_shipping/blob/master/test/fixtures.yml).

## Contributors

* Jaroslaw Wozniak
* Marcin Jablonski

## Legal Notice

Unless otherwise noted in specific files, all code in the WWEXSHIP project is under the copyright and license described in the included MIT-LICENSE file.
