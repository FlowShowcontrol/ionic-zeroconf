
  Pod::Spec.new do |s|
    s.name = 'IonicZeroconf'
    s.version = '0.0.1'
    s.summary = 'Bonjour discovery for capacitor applications'
    s.license = 'MIT'
    s.homepage = 'http://www.github.com/FlowShowcontrol'
    s.author = 'Flow Showcontrol'
    s.source = { :git => '', :tag => s.version.to_s }
    s.source_files = 'ios/Plugin/Plugin/**/*.{swift,h,m,c,cc,mm,cpp}'
    s.ios.deployment_target  = '10.0'
    s.dependency 'Capacitor'
  end