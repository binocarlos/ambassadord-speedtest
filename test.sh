#!/bin/bash
export IP=${IP:-192.168.8.120}

cmd-webserverrun(){
	/bin/webserver
}

cmd-webserver(){
	local name="$1"; shift
	local port="$1"; shift
	# run the webserver container
	docker run -d --name $name -p $IP:$port:8080 binocarlos/ambassadord-speedtest webserver:run
	# register it with consul service
	curl -s -X PUT -H "Content-Type: application/json" -d '{"ID":"'"$name"'","Name":"web","Tags":[],"Port":'"$port"'}' http://$IP:8500/v1/agent/service/register
	# register it with consul kv
	curl -s -X PUT -d "$IP:$port" http://$IP:8500/v1/kv/web/$name
}

cmd-start(){
	$(docker run --rm -e EXPECT=1 progrium/consul cmd:run $IP -d)
	docker run -d -v /var/run/docker.sock:/var/run/docker.sock --name backends progrium/ambassadord --omnimode
	docker run --rm --privileged --net container:backends progrium/ambassadord --setup-iptables
	sleep 1
	cmd-webserver web1 8081
	cmd-webserver web2 8082
	cmd-webserver web3 8083
}

cmd-stop(){
	docker stop backends && docker rm backends
	docker stop consul && docker rm consul
	docker stop web1 && docker rm web1
	docker stop web2 && docker rm web2
	docker stop web3 && docker rm web3
}

cmd-benchmark() {
	local mode="$1"; shift
	local backend="web.service.consul"
	local address="http://backends:8080/"
	local abargs="$@"

	if [[ -z $abargs ]]; then
		abargs="-n 200 -c 20"
	fi

	if [[ "$mode" == "kv" ]]; then
		backend="consul://$IP:8500/web"
	elif [[ "$mode" == "direct" ]]; then
		address="http://$IP:8081/"
	fi

	echo
	echo "--------------------------------------"
	echo
	echo "$mode Benchmark $abargs $address"
	echo
	echo "--------------------------------------"
	echo
	docker run -ti --rm --link backends:backends -e "BACKEND_8080=$backend" --entrypoint="/usr/bin/ab" binocarlos/ambassadord-speedtest $abargs $address
}

main() {
	case "$1" in
	start)                 shift; cmd-start $@;;
  stop)                  shift; cmd-stop $@;;
  webserver)             shift; cmd-webserver $@;;
  webserver:run)         shift; cmd-webserverrun $@;;
  benchmark)             shift; cmd-benchmark $@;;
  benchmarks)            shift; cmd-benchmarks $@;;
	esac
}

main "$@"