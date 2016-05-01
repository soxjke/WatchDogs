Pod::Spec.new do |s|
  s.name             = "WatchDogs"
  s.version          = "0.1.0"
  s.summary          = "Run-time helpers to avoid API misusages"

  s.description      = <<-DESC
CoreData threading issues, long-running operations on a main-thread,
all the different kinds of monitoring might be needed to warn about issues
appearing while app debugging.
                       DESC

  s.homepage         = "https://github.com/soxjke/WatchDogs"
  s.license          = 'MIT'
  s.author           = { "Petro Korienev" => "soxjke@gmail.com" }
  s.source           = { :git => "https://github.com/soxjke/WatchDogs.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/soxjke'

  s.ios.deployment_target = '7.0'

  s.source_files = 'WatchDogs/Classes/**/*'
end
