require 'rubygems'

spec = Gem::Specification.new do |gem|
   gem.name      = 'win32-file-stat'
   gem.version   = '1.3.4'
   gem.authors   = ['Daniel J. Berger', 'Park Heesob']
   gem.license   = 'Artistic 2.0'
   gem.email     = 'djberg96@gmail.com'
   gem.homepage  = 'http://www.rubyforge.org/projects/win32utils'
   gem.platform  = Gem::Platform::RUBY
   gem.summary   = 'A File::Stat class tailored to MS Windows'
   gem.test_file = 'test/test_file_stat.rb'
   gem.has_rdoc  = true
   gem.files     = Dir['**/*'].reject{ |f| f.include?('CVS') }

   gem.rubyforge_project = 'Win32Utils'
   gem.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST']

   gem.add_dependency('windows-pr', '>= 1.0.0')
   gem.add_development_dependency('test-unit', '>= 2.0.2')

   gem.description = <<-EOF
      The win32-file-stat library provides a custom File::Stat class
      specifically tailored for MS Windows. Examples include the ability
      to retrieve file attributes (hidden, archive, etc) as well as the
      redefinition of certain core methods that either aren't implemented
      at all, such as File.blksize, or methods that aren't implemented
      properly, such as File.size.
   EOF
end

Gem::Builder.new(spec).build
