require 'rake'
require 'rake/testtask'
require 'rbconfig'
include Config

desc 'Install the win32-file-stat library (non-gem)'
task :install do
   install_dir = File.join(CONFIG['sitelibdir'], 'win32', 'file')
   file = 'lib\win32\file\stat.rb'
   FileUtils.mkdir_p(install_dir)
   FileUtils.cp(file, install_dir, :verbose => true)
end

desc 'Install the win32-file-stat library as a gem'
task :install_gem do
   ruby 'win32-file-stat.gemspec'
   file = Dir["win32-file-stat*.gem"].first
   sh "gem install #{file}"
end

Rake::TestTask.new do |t|
   t.verbose = true
   t.warning = true
end