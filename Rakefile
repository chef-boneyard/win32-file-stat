require 'rake'
require 'rake/clean'
require 'rake/testtask'

CLEAN.include("**/*.gem", "**/*.rbx", "**/*.rbc", "**/*.log", "**/*.exe", "**/*.txt")

namespace :gem do
  desc "Create the win32-file-stat gem"
  task :create => [:clean] do
    require 'rubygems/package'
    spec = eval(IO.read("win32-file-stat.gemspec"))
    spec.signing_key = File.join(Dir.home, '.ssh', 'gem-private_key.pem')
    Gem::Package.build(spec, true)
  end

  desc "Install the win32-file-stat gem"
  task :install => [:create] do
    file = Dir["win32-file-stat*.gem"].first
    sh "gem install -l #{file}"
  end
end

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
end

task :default => :test
