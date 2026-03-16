platform :osx, '14.0'
use_frameworks!

target 'Clipy' do

  # Application
  pod 'Sauce'
  pod 'Sparkle'
  pod 'RealmSwift'
  pod 'KeyHolder'
  pod 'Magnet'
  pod 'AEXML'
  pod 'SwiftHEXColors'
  # Utility
  pod 'BartyCrouch'
  pod 'SwiftLint'
  pod 'SwiftGen'

  target 'ClipyTests' do
    inherit! :search_paths

    pod 'Quick', '~> 7.0'
    pod 'Nimble', '~> 13.0'

  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
