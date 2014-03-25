# -*- encoding: utf-8 -*-
# -*- encoding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class SpeedShip < Carrier
      self.retry_safe = true

      cattr_accessor :default_options
      cattr_reader :name
      @@name = "SpeedShip"

      TEST_URL = "http://app6.wwex.com:8080/s3fWebService/services/SpeedShip2Service"
      LIVE_URL = "http://app6.wwex.com:8080/s3fWebService/services/SpeedShip2Service"

      #RESOURCES = {
      #    :rates => 'ups.app/xml/Rate',
      #    :track => 'ups.app/xml/Track'
      #}

      PICKUP_CODES = HashWithIndifferentAccess.new({
                                                       :daily_pickup => "01",
                                                       :customer_counter => "03",
                                                       :one_time_pickup => "06",
                                                       :on_call_air => "07",
                                                       :suggested_retail_rates => "11",
                                                       :letter_center => "19",
                                                       :air_service_center => "20"
                                                   })

      CUSTOMER_CLASSIFICATIONS = HashWithIndifferentAccess.new({
                                                                   :wholesale => "01",
                                                                   :occasional => "03",
                                                                   :retail => "04"
                                                               })

      # these are the defaults described in the UPS API docs,
      # but they don't seem to apply them under all circumstances,
      # so we need to take matters into our own hands
      DEFAULT_CUSTOMER_CLASSIFICATIONS = Hash.new do |hash, key|
        hash[key] = case key.to_sym
                      when :daily_pickup then
                        :wholesale
                      when :customer_counter then
                        :retail
                      else
                        :occasional
                    end
      end


      # From http://en.wikipedia.org/w/index.php?title=European_Union&oldid=174718707 (Current as of November 30, 2007)
      EU_COUNTRY_CODES = ["GB", "AT", "BE", "BG", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"]

      US_TERRITORIES_TREATED_AS_COUNTRIES = ["AS", "FM", "GU", "MH", "MP", "PW", "PR", "VI"]


      DELIVERY_OPTION = {
          "Delivery Confirmation" => "1",
          "Signature Required" => "2",
          "Adult Signature Required" => "3"
      }

      PACKAGE_TYPE = {
          "Customer Packaging" => "00",
          "UPS Letter" => "01",
          "UPS Tube" => "03",
          "UPS PAK" => "04",
          "UPS Express Box - Small" => "S",
          "UPS Express Box - Medium" => "M",
          "UPS Express Box - Large" => "L"
      }


      DUTIES_AND_TAXES = {
          "Paid By Sender" => "PBS",
          "Bill To Receiver" => "BTR",
          "Bill Third Party" => "BTP"
      }

      SHIPMENT_TYPE = {
          "For multi piece/package and single piece/package shipments" => "S",
          "For single piece/package return shipments" => "R"
      }

      def requirements
        [:loginId, :password, :licenseKey, :accountNumber]
      end


      def void_shipment(shipment_numbers)
        opt = {"SOAPAction" => "urn:voidUPSShipment", "Content-Type" => "text/xml"}
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/",
                           'xmlns:ser' => "http://service.v1.speedship2.s3f.soapservice.ws.wwex.com",
                           'xmlns:xsd' => "http://common.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                           'xmlns:xsd1' => "http://voidshipment.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd") do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        build_void_request(shipment_numbers, body)
        response = commit(:track, main.to_s, opt)
        parse_void_response(response)
      end

      def find_rates(origin, destination, packages, options={})
        opt = {"SOAPAction" => "urn:getUPSServiceDetails", "Content-Type" => "text/xml"}
        origin, destination = upsified_location(origin), upsified_location(destination)
        options = @options.merge(options)
        packages = Array(packages)
        main = create_xml(origin, destination, packages, options)
        response = commit(:rates, save_request(main.to_s), opt)

        parse_rate_response(origin, destination, packages, response, options)
      end

      def find_tracking_info(tracking_numbers, options={})
        opt = {"SOAPAction" => "urn:trackUPSShipment", "Content-Type" => "text/xml"}
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')


        main = XmlNode.new('soapenv:Envelope', 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/",
                           'xmlns:ser' => "http://service.v1.speedship2.s3f.soapservice.ws.wwex.com",
                           'xmlns:xsd' => "http://common.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                           'xmlns:xsd1' => "http://trackshipment.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd") do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        build_tracking_request(tracking_numbers, options, body)
        response = commit(:track, main.to_s, opt)
        parse_tracking_response(response, options)
      end

      def book_shipment(origin, destination, rates_response, options, packages)
        opt = {"SOAPAction" => "urn:shipRatedService", "Content-Type" => "text/xml"}
        main = create_book_xml(origin, destination, rates_response, options, packages)

        response = commit(:track, main.to_s, opt)
        parse_book_response(response, options)
      end

      def ups_shipment(origin, destination, rates_response, options, packages)
        opt = {"SOAPAction" => "urn:shipUPSShipment", "Content-Type" => "text/xml"}
        main = create_ups_xml(origin, destination, rates_response, options, packages)

        response = commit(:track, main.to_s, opt)
        parse_ups_response(response, options)
      end

      protected


      def build_void_request(shipment_numbers, xml_request)
        xml_request << XmlNode.new('ser:voidUPSShipment') do |void_ups|
          void_ups << XmlNode.new('ser:voidShipmentRequest') do |shipment_request|
            shipment_request << XmlNode.new('xsd1:shipmentNumbers') do |numbers|

              shipment_numbers.each do |shipment_number|
                numbers << XmlNode.new('xsd:shipmentNumber', shipment_number)
              end
            end
          end
        end
      end


      def create_book_xml(origin, destination, rates_response, options, packages)
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/",
                           'xmlns:ser' => "http://service.v1.speedship2.s3f.soapservice.ws.wwex.com",
                           'xmlns:xsd' => "http://common.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                           'xmlns:xsd1' => "http://ship.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd") do |main_env|

          main_env << header
          main_env << body
        end
        build_access_request(header)
        build_book_request(origin, destination, rates_response, body, options, packages)
        return main.to_s
      end


      def create_ups_xml(origin, destination, rates_response, options, packages)

        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')

        main = XmlNode.new('soapenv:Envelope', 'xmlns:soapenv' => "http://schemas.xmlsoap.org/soap/envelope/",
                           'xmlns:ser' => "http://service.v1.speedship2.s3f.soapservice.ws.wwex.com",
                           'xmlns:xsd' => "http://common.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                           'xmlns:xsd1' => "http://ship.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                           'xmlns:xsd2' => "http://rateestimate.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd") do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        build_ups_request(origin, destination, rates_response, body, options, packages)
        return main.to_s

      end


      def create_xml(origin, destination, packages, options)

        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
                                                "xmlns:ser" => "http://service.v1.speedship2.s3f.soapservice.ws.wwex.com",
                                                "xmlns:xsd" => "http://common.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd",
                                                "xmlns:xsd1" => "http://rateestimate.v1.speedship2.s3f.soapservice.ws.wwex.com/xsd"}) do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        build_rate_request(origin, destination, packages, body, options)

        return main.to_s
      end


      def upsified_location(location)
        if location.country_code == 'US' && US_TERRITORIES_TREATED_AS_COUNTRIES.include?(location.state)
          atts = {:country => location.state}
          [:zip, :city, :address1, :address2, :address3, :phone, :fax, :address_type].each do |att|
            atts[att] = location.send(att)
          end
          Location.new(atts)
        else
          location
        end
      end

      def build_access_request(xml_request)
        xml_request << XmlNode.new('ser:authenticationDetail') do |authentication_detail|
          authentication_detail << XmlNode.new('ser:authenticationToken') do |access_request|
            access_request << XmlNode.new('xsd:loginId', @options[:loginId])
            access_request << XmlNode.new('xsd:password', @options[:password])
            access_request << XmlNode.new('xsd:licenseKey', @options[:licenseKey])
            access_request << XmlNode.new('xsd:accountNumber', @options[:accountNumber])
          end
        end
        xml_request.to_s
      end


      def build_ups_request(origin, destination, response, xml_request, options, packages)

        imperial = ['US', 'LR', 'MM'].include?(origin.country)
        xml_request << XmlNode.new('ser:shipUPSShipment') do |ups_shipment|
          ups_shipment << XmlNode.new('ser:shipUPSRequest') do |ups_request|
            build_charges_detail(ups_request, response, options)
            email_shipping_label_detail(ups_request, options)
            build_receiver_full_address(ups_request, destination, options)
            build_shipment_address(ups_request, options)
            send_email_notification_detail(ups_request, options)
            build_sender_full_address(ups_request, origin, options)
            shipment_full_service_options(ups_request, options)
            shipment_packages_with_add_info(ups_request, packages, imperial, options)
            build_shipment_pickup_info(ups_request, options)
            ups_request << XmlNode.new('xsd1:shipmentServiceCode', response)

          end
        end
        xml_request.to_s
      end


      def build_book_request(origin, destination, rates_response, xml_request, options, packages)

        xml_request << XmlNode.new('ser:shipRatedService') do |rated_service|
          rated_service << XmlNode.new('ser:shipRatedServiceRequest') do |rated_service_request|
            build_charges_detail(rated_service_request, rates_response, options)
            build_receiver_full_address(rated_service_request, destination, options)
            build_shipment_address(rated_service_request, options)
            build_sender_full_address(rated_service_request, origin, options)
            build_shipment_additional_service_options(rated_service_request, options)
            build_shipment_package_additional_info(rated_service_request, packages)
            rated_service_request << XmlNode.new('xsd1:shipmentRateEstimateId', rates_response.service_name[:rate_estimate_id])
          end
        end
        xml_request.to_s
      end

      def build_receiver_full_address(xml_request, destination, options)
        xml_request << XmlNode.new('xsd1:receiverFullAddress') do |address|
          address << XmlNode.new('xsd:city', destination.city)
          address << XmlNode.new('xsd:countryCode', destination.country_code)
          address << XmlNode.new('xsd:postalCode', destination.postal_code)
          address << XmlNode.new('xsd:residentialIndicator', destination.residential_indicator)
          address << XmlNode.new('xsd:state', destination.state)
          address << XmlNode.new('xsd1:addressLine1', destination.address1)
          address << XmlNode.new('xsd1:addressLine2', destination.address2)
          address << XmlNode.new('xsd1:addressLine3', destination.address3)
          address << XmlNode.new('xsd1:companyOrName', destination.company)
          address << XmlNode.new('xsd1:emailAddress', destination.email)
          address << XmlNode.new('xsd1:phoneNumber', destination.phone)
          if options['additional_parameters'].present?
            build_additional_parameters(address, options)
          end
          address << XmlNode.new('xsd1:contact', destination.phone)

        end
      end

      def build_sender_full_address(xml_request, origin, options)
        xml_request << XmlNode.new('xsd1:senderFullAddress') do |sender_address|
          sender_address << XmlNode.new('xsd:city', origin.city)
          sender_address << XmlNode.new('xsd:countryCode', origin.country_code)
          sender_address << XmlNode.new('xsd:postalCode', origin.zip)
          sender_address << XmlNode.new('xsd:residentialIndicator', origin.residential_indicator)
          sender_address << XmlNode.new('xsd:state', origin.state)
          sender_address << XmlNode.new('xsd1:addressLine1', origin.address1)
          sender_address << XmlNode.new('xsd1:addressLine2', origin.address2)
          sender_address << XmlNode.new('xsd1:addressLine3', origin.address3)
          sender_address << XmlNode.new('xsd1:companyOrName', origin.company)
          sender_address << XmlNode.new('xsd1:emailAddress', origin.email)
          sender_address << XmlNode.new('xsd1:phoneNumber', origin.phone)
          if options['additional_parameters'].present?
            build_additional_parameters(sender_address, options)
          end
          sender_address << XmlNode.new('xsd1:sentBy', origin.name)
        end

      end


      def build_shipment_address(xml_response, options)
        if options[:return_shipment].present?
          xml_response << XmlNode.new('xsd1:returnShipmentAddress') do |shipment_address|
            shipment_address << XmlNode.new('xsd:city', options[:return_shipment][:city])
            shipment_address << XmlNode.new('xsd:countryCode', options[:return_shipment][:country_code])
            shipment_address << XmlNode.new('xsd:postalCode', options[:return_shipment][:postal_code])
            shipment_address << XmlNode.new('xsd:residentialIndicator', options[:return_shipment][:residential])
            shipment_address << XmlNode.new('xsd:state', options[:return_shipment][:state])
            shipment_address << XmlNode.new('xsd:addressLine1', options[:return_shipment][:address1])
            shipment_address << XmlNode.new('xsd:addressLine2', options[:return_shipment][:address2])
            shipment_address << XmlNode.new('xsd:addressLine3', options[:return_shipment][:address3])
            shipment_address << XmlNode.new('xsd:companyOrName', options[:return_shipment][:company])
            shipment_address << XmlNode.new('xsd:emailAddress', options[:return_shipment][:email_address])
            shipment_address << XmlNode.new('xsd:phoneNumber', options[:return_shipment][:phone])
            shipment_address << XmlNode.new('xsd:contact', options[:return_shipment][:phone])
          end
        end

      end

      def email_shipping_label_detail(xml_request, options)
        xml_request << XmlNode.new('xsd1:emailShippingLabelDetail') do |email_shipping|
          if options[:email_shipping_label_detail].present?
            email_shipping << XmlNode.new('xsd1:emailShippingLabelIndicator', options[:email_shipping_label_detail][:indicator])
            email_shipping << XmlNode.new('xsd1:fromEmailAddress', options[:email_shipping_label_detail][:email_from])
            email_shipping << XmlNode.new('xsd1:personalMessage', options[:email_shipping_label_detail][:personal_message])
            email_shipping << XmlNode.new('xsd1:recipientEmailAddresses', options[:email_shipping_label_detail][:recipient_email_addresses])
          end
        end

      end

      def send_email_notification_detail(xml_request, options)
        xml_request << XmlNode.new('xsd1:sendEmailNotificationDetail') do |notification_detail|
          notification_detail << XmlNode.new('xsd1:notificationEmailDetails') do |notification_email_details|
            notification_email_details << XmlNode.new('xsd1:emailMessage', options[:notification_email_message])
            if options[:notification_email_details].present?
              options[:notification_email_details].each do |detail|
                notification_email_details << XmlNode.new('xsd1:notificationEmailDetail') do |notif_detail|
                  notif_detail << XmlNode.new('xsd1:emailAddress', detail[:email_address])
                  notif_detail << XmlNode.new('xsd1:emailDeliveryIndicator', detail[:delivery_indicator])
                  notif_detail << XmlNode.new('xsd1:emailExceptionIndicator', detail[:exception_indicator])
                  notif_detail << XmlNode.new('xsd1:emailShipIndicator', detail[:ship_indicator])
                end
              end
            end
            notification_email_details << XmlNode.new('xsd1:sendUndeliverableEmail', options[:send_undeliverable_email])
            notification_email_details << XmlNode.new('xsd1:undeliverableEmailAddress', options[:undeliverable_email_address])

          end
          notification_detail << XmlNode.new('xsd1:sendEmailNotificationIndicator', options[:send_email_notification_indicator])
        end

      end

      def shipment_full_service_options(xml_request, options)
        xml_request << XmlNode.new('xsd1:shipmentFullServiceOptions') do |full_service_options|
          schedulePickupIndicator(full_service_options, options)
          build_rate_additional_parameters(full_service_options, options)
          build_shipment_additional_service_options(full_service_options, options)
        end

      end


      def build_shipment_additional_service_options(xml_response, options)

        xml_response << XmlNode.new('xsd1:shipmentAdditionalServiceOptions') do |additional_service_options|
          additional_service_options << XmlNode.new('xsd1:emailShippingLabelDetail') do |shipping_detail|
            shipping_detail << XmlNode.new('xsd1:emailShippingLabelIndicator', options[:shipping_label_indicator])
            shipping_detail << XmlNode.new('xsd1:fromEmailAddress', options[:from_email_address])
            shipping_detail << XmlNode.new('xsd1:personalMessage', options[:personal_message])
            shipping_detail << XmlNode.new('xsd1:recipientEmailAddresses', options[:recipient_email_addresses])
          end
          additional_service_options << XmlNode.new('xsd1:schedulePickupDetail') do |schedule_pickup|
            build_shipment_pickup_info(schedule_pickup, options)
          end
          if options[:notification_email].present?
            additional_service_options << XmlNode.new('xsd1:sendEmailNotificationDetail') do |send_email_notification|

              send_email_notification << XmlNode.new('xsd1:notificationEmailDetails') do |notification_email_details|
                notification_email_details << XmlNode.new('xsd1:emailMessage', options[:notification_email][:message])
                notification_email_details << XmlNode.new('xsd1:notificationEmailDetail') do |email_detail|

                  email_detail << XmlNode.new('xsd1:emailAddress', options[:notification_email][:email_address])
                  email_detail << XmlNode.new('xsd1:emailDeliveryIndicator', options[:notification_email][:delivery_indicator])
                  email_detail << XmlNode.new('xsd1:emailExceptionIndicator', options[:notification_email][:exception_indicator])
                  email_detail << XmlNode.new('xsd1:emailShipIndicator', options[:notification_email][:email_ship_indicator])
                end
                notification_email_details << XmlNode.new('xsd1:sendUndeliverableEmail', options[:notification_email][:send_undeliverable_email])
                notification_email_details << XmlNode.new('xsd1:undeliverableEmailAddress', options[:notification_email][:undeliverable_email_address])
              end
              send_email_notification << XmlNode.new('xsd1:sendEmailNotificationIndicator', options[:notification_email][:send_email_notification_indicator])
            end

            additional_service_options << XmlNode.new('xsd1:senderReceiptIndicator', options[:notification_email][:sender_receipt_indicator])
            additional_service_options << XmlNode.new('xsd1:shipmentLabelSize', options[:notification_email][:shipment_label_size])
            additional_service_options << XmlNode.new('xsd1:shipperReleaseIndicator', options[:notification_email][:shipper_release_indicator])
          end
        end

      end

      def build_shipment_pickup_info(xml_request, options)
        xml_request << XmlNode.new('xsd1:shipmentPickupInfo') do |pickup_info|
          if options[:pickup].present?
            pickup_info << XmlNode.new('xsd1:city', options[:pickup][:city])
            pickup_info << XmlNode.new('xsd1:countryCode', options[p: ickup][:country_code])
            pickup_info << XmlNode.new('xsd1:postalCode', options[:pickup][:postal_code])
            pickup_info << XmlNode.new('xsd1:residentialIndicator', options[:pickup][:residentialIndicator])
            pickup_info << XmlNode.new('xsd1:state', options[:pickup][:state])
            pickup_info << XmlNode.new('xsd1:addressLine1', options[:pickup][:address1])
            pickup_info << XmlNode.new('xsd1:addressLine2', options[:pickup][:address2])
            pickup_info << XmlNode.new('xsd1:addressLine3', options[:pickup][:address3])
            pickup_info << XmlNode.new('xsd1:companyOrName', options[:pickup][:company_or_name])
            pickup_info << XmlNode.new('xsd1:emailAddress', options[:pickup][:email])
            pickup_info << XmlNode.new('xsd1:phoneNumber', options[:pickup][:phone])
            pickup_info << XmlNode.new('xsd1:contact', options[:pickup][:contact])
            pickup_info << XmlNode.new('xsd1:pickupByTime', options[:pickup][:pick_by_time])
            pickup_info << XmlNode.new('xsd1:pickupDate', options[:pickup][:pick_date])
            pickup_info << XmlNode.new('xsd1:pickupFloor', options[:pickup][:pick_floor])
            pickup_info << XmlNode.new('xsd1:pickupLocation', options[:pickup][:pick_location])
            pickup_info << XmlNode.new('xsd1:pickupRoom', options[:pickup][:pick_room])
            pickup_info << XmlNode.new('xsd1:pickupType', options[:pickup][:pick_type])
            pickup_info << XmlNode.new('xsd1:readyTime', options[:pickup][:ready_time])
          end
        end

      end

      def build_shipment_package_additional_info(xml_request, packages)
        xml_request << XmlNode.new('xsd1:shipmentPackageAdditionalInfo') do |additional_info|
          additional_info << XmlNode.new('xsd1:shipmentPackageDescriptions') do |shipment_desc|
            if packages.present?
              packages.each do |package|
                shipment_desc << XmlNode.new('xsd1:shipmentPackageDescription') do |package_desc|
                  package_desc << XmlNode.new('xsd1:DNCVIndicator', package.options[:DNCVIndicator])
                  package_desc << XmlNode.new('xsd1:descriptionOfGoods', package.options[:descriptionOfGoods])
                end
              end
            end
          end
          additional_info << XmlNode.new('xsd1:shipmentReferences') do |shipment_references|

            packages.each do |package|
              if package.options[:references].present?
                package.options[:references].each do |reference|
                  shipment_references << XmlNode.new('xsd1:shipmentReference') do |shipment_reference|
                    shipment_reference << XmlNode.new('xsd1:packageNumber', reference[:package_number])
                    shipment_reference << XmlNode.new('xsd1:shipmentReference1', reference[:shipment_reference1])
                    shipment_reference << XmlNode.new('xsd1:shipmentReference2', reference[:shipment_reference2])
                    shipment_reference << XmlNode.new('xsd1:shipmentReferenceBarcode', reference[:shipment_reference_barcode])
                  end
                end
              end
            end
          end

        end
      end

      def shipment_packages_with_add_info(xml_request, packages, imperial, options)
        xml_request << XmlNode.new('xsd1:shipmentPackagesWithAddInfo') do |shipment_with_add_info|
          if packages.present?
            packages.each do |package|
              shipment_with_add_info << XmlNode.new('xsd1:shipmentPackageWithAddInfo') do |package_with_add_info|
                build_shipment_additional_service_options(package_with_add_info, options)
                build_shipment_package_info(package_with_add_info, package, imperial, options)
              end
            end
          end
        end
      end

      def build_charges_detail(xml_request, response, options)
        xml_request << XmlNode.new('xsd1:billChargesToDetail') do |bill_charges|
          bill_charges << XmlNode.new('xsd1:billDutiesAndTaxesToDetail') do |bill_detail|
            bill_detail << XmlNode.new('xsd1:billDutiesAndTaxesToInfo') do |duties_taxes|
              duties_taxes << XmlNode.new('xsd1:billToCountryCode', options[:bill_to_country_code])
              duties_taxes << XmlNode.new('xsd1:billToPostalCode', options[:bill_to_zip])
              duties_taxes << XmlNode.new('xsd1:billToUPSAccountNumber', options[:ups_account_number])
            end
            bill_detail << XmlNode.new('xsd1:billDutiesAndTaxesToOption', options[:duties_and_taxes_options])
          end
          bill_charges << XmlNode.new('xsd1:billShippingChargeToDetail') do |shipping_charge|
            shipping_charge << XmlNode.new('xsd1:billShippingChargeToInfo') do |shipping_info|
              shipping_info << XmlNode.new('xsd1:associatedShipperUPSAccount', options[:associated_shipper_ups_Account])
              shipping_info << XmlNode.new('xsd1:billDeclaredValueChargesToShipper', options[:value_charges_to_shipper])
              shipping_info << XmlNode.new('xsd1:billToCountryCode', options[:shipping_bill_to_country_code])
              shipping_info << XmlNode.new('xsd1:billToPostalCode', options[:shipping_bill_to_postal_code])
              shipping_info << XmlNode.new('xsd1:billToUPSAccountNumber', options[:ups_account_number])
            end
            shipping_charge << XmlNode.new('xsd1:billShippingChargeToOption', DUTIES_AND_TAXES[options[:billing_shipping_charge_to_options]])
          end

        end
      end

      def schedulePickupIndicator(xml_request, options)
        xml_request << XmlNode.new('xsd1:additionalParameters') do |additional_parameters|
          if options[:additional_parameters].present?
            options[:additional_parameters].each do |parameter|
              additional_parameters << XmlNode.new('xsd:shipmentParameter') do |shipment_parameter|
                shipment_parameter << XmlNode.new('xsd:name', parameter[:name])
                shipment_parameter << XmlNode.new('xsd:value', parameter[:value])
              end
            end
          end
        end

      end


      def build_additional_parameters_rates(xml_request, options)
        xml_request << XmlNode.new('xsd:additionalParameters') do |additional_parameters|
          if options[:additional_parameters].present?
            options[:additional_parameters].each do |parameter|
              additional_parameters << XmlNode.new('xsd:shipmentParameter') do |shipment_parameter|
                shipment_parameter << XmlNode.new('xsd:name', parameter[:name])
                shipment_parameter << XmlNode.new('xsd:value', parameter[:value])
              end
            end
          end
        end

      end

      def build_rate_additional_parameters(xml_request, options)
        xml_request << XmlNode.new('xsd1:rateServiceOptions') do |service_options|
          service_options << XmlNode.new('xsd2:additionalParameters') do |additional_parameters|
            if options[:rate_service_options].present?
              options[:rate_service_options].each do |service_option|
                additional_parameters << XmlNode.new('xsd:shipmentParameter') do |shipment_parameter|
                  shipment_parameter << XmlNode.new('xsd:name', service_option[:name])
                  shipment_parameter << XmlNode.new('xsd:value', service_option[:value])
                end
              end
            end
          end
          service_options << XmlNode.new('xsd2:carbonNeutralIndicator', options[:carbon_neutral_indicator])
          service_options << XmlNode.new('xsd2:codIndicator', options[:cod_indicator])
          service_options << XmlNode.new('xsd2:confirmDeliveryIndicator', options[:confirm_delivery_indicator])
          service_options << XmlNode.new('xsd2:deliveryOnSatIndicator', options[:delivery_on_sat_indicator])
          service_options << XmlNode.new('xsd2:handlingChargeIndicator', options[:handling_charge_indicator])
          service_options << XmlNode.new('xsd2:returnLabelIndicator', options[:return_label_indicator])
          service_options << XmlNode.new('xsd2:schedulePickupIndicator', options[:schedule_pickup_indicator])
          if options[:shipment_type].present?
            service_options << XmlNode.new('xsd2:shipmentType', options[:shipment_type])
          else
            service_options << XmlNode.new('xsd2:shipmentType', "R")
          end
        end

      end


      def build_rate_request(origin, destination, packages, xml_request, options)
        imperial = ['US', 'LR', 'MM'].include?(origin.country)
        packages = Array(packages)

        xml_request << XmlNode.new('ser:getUPSServiceDetails') do |service_details|
          service_details << XmlNode.new('ser:upsServiceDetailRequest') do |detail_request|
            detail_request << XmlNode.new('xsd1:serviceOptions') do |service_options|
              build_service_options_node(service_options, options)
            end


            detail_request << XmlNode.new('xsd1:shipFrom') do |ship_from|
              build_location_node(origin, ship_from)
            end
            detail_request << XmlNode.new('xsd1:shipTo') do |ship_to|
              build_location_node(destination, ship_to)
            end


            detail_request << XmlNode.new('xsd1:shipmentPackages') do |shipments|
              build_shipment_packages(packages, imperial, shipments, options={})
            end
          end
        end

      end

      def build_shipment_packages(packages, imperial, xml_request, options={})
        packages.each do |package|
          xml_request << XmlNode.new('xsd:shipmentPackage') do |shipment_package|
            build_package(shipment_package, package, options, imperial)
          end
        end

      end

      def build_shipment_package_info(xml_request, package, imperial, options={})
        xml_request << XmlNode.new('xsd1:shipmentPackageInfo') do |shipment_package_info|
          build_package(shipment_package_info, package, options, imperial)
        end
      end


      def build_package(shipment_package, package, options, imperial)

        build_additional_parameters_rates(shipment_package, options)
        shipment_package << XmlNode.new('xsd:additonalHandling', package.options[:additional_handling])
        shipment_package << XmlNode.new('xsd:codPaymentForm', package.options[:cod_payment_form])
        shipment_package << XmlNode.new('xsd:codValue', package.options[:value_cod])
        shipment_package << XmlNode.new('xsd:confirmDeliveryOption', DELIVERY_OPTION[package.options[:delivery_option]])
        shipment_package << XmlNode.new('xsd:handlingChargeAmount', package.options[:handling_charge_amount])
        shipment_package << XmlNode.new('xsd:handlingChargeUOM', package.options[:UOM])
        if imperial
          shipment_package << XmlNode.new('xsd:height', package.inches[2])
        else
          shipment_package << XmlNode.new('xsd:height', package.cm[2])
        end
        shipment_package << XmlNode.new('xsd:insuranceValue', package.options[:insurance_value])
        shipment_package << XmlNode.new('xsd:largePackage', package.options[:large_package])
        if imperial
          shipment_package << XmlNode.new('xsd:length', package.inches[0])
        else
          shipment_package << XmlNode.new('xsd:length', package.cm[0])
        end
        shipment_package << XmlNode.new('xsd:packageNumber', package.options[:package_number])
        if package.options[:package_type].present?
          shipment_package << XmlNode.new('xsd:packageType', PACKAGE_TYPE[package.options[:package_type]])
        end

        if imperial
          shipment_package << XmlNode.new('xsd:weight', package.pounds)
          shipment_package << XmlNode.new('xsd:width', package.inches[1])

        else
          shipment_package << XmlNode.new('xsd:weight', package.kg)
          shipment_package << XmlNode.new('xsd:width', package.cm[1])
        end

      end


      def build_service_options_node(service_options, options= {})

        service_options << XmlNode.new('xsd1:additionalParameters') do |additional_parameter|
          if options[:additional_parameters].present?
            options[:additional_parameters].each do |k, v|
              additional_parameter << XmlNode.new('xsd:shipmentParameter') do |shipment_parameter|
                shipment_parameter << XmlNode.new('xsd:name', v[:name])
                shipment_parameter << XmlNode.new('xsd:value', v[:value])
              end
            end
          end
        end
        service_options << XmlNode.new('xsd1:carbonNeutralIndicator', options[:carbon_indicator])
        service_options << XmlNode.new('xsd1:codIndicator', options[:cod_indicator])
        service_options << XmlNode.new('xsd1:confirmDeliveryIndicator', options[:confirm_delivery_indicator])
        service_options << XmlNode.new('xsd1:deliveryOnSatIndicator', options[:delivery_sat_indicator])
        service_options << XmlNode.new('xsd1:handlingChargeIndicator', options[:handling_charge_indicator])
        service_options << XmlNode.new('xsd1:returnLabelIndicator', options[:return_label_indicator])
        service_options << XmlNode.new('xsd1:schedulePickupIndicator', options[:scheduled_delivery_indicator])
        if options[:shipment_type].present?
          service_options << XmlNode.new('xsd1:shipmentType', options[:shipment_type])
        else
          service_options << XmlNode.new('xsd1:shipmentType', "R")
        end
      end

      def build_location_node(location, xml)
        xml << XmlNode.new('xsd:city', location.city)
        xml << XmlNode.new('xsd:countryCode', location.country_code)
        xml << XmlNode.new('xsd:postalCode', location.postal_code)
        xml << XmlNode.new('xsd:residentialIndicator', location.residential_indicator)
        xml << XmlNode.new('xsd:state', location.state)
        xml.to_s
      end


      def build_tracking_request(tracking_numbers, options={}, xml_request)
        xml_request << XmlNode.new('ser:trackUPSShipment') do |root_node|
          root_node << XmlNode.new('ser:trackShipmentRequest') do |request|
            request << XmlNode.new('xsd1:shipmentNumbers') do |numbers|
              tracking_numbers.each do |number|
                numbers << XmlNode.new('xsd:shipmentNumber', number)
              end
            end

          end
        end

      end


      def add_insured_node(*args)
        params, package_node = args.extract_options!, args[0]
        currency, value = params[:currency], params[:value].to_i
        package_node << XmlNode.new("PackageServiceOptions") do |package_service_options|
          package_service_options << XmlNode.new("DeclaredValue") do |declared_value|
            declared_value << XmlNode.new("CurrencyCode", currency)
            declared_value << XmlNode.new("MonetaryValue", (value.to_i))
          end
          package_service_options << XmlNode.new("InsuredValue") do |declared_value|
            declared_value << XmlNode.new("CurrencyCode", currency)
            declared_value << XmlNode.new("MonetaryValue", (value.to_i))
          end
        end
      end

      def parse_rate_response(origin, destination, packages, response, options={})

        opt={}
        rates = []

        xml = REXML::Document.new(response)


        success = response_success?(xml)
        message = response_message(xml)

        if success
          rate_estimates = []
          xml.elements['//upsServiceDetails'].each do |rated_shipment|
            rated_shipment.elements['//feeItems'].each do |item|
              opt[item.elements['feeDesc'].text]= item.elements['feeAmount'].text
            end
            service_code = rated_shipment.elements['serviceCode'].text
            days_to_delivery = rated_shipment.elements['estimateDelivery'].text
            days_to_delivery = nil if days_to_delivery == 0
            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                               :service_name => rated_shipment.elements['serviceDescription'].text,
                                               :total_price => rated_shipment.elements['serviceFeeDetail/serviceFeeGrandTotal'].text,
                                               :service_code => service_code,
                                               :packages => packages,
                                               :rate_estimate_id => rated_shipment.elements['rateEstimateId'].text,
                                               :pickup_by => rated_shipment.elements['pickupBy'].text,
                                               :delivery_range => days_to_delivery,
                                               :package_number => rated_shipment.elements['serviceFeeDetail/packageLevelFees/packageLevelFee/packageNumber'].text,
                                               :fee_item => opt)


          end
        end

        RateResponse.new(success, message, Hash.from_xml(response).values.first, :rates => rate_estimates, :xml => response, :request => last_request)
      end


      def parse_void_response(response)
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)
        response = {}
        if success

          xml.elements['//shipmentVoidDetails'].each do |void_result|
            void_description = void_result.elements['voidDescription'].text
            shipment_number = void_result.elements['shipmentNumber'].text
            response[shipment_number] = void_description
          end
          return response
        else
          return message

        end
      end

      def parse_book_response(response, options)
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)
        labels = []

        if success
          xml.elements['//shipmentLabels'].each do |label|
            labels << {
                :air_bill_number => label.elements['airBillNumber'].text,
                :image_format => label.elements['imageFormat'].text,
                :package_number => label.elements['packageNumber'].text,
                :shipmentLabelContent => label.elements['shipmentLabelContent'].text,
            }
          end

          return labels
        else
          return message
        end

      end


      def parse_tracking_response(response, options={})


        #
        #xml = REXML::Document.new(response)
        #success = response_success?(xml)
        #message = response_message(xml)
        #
        #if success
        #  tracking_number, origin, destination, status_code, status_description, delivery_signature = nil
        #  delivered, exception = false
        #  exception_event = nil
        #  shipment_events = []
        #  status = {}
        #  scheduled_delivery_date = nil
        #
        #  first_shipment = xml.elements['/*/Shipment']
        #  first_package = first_shipment.elements['Package']
        #  tracking_number = first_shipment.get_text('ShipmentIdentificationNumber | Package/TrackingNumber').to_s
        #
        #  # Build status hash
        #  status_node = first_package.elements['Activity/Status/StatusType']
        #  status_code = status_node.get_text('Code').to_s
        #  status_description = status_node.get_text('Description').to_s
        #  status = TRACKING_STATUS_CODES[status_code]
        #
        #  if status_description =~ /out.*delivery/i
        #    status = :out_for_delivery
        #  end
        #
        #  origin, destination = %w{Shipper ShipTo}.map do |location|
        #    location_from_address_node(first_shipment.elements["#{location}/Address"])
        #  end
        #
        #  # Get scheduled delivery date
        #  unless status == :delivered
        #    scheduled_delivery_date = parse_ups_datetime({
        #                                                     :date => first_shipment.get_text('ScheduledDeliveryDate'),
        #                                                     :time => nil
        #                                                 })
        #  end
        #
        #  activities = first_package.get_elements('Activity')
        #  unless activities.empty?
        #    shipment_events = activities.map do |activity|
        #      description = activity.get_text('Status/StatusType/Description').to_s
        #      zoneless_time = if (time = activity.get_text('Time')) &&
        #          (date = activity.get_text('Date'))
        #                        time, date = time.to_s, date.to_s
        #                        hour, minute, second = time.scan(/\d{2}/)
        #                        year, month, day = date[0..3], date[4..5], date[6..7]
        #                        Time.utc(year, month, day, hour, minute, second)
        #                      end
        #      location = location_from_address_node(activity.elements['ActivityLocation/Address'])
        #      ShipmentEvent.new(description, zoneless_time, location)
        #    end
        #
        #    shipment_events = shipment_events.sort_by(&:time)
        #
        #    # UPS will sometimes archive a shipment, stripping all shipment activity except for the delivery
        #    # event (see test/fixtures/xml/delivered_shipment_without_events_tracking_response.xml for an example).
        #    # This adds an origin event to the shipment activity in such cases.
        #    if origin && !(shipment_events.count == 1 && status == :delivered)
        #      first_event = shipment_events[0]
        #      same_country = origin.country_code(:alpha2) == first_event.location.country_code(:alpha2)
        #      same_or_blank_city = first_event.location.city.blank? or first_event.location.city == origin.city
        #      origin_event = ShipmentEvent.new(first_event.name, first_event.time, origin)
        #      if same_country and same_or_blank_city
        #        shipment_events[0] = origin_event
        #      else
        #        shipment_events.unshift(origin_event)
        #      end
        #    end
        #
        #    # Has the shipment been delivered?
        #    if status == :delivered
        #      delivery_signature = activities.first.get_text('ActivityLocation/SignedForByName').to_s
        #      if !destination
        #        destination = shipment_events[-1].location
        #      end
        #      shipment_events[-1] = ShipmentEvent.new(shipment_events.last.name, shipment_events.last.time, destination)
        #    end
        #  end
        #
        #end
        #TrackingResponse.new(success, message, Hash.from_xml(response).values.first,
        #                     :carrier => @@name,
        #                     :xml => response,
        #                     :request => last_request,
        #                     :status => status,
        #                     :status_code => status_code,
        #                     :status_description => status_description,
        #                     :delivery_signature => delivery_signature,
        #                     :scheduled_delivery_date => scheduled_delivery_date,
        #                     :shipment_events => shipment_events,
        #                     :delivered => delivered,
        #                     :exception => exception,
        #                     :exception_event => exception_event,
        #                     :origin => origin,
        #                     :destination => destination,
        #                     :tracking_number => tracking_number)
      end

      def location_from_address_node(address)
        return nil unless address
        Location.new(
            :country => node_text_or_nil(address.elements['CountryCode']),
            :postal_code => node_text_or_nil(address.elements['PostalCode']),
            :province => node_text_or_nil(address.elements['StateProvinceCode']),
            :city => node_text_or_nil(address.elements['City']),
            :address1 => node_text_or_nil(address.elements['AddressLine1']),
            :address2 => node_text_or_nil(address.elements['AddressLine2']),
            :address3 => node_text_or_nil(address.elements['AddressLine3'])
        )
      end

      #def parse_ups_datetime(options = {})
      #  time, date = options[:time].to_s, options[:date].to_s
      #  if time.nil?
      #    hour, minute, second = 0
      #  else
      #    hour, minute, second = time.scan(/\d{2}/)
      #  end
      #  year, month, day = date[0..3], date[4..5], date[6..7]
      #
      #  Time.utc(year, month, day, hour, minute, second)
      #end

      def response_success?(xml)
        xml.elements['//ns2:responseStatusCode'].text.to_i == 0
      end

      def response_message(xml)
        if xml.elements['//ns2:responseStatusCode'].text.to_i == 0
          return xml.elements['//ns2:responseStatusDescription'].text
        else
          return xml.elements['//errorDescription'].text
        end
      end

      def commit(action, request, options={})
        ssl_post(LIVE_URL, request.to_s, options)
      end


      def service_name_for(origin, code)
        origin = origin.country_code(:alpha2)

        name = case origin
                 when "CA" then
                   CANADA_ORIGIN_SERVICES[code]
                 when "MX" then
                   MEXICO_ORIGIN_SERVICES[code]
                 when *EU_COUNTRY_CODES then
                   EU_ORIGIN_SERVICES[code]
               end

        name ||= OTHER_NON_US_ORIGIN_SERVICES[code] unless name == 'US'
        name ||= DEFAULT_SERVICES[code]
      end

    end
  end
end

