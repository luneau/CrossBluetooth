Pod::Spec.new do |s|
  s.name         = 'CrossBluetooth'
  s.version      = '1.0'
  s.summary      = 'CrossBluetooth (or xBluetooth) is Bluetooth API in swift with reactive pattern using Combine'

  s.description                = <<-DESC
                                   CrossBluetooth (or xBluetooth) is Bluetooth API in swift with reactive pattern using Combine
                                 DESC

  s.homepage                   = 'https://github.com/luneau/CrossBluetooth'
  s.license                    = 'MIT License'
  s.author                     = { "Sébastien Luneau"}
  s.requires_arc               = true
  s.ios.deployment_target      = '13'
  s.watchos.deployment_target  = '6.0'
  s.macos.deployment_target    = '10.15'
  s.tvos.deployment_target     = '13'

  s.swift_version = '5.0'

  s.source                     = { :git => 'https://github.com/luneau/CrossBluetooth.git', :tag => s.version }
  
  s.source_files               = 'Sources/CrossBluetooth/*.swift',
                                 'Sources/CrossBluetooth/BluetoothCombine/*.swift',
                                 'Sources/CrossBluetooth/CoreBluetooth/*.swift',
                                 'Sources/CrossBluetooth/CoreBluetooth/DelegateWrappers/*.swift',
  s.frameworks                 = 'Combine','CoreBluetooth'
  
end
