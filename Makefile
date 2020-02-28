
REPO      := rumrunner
RUBY      := latest
STAGES    := install test build
SHELL     := /bin/sh
CLEANS    := $(foreach STAGE,$(STAGES),clean@$(STAGE))
IMAGES    := $(foreach STAGE,$(STAGES),image@$(STAGE))
SHELLS    := $(foreach STAGE,$(STAGES),shell@$(STAGE))
GEMFILE   := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").full_name').gem
VERSION   := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").version')
TIMESTAMP := $(shell date +%s)

.PHONY: default clean clobber gem push shell $(IMAGES) $(SHELLS)

default: gem

.docker/$(REPO) pkg:
	mkdir -p $@

.docker/$(REPO)/$(VERSION)-install: lib Gemfile rumrunner.gemspec
.docker/$(REPO)/$(VERSION)-test:    .docker/$(REPO)/$(VERSION)-install
.docker/$(REPO)/$(VERSION)-build:   .docker/$(REPO)/$(VERSION)-test
.docker/$(REPO)/$(VERSION)-%:     | .docker/$(REPO)
	docker build \
	--build-arg RUBY=$(RUBY) \
	--iidfile $@@$(TIMESTAMP) \
	--tag $(REPO):$(VERSION)-$* \
	--target $* \
	.
	cp $@@$(TIMESTAMP) $@

clean: $(CLEANS)
	-for i in $$(docker image ls --filter dangling=true --quiet --no-trunc); do for j in $$(grep -l $$i .docker/$(REPO)/* 2> /dev/null); do docker image rm --force $$i; rm $$j; done; done
	-rm pkg/$(GEMFILE)

clobber:
	-docker image ls --quiet $(REPO):$(VERSION)* | xargs docker image rm --force
	-rm -rf .docker pkg

gem: pkg/$(GEMFILE)

push: pkg/$(GEMFILE)
	gem push $<

pkg/$(GEMFILE): .docker/$(REPO)/$(VERSION)-build | pkg
	docker run --rm --entrypoint cat $(shell cat $<) $@ > $@

$(CLEANS): clean@%:
	-rm -rf .docker/$(REPO)/$(VERSION)-$*

$(IMAGES): image@%: .docker/$(REPO)/$(VERSION)-%

$(SHELLS): shell@%: .docker/$(REPO)/$(VERSION)-%
	docker run --rm -it --entrypoint $(SHELL) $(shell cat $<)
