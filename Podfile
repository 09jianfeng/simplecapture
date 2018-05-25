#inhibit_all_warnings!
platform :ios, '8.0'

#xcodeproj 'SimpleCapture'

source 'https://github.com/CocoaPods/Specs.git'

target 'SimpleCapture' do
pod 'CocoaLumberjack', '3.1.0'
pod 'Masonry', '1.0.2'
pod 'GCDWebServer/WebDAV', '~> 3.0'
pod 'KVOController'
pod 'NSLogger'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['ONLY_ACTIVE_ARCH'] = "NO"
        end
    end
end
