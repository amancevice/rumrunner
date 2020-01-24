RUBY_VERSION := latest
STAGES       := install test build
SHELL        := /bin/sh
CLEANS       := $(foreach STAGE,$(STAGES),clean@$(STAGE))
IMAGES       := $(foreach STAGE,$(STAGES),image@$(STAGE))
SHELLS       := $(foreach STAGE,$(STAGES),shell@$(STAGE))
GEMFILE      := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").full_name').gem
VERSION      := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").version')
TIMESTAMP    := $(shell date +%s)

.PHONY: default clean clobber gem push shell $(IMAGES) $(SHELLS)

default: gem

.docker/rumrunner pkg:
	mkdir -p $@

.docker/rumrunner/$(VERSION)-install: lib Gemfile rumrunner.gemspec
.docker/rumrunner/$(VERSION)-test:    .docker/rumrunner/$(VERSION)-install
.docker/rumrunner/$(VERSION)-build:   .docker/rumrunner/$(VERSION)-test
.docker/rumrunner/$(VERSION)-%:     | .docker/rumrunner
	docker build \
	--build-arg RUBY_VERSION=$(RUBY_VERSION) \
	--iidfile $@@$(TIMESTAMP) \
	--tag rumrunner:$(VERSION)-$* \
	--target $* \
	.
	cp $@@$(TIMESTAMP) $@

clean: $(CLEANS)
	-rm pkg/$(GEMFILE)

clobber:
	-awk {print} .docker/* 2> /dev/null | xargs docker image rm --force
	-rm -rf .docker pkg

gem: pkg/$(GEMFILE)

push: pkg/$(GEMFILE)
	gem push $<

pkg/$(GEMFILE): .docker/rumrunner/$(VERSION)-build | pkg
	docker run --rm --entrypoint cat $(shell cat $<) $@ > $@

$(CLEANS): clean@%:
	-rm -rf .docker/rumrunner/$(VERSION)-$*

$(IMAGES): image@%: .docker/rumrunner/$(VERSION)-%

$(SHELLS): shell@%: .docker/rumrunner/$(VERSION)-%
	docker run --rm -it --entrypoint $(SHELL) $(shell cat $<)
