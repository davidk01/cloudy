require "bundler/gem_tasks"
require "rake/testtask"

# Turns out if TEST variable is set then `rake test`
# will pick it up and fail if you have already set that
# variable to somthing expected by another toolset. So
# I unset it here to avoid that problem.
ENV.delete('TEST')

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test
