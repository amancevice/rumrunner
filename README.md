<img alt="cargofile" src="./docs/icon.png"/>

[![Build Status](https://travis-ci.com/amancevice/cargofile.svg?branch=master)](https://travis-ci.com/amancevice/cargofile)
[![codecov](https://codecov.io/gh/amancevice/cargofile/branch/master/graph/badge.svg)](https://codecov.io/gh/amancevice/cargofile)

Cargofile is a Rake-based utility for building projects using multi-stage Dockerfiles.

Cargofile allows users to minimally annotate builds using a Rake-like DSL
and execute them with a rake-like CLI.

Carfofile has the following features:
* Cargofiles are completely defined in standard Ruby syntax, like Rakefiles.
* Users can specify Docker build stages with prerequisites.
* Artifacts can be exported from stages
* Stages' build steps can be customized
* Shell tasks are automatically provided for every stage

## Installation

```bash
gem install cargofile
```

## Example

Imagine a simple multi-stage Dockerfile:

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
cargo :image_name do
  tag "1.2.3"

  stage :build
  stage :test => :build
  stage :deploy => :test
end
```

Run `bundle exec cargo --tasks` to view the installed tasks:

```bash
cargo build                # Build `build` stage
cargo build:clean          # Remove any temporary images and products from `build` stage
cargo build:shell[shell]   # Shell into `build` stage
cargo clean                # Remove any temporary images and products
cargo clobber              # Remove any generated files
cargo deploy               # Build `deploy` stage
cargo deploy:clean         # Remove any temporary images and products from `deploy` stage
cargo deploy:shell[shell]  # Shell into `deploy` stage
cargo test                 # Build `test` stage
cargo test:clean           # Remove any temporary images and products from `test` stage
cargo test:shell[shell]    # Shell into `test` stage
```

Run the `<stage>` task to build the image up to that stage and cache the image digest.

Run the `<stage>:shell` task to build the image and then shell into an instance of the image running as a temporary container.

The default shell is `/bin/sh`, but this can be overridden at runtime with the task arg, eg `bundle exec cargo build:shell[/bin/bash]`

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
    cmd     %w[zip -r - .]
  end
end
```

## Customize Shells

By default, all stages have a `:shell` task that can be invoked to build and shell into a container for a stage. By default the container is run as an ephemeral container (`--rm`) in interactive with TTY allocated and a bash shell open.

Customize the shell for a stage with the `shell` method:

```ruby
cargo :image_name do
  stage :dev

  shell :dev do
    entrypoint "/bin/zsh"
    rm         false
    volume     "#{Dir.pwd}:/var/task/"
  end
end
```

## Default Task

Use the `default` method to set a default task when running `bundle exec cargo`:


```ruby
cargo :image_name do
  stage :build

  artifact "package.zip" => :build

  default "package.zip"
end
```
