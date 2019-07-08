# Cargofile

Experiment in building projects with multi-stage Dockerfiles

## Example

Create `Cargofile` and describe your build

```ruby
#!/usr/bin/env ruby

require "cargofile"

cargo :cargofile do |c|

  # Default commands for ALL stages
  c.build_arg :RUNTIME => "ruby2.5"
  c.tag       %x(git describe --tags --always).strip

  c.stage :build do |s|
    s.artifact "Gemfile.lock" # Default artifact extraction using `cat`

    s.artifact "pkg/vendor.zip" do |a| # Custom artifact extraction
      a.workdir "/var/task/vendor"
      a.cmd     %w{zip -r - .}
    end
  end

  c.stage :test

  c.stage :plan do |s|
    # Add additional options for the Docker build
    s.build_arg :AWS_ACCESS_KEY_ID
    s.build_arg :AWS_DEFAULT_REGION
    s.build_arg :AWS_SECRET_ACCESS_KEY
  end
end

task :default => :build
```
