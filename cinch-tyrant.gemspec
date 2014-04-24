Gem::Specification.new do |gem|
  gem.name        = 'cinch-tyrant'
  gem.version     = '0.0.1'
  gem.author      = 'l'
  gem.date        = '2014-04-25'
  gem.summary     = 'Cinch Tyrant'
  gem.description = 'Allows your Cinch bot to provide information on War Metal Tyrant'
  gem.license     = 'Apache'
  gem.files       = Dir.glob('lib/**/*.rb') + Dir.glob('ext/**/*.{c,h,rb}')
  gem.extensions  = ['ext/tyrant/extconf.rb']
end
