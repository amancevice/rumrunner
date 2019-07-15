# Cargofile

[![Build Status](https://travis-ci.com/amancevice/cargofile.svg?branch=master)](https://travis-ci.com/amancevice/cargofile)
[![codecov](https://codecov.io/gh/amancevice/cargofile/branch/master/graph/badge.svg)](https://codecov.io/gh/amancevice/cargofile)

Experiment in building projects with multi-stage Dockerfiles.

*THIS IS ALL HIGHLY EXPERIMENTAL AT THE MOMENT*

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

cargo :image_name do
  tag "1.2.3"

  stage :build
  stage :test => :build
  stage :deploy => :test
end
```

Run `rake -f Cargofile --tasks` to view the installed tasks:

(*NOTE — eventually there will be a `cargo` entrypoint for that will behave like `rake`*)

```bash
rake build         # Build `build` stage
rake build:clean   # Remove any temporary images and products from `build` stage
rake build:shell   # Shell into `build` stage
rake clean         # Remove any temporary images and products
rake deploy        # Build `deploy` stage
rake deploy:clean  # Remove any temporary images and products from `deploy` stage
rake deploy:shell  # Shell into `deploy` stage
rake test          # Build `test` stage
rake test:clean    # Remove any temporary images and products from `test` stage
rake test:shell    # Shell into `test` stage
```

Run the `<stage>` task to build the image up to that stage and cache the image digest.

Run the `<stage>:shell` task to build the image and then shell into an instance of the image running as a temporary container.

The name of the images are taken from the name of the initial block and appended with the name of the stage. The above example would build:

- `image_name:1.2.3-build`
- `image_name:1.2.3-test`
- `image_name:1.2.3-deploy`

The default location for the digests is in `.docker`, but that can be modified:

```ruby
cargo :image_name => "tmp" do |c|
  # ...
end
```

## Customize Stages

Stages can be customized with blocks. Methods invoked on the stage are (with a few exceptions) passed onto the `docker build` command.

```ruby
cargo :image_name do
  tag "1.2.3"

  stage :build

  stage :test => :build

  stage :deploy => :test do
    build_arg :AWS_ACCESS_KEY_ID
    build_arg :AWS_SECRET_ACCESS_KEY
    build_arg :AWS_DEFAULT_REGION => "us-east-1"
    label     :Fizz
  end
end
```

## Export Artifacts

Use the `artifact` method to specify an artifact to be exported from the image.

```ruby
cargo :image_name do
  stage :build

  artifact "package.zip" => :build
end
```

By default the container simply `cat`s the file from the container to the local file system, but more complex exports can be defined:

```ruby
cargo :image_name do
  stage :build

  artifact "package.zip" => :build do
    workdir "/var/task/"
    cmd     %w{zip -r - .}
  end
end
```

## Shell into Stages

By default, all stages have a `:shell` task that can be invoked to build and shell into a container for a stage. By default the container is run as an ephemeral container (`--rm`) in interactive with TTY allocated and a bash shell open.

Customize the shell for a stage with the `shell` method:

```ruby
cargo :image_name do
  stage :dev

  shell :dev do
    rm     false
    cmd    "/bin/zsh"
    volume "#{Dir.pwd}:/var/task/"
  end
end
