all:	check run

check:
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d -ln bash /mnt/build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d -ln bash /mnt/docker_build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -d -ln bash /mnt/install.sh

format:
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w -ln bash /mnt/build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w -ln bash /mnt/docker_build.sh
	docker run --rm -v "$(shell pwd)/scripts":/mnt mvdan/shfmt -w -ln bash /mnt/install.sh

build:
	bash ./scripts/docker_build.sh || true

run: build

.PHONY: check format build run
