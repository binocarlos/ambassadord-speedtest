build:
	go build -o webserver
	docker build -t binocarlos/ambassadord-speedtest .

image:
	docker build -t binocarlos/ambassadord-speedtest .

dev:
	docker run -ti --rm \
		-e SPEEDTEST_IP \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /usr/bin/docker \:/usr/bin/docker \
		-v /srv/projects/ambassadord-speedtest/test.sh:/bin/test \
		binocarlos/ambassadord-speedtest start /tmp/nginx.conf /tmp

.PHONY: build