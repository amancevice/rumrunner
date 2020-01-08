RUBY      := latest
STAGES    := install test build
SHELL     := /bin/sh
IMAGES    := $(foreach STAGE,$(STAGES),image@$(STAGE))
SHELLS    := $(foreach STAGE,$(STAGES),shell@$(STAGE))
CLEANS    := $(foreach STAGE,$(STAGES),clean@$(STAGE))
TIMESTAMP := $(shell date +%s)
VERSION   := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").version')
GEMFILE   := pkg/$(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").full_name').gem

DIGESTS = $(shell awk {print} .docker/rumrunner/* 2> /dev/null | uniq)

.PHONY: default clean clobber gem push shell $(IMAGES) $(SHELLS)

default: gem

.docker/rumrunner pkg:
	mkdir -p $@

.docker/rumrunner/$(VERSION)-install: lib Gemfile rumrunner.gemspec
.docker/rumrunner/$(VERSION)-test:    .docker/rumrunner/$(VERSION)-install
.docker/rumrunner/$(VERSION)-build:   .docker/rumrunner/$(VERSION)-install
.docker/rumrunner/$(VERSION)-%:     | .docker/rumrunner
	docker build \
	--build-arg RUBY_VERSION=$(RUBY) \
	--iidfile $@@$(TIMESTAMP) \
	--tag rumrunner:$(VERSION)-$* \
	--target $* \
	.
	cp $@@$(TIMESTAMP) $@

$(GEMFILE): .docker/rumrunner/$(VERSION)-build | pkg
	docker run --rm --entrypoint cat $(shell cat $<) $@ > $@

$(IMAGES): image@%: .docker/rumrunner/$(VERSION)-%

$(SHELLS): shell@%: .docker/rumrunner/$(VERSION)-%
	docker run --rm -it --entrypoint $(SHELL) $(shell cat $<)

clean@test: clean@build
clean@install: clean@test
$(CLEANS): clean@%:
	-rm -rf .docker/rumrunner/$(VERSION)-$*

clean:
	-rm -rf $(GEMFILE) $(shell ls .docker/rumrunner/$(VERSION)-* 2> /dev/null | grep -v @)

clobber:
	-docker image rm --force rumrunner $(DIGESTS) 2> /dev/null
	-rm -rf .docker/rumrunner pkg

gem: $(GEMFILE)

push: $(GEMFILE)
	gem push $<

shell: shell@$(lastword $(STAGES))
