require 'rake'
require 'rake/clean'
require 'rake/testtask'

CLEAN.include("**/*.gem", "**/*.rbx", "**/*.rbc")

namespace :gem do
  desc "Create the win32-file-stat gem"
  task :create => [:clean] do
    spec = eval(IO.read("win32-file-stat.gemspec"))
    Gem::Builder.new(spec).build
  end

  desc "Install the win32-file-stat gem"
  task :install => [:create] do
    file = Dir["win32-file-stat*.gem"].first
    sh "gem install #{file}"
  end
end

Rake::TestTask.new do |t|
  t.verbose = true
  t.warning = true
end

task :default => :test
