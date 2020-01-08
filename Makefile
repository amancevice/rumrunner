RUBY      := latest
STAGES    := install test build
SHELL     := /bin/sh
CLEANS    := $(foreach STAGE,$(STAGES),clean@$(STAGE))
IMAGES    := $(foreach STAGE,$(STAGES),image@$(STAGE))
SHELLS    := $(foreach STAGE,$(STAGES),shell@$(STAGE))
TIMESTAMP := $(shell date +%s)
VERSION   := $(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").version')
GEMFILE   := pkg/$(shell ruby -e 'puts Gem::Specification::load("rumrunner.gemspec").full_name').gem

.PHONY: default clean clobber gem push shell $(IMAGES) $(SHELLS)

default: $(GEMFILE)

.docker/rumrunner pkg:
	mkdir -p $@

.docker/rumrunner/$(VERSION)-install: lib Gemfile rumrunner.gemspec
.docker/rumrunner/$(VERSION)-test:    .docker/rumrunner/$(VERSION)-install
.docker/rumrunner/$(VERSION)-build:   .docker/rumrunner/$(VERSION)-test
.docker/rumrunner/$(VERSION)-%:     | .docker/rumrunner
	docker build \
	--build-arg RUBY_VERSION=$(RUBY) \
	--iidfile $@@$(TIMESTAMP) \
	--tag rumrunner:$(VERSION)-$* \
	--target $* \
	.
	cp $@@$(TIMESTAMP) $@

clean:
	-find .docker -name '$(VERSION)-*' -not -name '*@*' | xargs rm
	-rm $(GEMFILE)

clobber:
	-awk {print} .docker/* 2> /dev/null | xargs docker image rm --force
	-rm -rf .docker pkg

push: $(GEMFILE)
	gem push $<

$(GEMFILE): .docker/rumrunner/$(VERSION)-build | pkg
	docker run --rm --entrypoint cat $(shell cat $<) $@ > $@

$(IMAGES): image@%: .docker/rumrunner/$(VERSION)-%

$(SHELLS): shell@%: .docker/rumrunner/$(VERSION)-%
	docker run --rm -it --entrypoint $(SHELL) $(shell cat $<)

clean@test: clean@build
clean@install: clean@test
$(CLEANS): clean@%:
	-find .docker -name '$(VERSION)-$*' -not -name '*@*' | xargs rm
