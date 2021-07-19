# Makefile for gitlab-patroni cookbook
# Copyright 2018, GitLab B.V.
# Licence MIT
# vim: ts=8 sw=8 noet

# Variables
UNAME		:= $(shell uname -s)
BUNDLE_PATH	?= ./.bundle

# this is godly
# https://news.ycombinator.com/item?id=11939200
.PHONY: help
help:	### This help screen. Keep it first target to be default
ifeq ($(UNAME), Linux)
	@grep -P '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
else
	@# this is not tested, but prepared in advance for you, Mac drivers
	@awk -F ':.*###' '$$0 ~ FS {printf "%15s%s\n", $$1 ":", $$2}' $(MAKEFILE_LIST) | grep -v '@awk' | sort
endif

# Targets
#
.PHONY: debug
debug:	### Debug Makefile itself
	@echo $(CURL)

.PHONY: gems
gems:	### Install latest versions of all gems
	rm -f Gemfile.lock
	bundle install --jobs $$(nproc) --clean --path $(BUNDLE_PATH)

.PHONY: lint
lint:	cookstyle

.PHONY: cookstyle
cookstyle:
	bundle exec cookstyle

.PHONY: rspec
rspec:
	bundle exec rspec -f d

.PHONY: kitchen
kitchen:
	bundle exec kitchen test --destroy=always
