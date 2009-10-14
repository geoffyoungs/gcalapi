require 'rake/gempackagetask'
require "rake/contrib/rubyforgepublisher"
require "rake/rdoctask"
require "rake/testtask"

require 'rbconfig'
include Config

PKG_NAME = 'gcalapi'
PKG_VERSION = File.read('VERSION').chomp
PKG_FILES = FileList["**/*"].exclude(".svn").exclude("pkg").exclude("test/temp_*.rb").exclude("test/parameters.rb").exclude("*.log").exclude("test/*.log")

Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/*_test.rb']
    t.verbose = true
end

desc "Removing generated files"
task :clean do
  rm_rf 'html'
  rm_rf 'pkg'
end

desc "Generate RDoc documentation"
Rake::RDocTask.new do |rdoc|
  rdoc.options << '--line-numbers'
  rdoc.options << '--inline-source'
  rdoc.options << '--all'
  rdoc.rdoc_files.include 'README'
  rdoc.rdoc_files.include 'lib/googlecalendar/*.rb'
end

spec = Gem::Specification.new do |s|
  #### Basic information.

  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = "Google Calendar API"
  s.description = ""

  #### Dependencies and requirements.

  s.files = PKG_FILES

  #### C code extensions.

  #s.extensions << "ext/extconf.rb"

  #### Load-time details: library and application (you will need one or both).

  s.require_path = 'lib'                         # Use these for libraries.
  s.autorequire = "googlecalendar/calendar"

  #### Documentation and testing.

  s.has_rdoc = true
  #s.extra_rdoc_files = rd.rdoc_files.reject { |fn| fn =~ /\.rb$/ }.to_a
  s.extra_rdoc_files = 'README'
  s.rdoc_options << '--line-numbers' << '--inline-source'
  #s.rdoc_options <<
  #  '--title' <<  'Rake -- Ruby Make' <<
  #  '--main' << 'README' <<
  #  '--line-numbers'
  s.test_files = Dir.glob('test/*_test.rb')

  #### Author and project details.

  s.author = "zorio"
  s.email = "zoriorz@gmail.com"
  s.homepage = "http://gcalapi.rubyforge.net"
  s.rubyforge_project = "gcalapi"
end

Rake::GemPackageTask.new(spec) do |pkg|
  #pkg.need_tar = true
  #pkg.need_zip = true
  #pkg.package_files += PKG_FILES
end

task :release => [ :clean, :rdoc, :package ]

desc "Publish to RubyForge"
task :rubyforge => [:rdoc, :package] do
  Rake::RubyForgePublisher.new(PKG_NAME, "zorio").upload
end
