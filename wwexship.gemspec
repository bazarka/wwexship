Gem::Specification.new do |s|
  s.name = "wwexship"
  s.version = "0.0.2"
  s.author = "Marcin Jabłoński, Jaroslaw Wozniak"
  s.homepage = "https://github.com/bazarka/wwexship"
  s.summary = "Extension for Active Shipping"
  s.description = "Implements SpeedFreight and SpeedShip carriers"
  s.files = ["lib/wwexship/active_shipping/shipping/carriers/speed_freight.rb",
             "lib/wwexship/active_shipping/shipping/carriers/speed_ship.rb",
             "lib/wwexship.rb", "lib/wwexship/active_shipping/shipping/location.rb"]
  s.require_path = 'lib'
  s.license = "MIT"
  s.email = 'info@bazarka.com'

  s.add_runtime_dependency 'active_shipping'

  s.add_development_dependency('minitest', '~> 4.7.5')
  s.add_development_dependency('rake')
  s.add_development_dependency('mocha', '~> 0.14.0')
  s.add_development_dependency('timecop')
  s.add_development_dependency('nokogiri')
end
