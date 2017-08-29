IMAGE_NAME = s2i-ubuntu-basetools:16.04

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

.PHONY: test
test:
	docker build -t $(IMAGE_NAME) .
	IMAGE_NAME=$(IMAGE_NAME) test/run.sh