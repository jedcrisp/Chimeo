# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

# Enable dSYM generation for all frameworks
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
      config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
    end
  end
end

target 'Chimeo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Chimeo
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
  pod 'Firebase/Storage'
  pod 'Firebase/Functions'
  pod 'GoogleSignIn'

end

target 'LocalAlert' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for LocalAlert
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Messaging'
  pod 'Firebase/Storage'
  pod 'Firebase/Functions'
  pod 'GoogleSignIn'

end