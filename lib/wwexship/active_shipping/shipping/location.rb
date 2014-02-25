module ActiveMerchant #:nodoc:
  module Shipping #:nodoc:
    class Location
      attr_reader :residential_indicator, :email

      def initialize(options = {})
        @country = (options[:country].nil? or options[:country].is_a?(ActiveMerchant::Country)) ?
            options[:country] :
            ActiveMerchant::Country.find(options[:country])
        @postal_code = options[:postal_code] || options[:postal] || options[:zip]
        @province = options[:province] || options[:state] || options[:territory] || options[:region]
        @city = options[:city]
        @name = options[:name]
        @address1 = options[:address1]
        @address2 = options[:address2]
        @address3 = options[:address3]
        @phone = options[:phone]
        @fax = options[:fax]
        @email = options[:email]
        @company_name = options[:company_name] || options[:company]
        @residential_indicator = options[:residential_indicator]

        self.address_type = options[:address_type]
      end

    end
  end
end
