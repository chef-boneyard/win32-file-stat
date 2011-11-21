Gem::Specification.new do |spec|
  spec.name      = 'win32-file-stat'
  spec.version   = '1.3.5'
  spec.authors   = ['Daniel J. Berger', 'Park Heesob']
  spec.license   = 'Artistic 2.0'
  spec.email     = 'djberg96@gmail.com'
  spec.homepage  = 'http://www.rubyforge.org/projects/win32utils'
  spec.summary   = 'A File::Stat class tailored to MS Windows'
  spec.test_file = 'test/test_file_stat.rb'
  spec.files     = Dir['**/*'].reject{ |f| f.include?('git') }

  spec.rubyforge_project = 'Win32Utils'
  spec.extra_rdoc_files  = ['README', 'CHANGES', 'MANIFEST']

  spec.add_dependency('windows-pr', '>= 1.0.0')
  spec.add_development_dependency('test-unit')

  spec.description = <<-EOF
    The win32-file-stat library provides a custom File::Stat class
    specifically tailored for MS Windows. Examples include the ability
    to retrieve file attributes (hidden, archive, etc) as well as the
    redefinition of certain core methods that either aren't implemented
    at all, such as File.blksize, or methods that aren't implemented
    properly, such as File.size.
  EOF
end
