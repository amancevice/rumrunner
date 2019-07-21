<img alt="rumrunner" src="./docs/icon.png"/>

[![Build Status](https://travis-ci.com/amancevice/rumrunner.svg?branch=master)](https://travis-ci.com/amancevice/rumrunner)
[![codecov](https://codecov.io/gh/amancevice/rumrunner/branch/master/graph/badge.svg)](https://codecov.io/gh/amancevice/rumrunner)

Rum Runner is a Rake-based utility for building multi-stage Dockerfiles.

Users can pair a multi-stage Dockerfile with a Rumfile that uses a
Rake-like DSL to customize each stage's build options and dependencies.

The `rum` executable allows users to easily invoke builds, shell-into
specific stages for debugging, and export artifacts from built containers.

Rum Runner has the following features:
* Rake-like DSL/CLI that enable simple annotation and execution of builds.
* Rumfiles are completely defined in standard Ruby syntax, like Rakefiles.
* Users can chain Docker build stages with prerequisites.
* Artifacts can be exported from stages
* Shell tasks are automatically provided for every stage
* Stage, artifact, and shell, steps can be customized

**Origins**

This project was born from using Makefiles to drive multi-stage builds. For the most part this worked really well, but it became a bit of an ordeal to write for more complex projects. This tool is an attempt to recreate that general technique with minimal annotation and limited assumptions.

## Installation

```bash
gem install rumrunner
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

Create `Rumfile` and describe your build:

```ruby
rum :image_name do
  tag "1.2.3"

  stage :build
  stage :test => :build
  stage :deploy => :test
end
```

Run `bundle exec rum --tasks` to view the installed tasks:

```bash
rum build                # Build `build` stage
rum build:clean          # Remove any temporary images and products from `build` stage
rum build:shell[shell]   # Shell into `build` stage
rum clean                # Remove any temporary images and products
rum clobber              # Remove any generated files
rum deploy               # Build `deploy` stage
rum deploy:clean         # Remove any temporary images and products from `deploy` stage
rum deploy:shell[shell]  # Shell into `deploy` stage
rum test                 # Build `test` stage
rum test:clean           # Remove any temporary images and products from `test` stage
rum test:shell[shell]    # Shell into `test` stage
```

Run the `<stage>` task to build the image up to that stage and cache the image digest.

Run the `<stage>:shell` task to build the image and then shell into an instance of the image running as a temporary container.

The default shell is `/bin/sh`, but this can be overridden at runtime with the task arg, eg `bundle exec rum build:shell[/bin/bash]`

The name of the images are taken from the name of the initial block and appended with the name of the stage. The above example would build:

- `image_name:1.2.3-build`
- `image_name:1.2.3-test`
- `image_name:1.2.3-deploy`

The default location for the digests is in `.docker`, but that can be modified:

```ruby
rum :image_name => "tmp" do |c|
  # ...
end
```

## Customize Stages

Stages can be customized with blocks. Methods invoked on the stage are (with a few exceptions) passed onto the `docker build` command.

```ruby
rum :image_name do
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
rum :image_name do
  stage :build

  artifact "package.zip" => :build
end
```

By default the container simply `cat`s the file from the container to the local file system, but more complex exports can be defined:

```ruby
rum :image_name do
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
rum :image_name do
  stage :dev

  shell :dev do
    entrypoint "/bin/zsh"
    rm         false
    volume     "#{Dir.pwd}:/var/task/"
  end
end
```

## Default Task

Use the `default` method to set a default task when running `bundle exec rum`:


```ruby
rum :image_name do
  stage :build

  artifact "package.zip" => :build

  default "package.zip"
end
```
