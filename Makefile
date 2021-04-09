# Copyright (c) 2017-2021, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

DOCKER ?= docker
MKDIR  ?= mkdir
DIST_DIR ?= $(CURDIR)/dist

LIB_NAME := nvidia-container-runtime
LIB_VERSION := 3.4.2
PKG_REV := 1

TOOLKIT_VERSION := 1.4.2
GOLANG_VERSION  := 1.15.6
GOLANG_PKG_PATH := github.com/NVIDIA/container-runtime/cmd

# By default run all native docker-based targets
docker-native:
include $(CURDIR)/docker/docker.mk

binary:
	go build -ldflags "-s -w" -o "$(LIB_NAME)" $(GOLANG_PKG_PATH)

build:
	@go build -o $(LIB_NAME) $(GOLANG_PKG_PATH)

# Define the check targets for the Golang codebase
MODULE := .
.PHONY: check fmt assert-fmt ineffassign lint misspell vet
check: assert-fmt lint misspell vet
fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l -w

assert-fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l > fmt.out
	@if [ -s fmt.out ]; then \
		echo "\nERROR: The following files are not formatted:\n"; \
		cat fmt.out; \
		rm fmt.out; \
		exit 1; \
	else \
		rm fmt.out; \
	fi

ineffassign:
	ineffassign $(MODULE)/...

lint:
	# We use `go list -f '{{.Dir}}' $(GOLANG_PKG_PATH)/...` to skip the `vendor` folder.
	go list -f '{{.Dir}}' $(MODULE)/... | xargs golint -set_exit_status

misspell:
	misspell $(MODULE)/...

vet:
	go vet $(MODULE)/...

MOCK_RUNC=$(CURDIR)/runc
mock-runc:
	@(printf '#!/bin/bash\necho mock runc') > $(MOCK_RUNC)
	@chmod +x $(MOCK_RUNC)

mock-hook:
	[ ! -e /etc/nvidia-container-runtime ] && mkdir /etc/nvidia-container-runtime || true
	[ ! -e /etc/nvidia-container-runtime/config.toml ] && echo "" > /etc/nvidia-container-runtime/config.toml || true
	[ ! -e /usr/bin/nvidia-container-runtime-hook ] && echo "" > /usr/bin/nvidia-container-runtime-hook && chmod +x /usr/bin/nvidia-container-runtime-hook || true

test: build mock-runc mock-hook
	@go test -v $(MODULE)/...
	@${RM} $(MOCK_RUNC)

.PHONY: docker-test
docker-test:
	$(DOCKER) run \
		--rm \
		-e GOCACHE=/tmp/.cache \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		golang:$(GOLANG_VERSION) \
			make test

