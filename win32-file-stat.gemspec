Gem::Specification.new do |spec|
  spec.name      = 'win32-file-stat'
  spec.version   = '1.4.2'
  spec.authors   = ['Daniel J. Berger', 'Park Heesob']
  spec.license   = 'Artistic 2.0'
  spec.email     = 'djberg96@gmail.com'
  spec.homepage  = 'http://www.github.com/djberg96/win32-file-stat'
  spec.summary   = 'A File::Stat class tailored to MS Windows'
  spec.test_file = 'test/test_file_stat.rb'
  spec.files     = Dir['**/*'].reject{ |f| f.include?('git') }

  spec.rubyforge_project = 'Win32Utils'
  spec.extra_rdoc_files = ['README', 'CHANGES', 'MANIFEST']
  spec.required_ruby_version = ">= 1.9.0"

  spec.add_dependency('ffi')
  spec.add_development_dependency('test-unit')
  spec.add_development_dependency('win32-security')
  spec.add_development_dependency('rake')

  spec.description = <<-EOF
    The win32-file-stat library provides a custom File::Stat class
    specifically tailored for MS Windows. Examples include the ability
    to retrieve file attributes (hidden, archive, etc) as well as the
    redefinition of certain core methods that aren't implemented at all,
    such as File.blksize.
  EOF
end
