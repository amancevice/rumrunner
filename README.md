# Cargofile

[![Build Status](https://travis-ci.com/amancevice/cargofile.svg?branch=master)](https://travis-ci.com/amancevice/cargofile)
[![codecov](https://codecov.io/gh/amancevice/cargofile/branch/master/graph/badge.svg)](https://codecov.io/gh/amancevice/cargofile)

Experiment in building projects with multi-stage Dockerfiles.

## Example

Imagine a simple two-stage Dockerfile:

```Dockerfile
FROM ruby AS build
# Run build steps here...

FROM ruby AS test
# Run test steps here...

FROM ruby AS deploy
# Run deploy steps here...
```

Create `Cargofile` and describe your build:

```ruby
#!/usr/bin/env ruby

require "cargofile"

cargo :imagename do |c|
  c.tag   "1.2.3"
  c.stage :build
  c.stage :test
  c.stage :deploy
end

task :default => :build
```

Run `rake -f Cargofile --tasks` to view the installed tasks:

(*NOTE — eventually there will be a `cargo` entrypoint for that will behave like `rake`*)

```bash
rake build         # Build through build stage
rake build:shell   # Shell into build stage
rake clean         # Remove any temporary products
rake clean:images  # Remove any temporary images
rake clobber       # Remove any generated files
rake plan          # Build through plan stage
rake plan:shell    # Shell into plan stage
rake test          # Build through test stage
rake test:shell    # Shell into test stage
```

Run the `<stage>` task to build the image up to that stage and cache the image digest.

Run the `<stage>:shell` task to build the image and then shell into an instance of the image running as a temporary container.

The name of the images are taken from the name of the initial block and appended with the name of the stage. The above example would build:

- `imagename:1.2.3-build`
- `imagename:1.2.3-test`
- `imagename:1.2.3-deploy`

The default location for the digests is in `.docker`, but that can be modified:

```ruby
cargo :imagename => "tmp" do |c|
  # ...
end
```

### Customize Stages

Stages can be customized with blocks. Methods invoked on the stage are (with a few exceptions) passed onto the `docker build` command.

```ruby
cargo :imagename do |c|
  c.tag   "1.2.3"
  c.stage :build
  c.stage :test

  c.stage :deploy do |s|
    s.build_arg :AWS_ACCESS_KEY_ID
    s.build_arg :AWS_SECRET_ACCESS_KEY
    s.build_arg :AWS_DEFAULT_REGION => "us-east-1"
    s.label     :Fizz
  end
end
```

### Export Artifacts

Use the `artifact` method to specify an artifact to be exported from the image.

```ruby
cargo :imagename do |c|
  c.stage :build do |s|
    s.artifact "package.zip"
  end
end
```

By default the container simply `cat`s the file from the container to the local file system, but more complex exports can be defined:

```ruby
cargo :imagename do |c|
  c.stage :build do |s|
    s.artifact "package.zip" do |a|
      a.workdir "/var/task/"
      a.cmd     %w{zip -r - .}
    end
  end
end
```
