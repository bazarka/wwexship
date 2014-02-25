# -*- encoding: utf-8 -*-
module ActiveMerchant
  module Shipping
    class SpeedFreight < Carrier
      self.retry_safe = true

      cattr_accessor :default_options
      cattr_reader :name
      @@name = "SpeedFreight"

      TEST_URL = "http://www.wwexship.com/webServices/services/SpeedFreightShipment"
      LIVE_URL = "http://www.wwexship.com/webServices/services/SpeedFreightShipment"

      RESOURCES = {
          :rates => 'ups.app/xml/Rate',
          :track => 'ups.app/xml/Track'
      }


      LIMITED_ACCESS_TYPE = {
          "School" => "01",
          "Church" => "02",
          "Military Base/Installation" => "03",
          "Prison/Jail/Correctional Facility" => "04"
      }

      INSURANCE_CATEGORY = {
          "1" => "New General Merchandise",
          "2" => "Used General Merchandise",
          "3" => "Fragile goods",
          "4" => "Non-Perishable Foods/Beverages/Commodities",
          "5" => "Perishable/Temperature Controlled/Foods/Beverages/Commodities (Full Conditions)",
          "6" => "Laptops/Cellphones/PDAs/iPads/Tablets/Notebooks and Gaming systems",
          "7" => "Wine",
          "8" => "Radioactive/Hazardous/Restricted or Controlled Items"

      }

      # From http://en.wikipedia.org/w/index.php?title=European_Union&oldid=174718707 (Current as of November 30, 2007)
      EU_COUNTRY_CODES = ["GB", "AT", "BE", "BG", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"]

      US_TERRITORIES_TREATED_AS_COUNTRIES = ["AS", "FM", "GU", "MH", "MP", "PW", "PR", "VI"]

      HANDLING_UNIT_TYPE = ["Pallet", "Skid", "Bag", "Bale", "Box", "Bundle", "Carton", "Crate", "Cylinder", "Drum", "Gaylord", "Loose", "Pails", "Roll", "Other"]
      LINE_ITEM_CLASS = ["50", "55", "60", "65", "70", "77.5", "85", "92.5", "100", "125", "150", "200", "300", "400", "500"]

      def requirements
        [:loginId, :password, :licenseKey, :accountNumber]
      end

      # require 'active_shipping'
      # destination = ActiveMerchant::Shipping::Location.new(country: 'US', state: 'ON', city: 'Ottawa', zip: '90210' )
      # origin = ActiveMerchant::Shipping::Location.new(country: 'US', state: 'CA', city: 'Beverly Hills', zip: '90210' )
      # w = {'line1' => {'class_type' => 'class_t1', 'weight' => '4', 'description' => 'desc', 'NMFC_number' => '3', 'piece_type' => 'types', 'number_pieces'=>'4'}, 'line2' =>  {'class_type' => 'class_t1', 'weight' => '4', 'description' => 'desc', 'NMFC_number' => '3', 'piece_type' => 'types', 'number_pieces'=>'4'}}
      # package1 = ActiveMerchant::Shipping::Package.new(100, [93,10], cylinder: true)
      # package1.options['lines'] = w
      # packages = []
      # packages << package1
      # w = ActiveMerchant::Shipping::Ltl.new(loginId: '2324435', password: 'dufekl', licenseKey: 'eojewgjwewg', accountNumber: '345')
      # w.find_rates(origin, destination, packages, {dupa: 'dupa'})

      def void_shipment(bol_numbers)
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:wwex" => "http://www.wwexship.com"}) do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        create_body_void_request(bol_numbers, body)
        response = commit(:rates, save_request(main.to_s))
        parse_void_response(response)
      end

      def pro_number(bol_numbers)
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:wwex" => "http://www.wwexship.com"}) do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        create_body_pro_number_request(bol_numbers, body)
        response= commit(:rates, save_request(main.to_s))
        parse_pro_number_response(response)
      end

      def book_shipment(origin, destination, rates_response, options, packages)
        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:wwex" => "http://www.wwexship.com"}) do |main_env|
          main_env << header
          main_env << body
        end
        build_access_request(header)
        create_body_book_request(origin, destination, rates_response, body, options)
        response = commit(:rates, save_request(main.to_s), (options[:test] || false))
        parse_book_response(response)
      end

      def find_rates(origin, destination, packages, options={})

        header = XmlNode.new('soapenv:Header')
        body = XmlNode.new('soapenv:Body')
        main = XmlNode.new('soapenv:Envelope', {"xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:wwex" => "http://www.wwexship.com"}) do |main_env|
          main_env << header
          main_env << body
        end
        #origin, destination = upsified_location(origin), upsified_location(destination)
        options = @options.merge(options)
        packages = Array(packages)
        create_body_request(origin, destination, packages, options, body)
        build_access_request(header)
        response = commit(:rates, save_request(main.to_s), (options[:test] || false))
        parse_rate_response(origin, destination, packages, response, options)
      end

      protected

      def create_body_pro_number_request(bol_numbers, xml_request)
        xml_request << XmlNode.new('wwex:getSpeedFreightShipmentProNumber') do |shipment_pro_number|
          shipment_pro_number << XmlNode.new('wwex:freightShipmentProNumberRequest') do |freight_shipment|
            freight_shipment << XmlNode.new('wwex:shipmentBOLNumbers') do |shipment_bol_nr|
              bol_numbers.each do |bol_number|
                shipment_bol_nr << XmlNode.new('wwex:freightShipmentBOLNumber', bol_number)
              end
            end
          end
        end
        xml_request.to_s
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

      def create_body_void_request(numbers, xml_request)
        xml_request << XmlNode.new('wwex:voidSpeedFreightShipment') do |freight_shipment|
          freight_shipment << XmlNode.new('wwex:freightShipmentVoidRequest') do |void_request|
            void_request << XmlNode.new('wwex:shipmentBOLNumbers') do |bol_number|
              numbers.each do |number|
                bol_number << XmlNode.new('wwex:freightShipmentBOLNumber', number)
              end
            end
          end
        end
        xml_request.to_s
      end

      def create_body_book_request(origin, destination, rates, xml_request, options)
        xml_request << XmlNode.new('wwex:bookSpeedFreightShipment') do |book_shipment|
          book_shipment << XmlNode.new('wwex:freightShipmentBookRequest') do |freight_shipment|
            freight_shipment << XmlNode.new('wwex:shipmentQuoteId', rates.service_name[:shipment_quote_id])
            freight_shipment << XmlNode.new('wwex:freightShipmentSenderDetail') do |sender_detail|
              build_sender_address(origin, sender_detail)
            end
            freight_shipment << XmlNode.new('wwex:freightShipmentReceiverDetail') do |destination_detail|
              build_destination_address(destination, destination_detail)
            end
            freight_shipment << XmlNode.new('wwex:shipmentDate', options[:shipment_date])
            freight_shipment << XmlNode.new('wwex:shipmentReadyTime', options[:shipment_ready_time])
            freight_shipment << XmlNode.new('wwex:shipmentClosingTime', options[:shipment_closing_time])
            freight_shipment << XmlNode.new('wwex:freightShipmentCODInfo') do |cod_info|
              build_code_info(cod_info, options)
            end
            freight_shipment << XmlNode.new('wwex:freightShipmentInsuranceDescription') do |insurance_description|
              insurance_description << XmlNode.new('wwex:insuranceDescriptionOfCargo', options[:insurance_description_of_cargo])
              insurance_description << XmlNode.new('wwex:insuranceMarksNumbers', options[:insurance_marks_number])
            end
            freight_shipment << XmlNode.new('wwex:shipmentReferences') do |shipment_references|
              if options[:references].present?
                options[:references].each do |k, v|
                  shipment_references << XmlNode.new('wwex:freightShipmentReference') do |freight_shipment_reference|
                    freight_shipment_reference << XmlNode.new('wwex:referenceDescription', v[:reference_description])
                    freight_shipment_reference << XmlNode.new('wwex:referenceType', v[:reference_type])
                    freight_shipment_reference << XmlNode.new('wwex:referencePackageNumber', v[:reference_package_number])
                  end
                end
              end
              freight_shipment << XmlNode.new('wwex:specialInstruction')
              freight_shipment << XmlNode.new('wwex:freightShipmentAddressLabel') do |shipment_address_label|
                shipment_address_label << XmlNode.new('wwex:printShipmentAddessLabel', options[:print_shipment_address_label])
                shipment_address_label << XmlNode.new('wwex:numberOfShipmentAddressLabel', options[:number_of_shipment_address_label])
              end
            end
          end
        end
        xml_request.to_s
      end


      def build_code_info(xml_request, options)
        xml_request << XmlNode.new('wwex:companyName', options[:code_company_name])
        xml_request << XmlNode.new('wwex:streetAddress', options[:code_street_address])
        xml_request << XmlNode.new('wwex:city', options[:code_city])
        xml_request << XmlNode.new('wwex:state', options[:code_state])
        xml_request << XmlNode.new('wwex:zip', options[:code_zip])
        xml_request << XmlNode.new('wwex:country', options[:code_country])
        xml_request << XmlNode.new('wwex:formOfPayment', options[:code_form_of_payment])
        xml_request.to_s
      end

      def build_destination_address(destination, destination_detail)
        destination_detail << XmlNode.new('wwex:receiverCompanyName', destination.company_name)
        destination_detail << XmlNode.new('wwex:receiverAddressLine1', destination.address1)
        destination_detail << XmlNode.new('wwex:receiverAddressLine2', destination.address2)
        destination_detail << XmlNode.new('wwex:receiverCity', destination.city)
        destination_detail << XmlNode.new('wwex:receiverState', destination.state)
        destination_detail << XmlNode.new('wwex:receiverZip', destination.zip)
        if destination.country_code.to_s == 'US'
          destination_detail << XmlNode.new('wwex:receiverCountryCode', 'USA')
        else
          destination_detail << XmlNode.new('wwex:receiverCountryCode', destination.country_code)
        end
        destination_detail << XmlNode.new('wwex:receiverPhone', destination.phone)
        destination_detail << XmlNode.new('wwex:receiverContact')
        destination_detail << XmlNode.new('wwex:emailBOLToReceiver')
        destination_detail << XmlNode.new('wwex:receiverEmailAddess', destination.email)
        destination_detail << XmlNode.new('wwex:billToReceiver')
        destination_detail << XmlNode.new('wwex:receiverAccountNumber')
        destination_detail.to_s
      end


      def build_sender_address(origin, sender_detail)
        sender_detail << XmlNode.new('wwex:senderCompanyName', origin.company_name)
        sender_detail << XmlNode.new('wwex:senderAddressLine1', origin.address1)
        sender_detail << XmlNode.new('wwex:senderAddressLine2', origin.address2)
        sender_detail << XmlNode.new('wwex:senderCity', origin.city)
        sender_detail << XmlNode.new('wwex:senderState', origin.state)
        sender_detail << XmlNode.new('wwex:senderZip', origin.zip)
        if origin.country_code.to_s == 'US'
          sender_detail << XmlNode.new('wwex:senderCountryCode', 'USA')
        else
          sender_detail << XmlNode.new('wwex:senderCountryCode', origin.country_code)
        end
        sender_detail << XmlNode.new('wwex:senderPhone', origin.phone)
        sender_detail << XmlNode.new('wwex:senderContact', origin.email)
        sender_detail << XmlNode.new('wwex:emailBOLToSender')
        sender_detail << XmlNode.new('wwex:senderEmailAddess', origin.email)
        sender_detail.to_s
      end


      def create_body_request(origin, destination, packages, options, xml_request)
        xml_request << XmlNode.new('wwex:quoteSpeedFreightShipment') do |speed_freight|
          speed_freight << XmlNode.new('wwex:freightShipmentQuoteRequest') do |quote_request|
            build_rate_request(origin, destination, packages, options, quote_request)
            build_insurance_request(options, quote_request)
            build_commodity_request(origin, packages, quote_request)
          end
        end
        xml_request.to_s
      end

      def build_access_request(xml_request)
        xml_request << XmlNode.new('wwex:AuthenticationToken') do |token|
          token << XmlNode.new('wwex:loginId', @options[:loginId])
          token << XmlNode.new('wwex:password', @options[:password])
          token << XmlNode.new('wwex:licenseKey', @options[:licenseKey])
          token << XmlNode.new('wwex:accountNumber', @options[:accountNumber])
          xml_request.to_s
        end
      end

      def build_rate_request(origin, destination, packages, options={}, xml_request)
        xml_request << XmlNode.new('wwex:senderCity', origin.city)
        xml_request << XmlNode.new('wwex:senderState', origin.state)
        xml_request << XmlNode.new('wwex:senderZip', origin.zip)
        xml_request << XmlNode.new('wwex:senderCountryCode', origin.country)
        xml_request << XmlNode.new('wwex:receiverCity', destination.city)
        xml_request << XmlNode.new('wwex:receiverState', destination.state)
        xml_request << XmlNode.new('wwex:receiverZip', destination.zip)
        xml_request << XmlNode.new('wwex:receiverCountryCode', destination.country)
        #optionals
        xml_request << XmlNode.new('wwex:insidePickup', options[:inside_pickup])
        xml_request << XmlNode.new('wwex:insideDelivery', options[:inside_delivery])
        xml_request << XmlNode.new('wwex:liftgatePickup', options[:lift_gate_pickup])
        xml_request << XmlNode.new('wwex:liftgateDelivery', options[:lift_gate_delivery])
        xml_request << XmlNode.new('wwex:residentialPickup', options[:residential_pickup])
        xml_request << XmlNode.new('wwex:residentialDelivery', options[:residential_delivery])
        xml_request << XmlNode.new('wwex:tradeshowPickup', options[:trade_show_pickup])
        xml_request << XmlNode.new('wwex:tradeshowDelivery', options[:trade_show_delivery])
        xml_request << XmlNode.new('wwex:constructionSitePickup', options[:construction_site_pickup])
        xml_request << XmlNode.new('wwex:constructionSiteDelivery', options[:construction_site_delivery])
        xml_request << XmlNode.new('wwex:notifyBeforeDelivery', options[:notify_before_delivery])
        xml_request << XmlNode.new('wwex:limitedAccessPickup', options[:limited_access_pickup])
        # if limitedAccessPickup is true then limitedAccessPickupType required
        xml_request << XmlNode.new('wwex:limitedAccessPickupType', LIMITED_ACCESS_TYPE[options[:pickup_type]])
        xml_request << XmlNode.new('wwex:limitedAccessDelivery', options[:limited_access_delivery])
        # if limitedAccessDelivery is true then limitedAccessDeliveryType required
        xml_request << XmlNode.new('wwex:limitedAccessDeliveryType', LIMITED_ACCESS_TYPE[options[:delivery_type]])
        xml_request << XmlNode.new('wwex:collectOnDelivery', options[:COD_service])
        xml_request << XmlNode.new('wwex:collectOnDeliveryAmount', options[:CPD_service_amount])
        xml_request << XmlNode.new('wwex:CODIncludingFreightCharge', options[:included_freight_charges])
        xml_request << XmlNode.new('wwex:shipmentDate', options[:date_of_shipment_pickup])
        xml_request.to_s
      end

      # if InsuranceDetail is used then commdityDetails must be used
      def build_insurance_request(options={}, xml_request)
        xml_request << XmlNode.new('wwex:insuranceDetail') do |insurance|
          insurance << XmlNode.new('wwex:insuranceCategory', INSURANCE_CATEGORY[options[:insurance_category_type]])
          insurance << XmlNode.new('wwex:insuredCommodityValue', options[:insurance_commodity_value])
          insurance << XmlNode.new('wwex:insuranceIncludingFreightCharge', options[:included_the_freight_charges])
        end
        xml_request.to_s
      end

      def build_commodity_request(origin, packages, xml_request)
        imperial = ['US', 'LR', 'MM'].include?(origin.country)
        xml_request << XmlNode.new('wwex:commdityDetails') do |commodity|
          # do przemyślenia (czy sami oblicamy czy jest podane)
          commodity << XmlNode.new('wwex:is11FeetShipment', false)
          commodity << XmlNode.new('wwex:handlingUnitDetails') do |details|
            packages.each do |package|

              details << XmlNode.new('wwex:wsHandlingUnit') do |package_handling|
                package_handling << XmlNode.new('wwex:typeOfHandlingUnit', package.options[:units])
                package_handling << XmlNode.new('wwex:numberOfHandlingUnit', package.options[:number])

                if imperial
                  package_handling << XmlNode.new('wwex:handlingUnitHeight', package.inches[2])
                  package_handling << XmlNode.new('wwex:handlingUnitLength', package.inches[0])
                  package_handling << XmlNode.new('wwex:handlingUnitWidth', package.inches[1])
                else
                  package_handling << XmlNode.new('wwex:handlingUnitHeight', package.cm[2])
                  package_handling << XmlNode.new('wwex:handlingUnitLength', package.cm[0])
                  package_handling << XmlNode.new('wwex:handlingUnitWidth', package.cm[1])
                end
                package_handling << XmlNode.new('wwex:lineItemDetails') do |line_item_details|
                  if package.options[:lines].present?
                    package.options[:lines].each do |k, line|
                      line_item_details << XmlNode.new('wwex:wsLineItem') do |ws_line_item|
                        ws_line_item << XmlNode.new('wwex:lineItemClass', line[:class_type])
                        ws_line_item << XmlNode.new('wwex:lineItemWeight', line[:weight])
                        ws_line_item << XmlNode.new('wwex:lineItemDescription', line[:description])
                        ws_line_item << XmlNode.new('wwex:lineItemNMFC', line[:NMFC_number])
                        ws_line_item << XmlNode.new('wwex:lineItemPieceType', line[:piece_type])
                        ws_line_item << XmlNode.new('wwex:piecesOfLineItem', line[:number_pieces])
                        ws_line_item << XmlNode.new('wwex:isHazmatLineItem', line[:hazmat])

                        ws_line_item << XmlNode.new('wwex:lineItemHazmatInfo') do |line_item_hazmat|
                          line_item_hazmat << XmlNode.new('wwex:lineItemHazmatUNNumberHeader', line[:UN_number])
                          line_item_hazmat << XmlNode.new('wwex:lineItemHazmatUNNumber', line[:UN_number_valid])
                          line_item_hazmat << XmlNode.new('wwex:lineItemHazmatClass', line[:hazmat_class])
                          line_item_hazmat << XmlNode.new('wwex:lineItemHazmatEmContactPhone', line[:hazmat_phone])
                          line_item_hazmat << XmlNode.new('wwex:lineItemHazmatPackagingGroup', line[:hazmat_group])
                        end

                      end
                    end
                  end
                end
              end
            end
          end
        end
        xml_request.to_s
      end

      def parse_pro_number_response(response)

        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)

        response = {}
        if success
          xml.elements['//freightShipmentProNumberResults'].each do |f|
            bol_number = f.elements['bolNumber'].text
            pro_number = f.elements['proNumber'].text
            response[bol_number]= pro_number
          end
          return response
        else
          return message
        end

      end

      def parse_void_response(response)
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)
        response = {}
        if success
          xml.elements['//freightShipmentVoidResults'].each do |void_result|
            description = void_result.elements['description'].text
            bol_number = void_result.elements['bolNumber'].text
            response[bol_number] = description
          end
          return response
        else
          return message
        end

      end

      def parse_book_response(response)
        xml = REXML::Document.new(response)
        response = {}
        label = []
        success = response_success?(xml)
        message = response_message(xml)
        if success
          bol_number = xml.elements['//freightShipmentBOLNumber'].text
          response[:number] = bol_number
          image = xml.elements['//base64BOLLabel'].text
          response[:image] = image
          label << response
          return label
        else
          return message
        end

      end

      def parse_rate_response(origin, destination, packages, response, options={})
        rates = []
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)

        if success

          rate_estimates = []

          xml.elements['//freightShipmentQuoteResults'].each do |rated_shipment|
            service_code = rated_shipment.elements['shipmentQuoteId'].text
            days_to_delivery = rated_shipment.elements['transitDays'].text
            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                               :name => rated_shipment.elements['carrierName'].text,
                                               :total_price => rated_shipment.elements['totalPrice'].text,
                                               :shipment_quote_id => service_code,
                                               :carrier_scac => rated_shipment.elements['carrierSCAC'].text,
                                               :delivery_range => (days_to_delivery),
                                               :guaranteed_service => rated_shipment.elements['guaranteedService'].text,
                                               :high_cost_delivery_shipment => rated_shipment.elements['highCostDeliveryShipment'].text,
                                               :interline => rated_shipment.elements['interline'].text,
                                               :nmfcRequired => rated_shipment.elements['nmfcRequired'].text

            )
          end
        end
        response = RateResponse.new(success, message, Hash.from_xml(response).values.first, :rates => rate_estimates, :xml => response, :request => last_request)
        return response
      end

      def response_success?(xml)
        xml.elements['//responseStatusCode'].text.to_i == 1
      end

      def response_message(xml)
        if xml.elements['//responseStatusCode'].text.to_i == 1
          return xml.elements['//responseStatusDescription'].text
        else
          return xml.elements['//errorDescription'].text
        end
      end

      def commit(action, request, test = false)
        ssl_post(LIVE_URL, request.to_s, {"SOAPAction" => "", "Content-Type" => "text/xml"})
      end
    end
  end
end
