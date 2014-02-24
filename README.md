# WWEXSHIP


This library extends Active Shipping and adds support for Worldwide Express carrier. This carrier provides two services Speed Freight and Speed Ship that this library implements.

Comparing to the Active Shipping the library adds additionally to find rates and track packages also a possibility to book and void shipments. Because of that the requests are more complex


## Supported Shipping Carriers

* [Worldwide Express](http://wwex.com/)

## Installation

    add it to your [Gemfile](http://gembundler.com/).

## Sample Usage

### Compare rates from the carrier

    require 'active_shipping'
    require 'wwexship'

    # Package up a poster and a Wii for your nephew.
    packages = [
        ActiveMerchant::Shipping::Package.new(   100,
                                                [93, 10],
                                                cylinder: true,
                                                'units' => 'Pallet',
                                                'number' => 2 ,
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

    destination = ActiveMerchant::Shipping::Location.new(   country: 'US',
                                                            state: 'CA',
                                                            city: 'Beverly Hills',
                                                            zip: '90210', address1:
                                                            '455 N. Rexford Dr.',
                                                            address2: '3rd Floor',
                                                            phone: '1-310-285-1013',
                                                            company: 'WebWizard')


    # Find out how much it'll be.
    w = ActiveMerchant::Shipping::SpeedFreight.new(loginId: 'login', password: 'secret', licenseKey: 'your license', accountNumber: 'your account #')
    response = w.find_rates(origin, destination, packages, {dupa: 'dupa'})


    options = {:shipment_date => '03/22/2014', :shipment_ready_time => '08:00 am', :shipment_closing_time => '09:00 pm'}
    rates_response =  response.rates.first
    table = []

    book = w.book_shipment(origin, destination , rates_response, options, packages)
    book1 = w.book_shipment(origin, destination , rates_response, options, packages)


    table << book[0][:number]
    table << book1[0][:number]
    #void = w.void_shipment(table)
    pro = w.pro_number(table)


## Running the tests

After installing dependencies with `bundle install`, you can run the unit tests with `rake test:units` and the remote tests with `rake test:remote`. The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in ~/test/fixtures.yml, and the format of that file can be seen in the included [fixtures.yml](https://github.com/Shopify/active_shipping/blob/master/test/fixtures.yml).

## Contributors

* Jaroslaw Wozniak
* Marcin Jablonski

## Legal Notice

Unless otherwise noted in specific files, all code in the Active Shipping project is under the copyright and license described in the included MIT-LICENSE file.
