module ActiveMerchant #:nodoc:
  module Shipping #:nodoc:
    class Location
      attr_reader :residential_indicator, :email
      alias_method :old_initialize, :initialize
      def initialize(options = {})
        old_initialize(options)
        @email = options[:email]
        @residential_indicator = options[:residential_indicator]
      end
    end
  end
end
