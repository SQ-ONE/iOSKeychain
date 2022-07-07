Pod::Spec.new do |s|
    s.name         = "Keychain"
    s.version      = "1.0.0"
    s.summary      = "iOS Keychain implementation using Objective-C"
    s.description  = <<-DESC
    An extended description of MyFramework project.
    DESC
    s.homepage     = "https://github.com/SQ-ONE/iOSKeychain"
    s.author             = { "ShashankSurvase" => "shashank.survase@squareoneinsights.com" }
    s.source       = { :git => "https://github.com/SQ-ONE/iOSKeychain.git", :tag => "#{s.version}" }
    s.vendored_frameworks = "Keychain.xcframework"
    s.platform = :ios
    s.ios.deployment_target  = '15.5'
end
