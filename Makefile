build:
	go build -o webserver
	docker build -t binocarlos/ambassadord-speedtest .

.PHONY: build