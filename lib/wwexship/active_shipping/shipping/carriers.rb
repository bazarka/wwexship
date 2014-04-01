require 'wwexship/active_shipping/shipping/carriers/speed_ship'

module ActiveMerchant
  module Shipping
    module Carriers
      class <<self
        alias_method :old_all, :all
         def all
           w = old_all
           return w + [SpeedShip]
        end
      end
    end
  end
end