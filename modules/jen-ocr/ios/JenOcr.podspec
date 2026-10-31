Pod::Spec.new do |s|
  s.name = 'JenOcr'
  s.version = '1.0.0'
  s.summary = 'Local text recognition for jen'
  s.description = 'Recognizes local label and receipt images with Apple Vision.'
  s.license = { :type => 'MIT' }
  s.author = 'jen'
  s.homepage = 'https://expo.dev'
  s.platforms = { :ios => '16.4' }
  s.source = { :path => '.' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.{h,m,mm,swift}'
  s.frameworks = 'Vision', 'ImageIO'
end
