#!/bin/bash
export SPEEDTEST_IP=${SPEEDTEST_IP:-192.168.8.120}

cmd-all(){
  cmd-nginxconfig > /tmp/nginx.conf
  cmd-haproxyconfig > /tmp/haproxy.cfg
  cmd-start /tmp/nginx.conf /tmp
  sleep 5
  cmd-benchmark nginx
  sleep 2
  cmd-benchmark haproxy
  sleep 2
  cmd-benchmark kv
  sleep 2
  cmd-benchmark dns
  sleep 2
  cmd-stop
}

cmd-webserverrun(){
	/bin/webserver
}

cmd-webserver(){
	local name="$1"; shift
	local port="$1"; shift
	# run the webserver container
	docker run -d --name $name -p $SPEEDTEST_IP:$port:8080 binocarlos/ambassadord-speedtest webserver:run
	# register it with consul service
	curl -s -X PUT -H "Content-Type: application/json" -d '{"ID":"'"$name"'","Name":"web","Tags":[],"Port":'"$port"'}' http://$SPEEDTEST_IP:8500/v1/agent/service/register
	# register it with consul kv
	curl -s -X PUT -d "$SPEEDTEST_IP:$port" http://$SPEEDTEST_IP:8500/v1/kv/web/$name
}

cmd-webservers(){
  cmd-webserver web1 8081
  cmd-webserver web2 8082
  cmd-webserver web3 8083
}

cmd-consul(){
  $(docker run --rm -e EXPECT=1 progrium/consul cmd:run $SPEEDTEST_IP -d)
}

cmd-ambassadord(){
  docker run -d -v /var/run/docker.sock:/var/run/docker.sock --dns 172.17.42.1 --name backends progrium/ambassadord --omnimode
  docker run --rm --privileged --net container:backends progrium/ambassadord --setup-iptables
}

cmd-nginx(){
  local nginxconf="$1"; shift
  if [[ -z $nginxconf ]]; then
    echo "no config given";
    exit 1;
  fi
  docker run -d --name nginx -v $nginxconf:/etc/nginx.conf:ro nginx
}

cmd-haproxy(){
  local haproxyconf="$1"; shift
  if [[ -z $haproxyconf ]]; then
    echo "no config given";
    exit 1;
  fi
  docker run -d --name haproxy -v $haproxyconf:/haproxy-override dockerfile/haproxy
}

cmd-start(){
	local nginxconf="$1"; shift
	local haproxyconf="$1"; shift
	cmd-consul
	cmd-ambassadord
	cmd-nginx $nginxconf
	cmd-haproxy $haproxyconf
	sleep 1
	cmd-webservers
}

cmd-stop(){
	docker stop nginx && docker rm nginx
	docker stop haproxy && docker rm haproxy
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
	local link="backends:backends"


	if [[ -z $abargs ]]; then
		abargs="-n 200 -c 20"
	fi

	if [[ "$mode" == "kv" ]]; then
		backend="consul://$SPEEDTEST_IP:8500/web"
	elif [[ "$mode" == "nginx" ]]; then
		link="nginx:backends"
    address="http://backends:80/"
	elif [[ "$mode" == "haproxy" ]]; then
		link="haproxy:backends"
    address="http://backends:80/"
	fi

	echo
	echo "--------------------------------------"
	echo
	echo "$mode Benchmark $abargs $address"
	echo
	echo "--------------------------------------"
	echo
	docker run -ti --rm --dns 172.17.42.1 --link $link -e "BACKEND_8080=$backend" --entrypoint="/usr/bin/ab" binocarlos/ambassadord-speedtest $abargs $address
}

cmd-haproxyconfig(){
	cat <<EOF
global  
   maxconn 4096  
   user haproxy  
   group haproxy
  
defaults  
   log   global  
   mode   http  
   # logs which servers requests go to, plus current connections and a whole lot of other stuff   
   option   httplog  
   option   dontlognull  
   retries   3  
   option redispatch  
   maxconn   2000  
   contimeout   5000  
   clitimeout   50000  
   srvtimeout   50000  
   log        127.0.0.1       local0  
   # use rsyslog rules to forword to a centralized server    
   log        127.0.0.1       local7 debug  
   # check webservers for health, taking them out of the queue as necessary   
   option httpchk  

backend web-backend
   balance roundrobin
   server web1 $SPEEDTEST_IP:8081 check
   server web2 $SPEEDTEST_IP:8082 check
   server web3 $SPEEDTEST_IP:8083 check

frontend http
	bind *:80
	default_backend web-backend
EOF
}

cmd-nginxconfig(){
	cat <<EOF
events {
  worker_connections  4096;  ## Default: 1024
}

http {
    upstream myapp1 {
        server $SPEEDTEST_IP:8081;
        server $SPEEDTEST_IP:8082;
        server $SPEEDTEST_IP:8083;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://myapp1;
        }
    }
}

daemon off;
EOF
}

usage() {
cat <<EOF
Usage:
tbc
EOF
  exit 1
}

main() {
	case "$1" in
  all)                   shift; cmd-all $@;;
	start)                 shift; cmd-start $@;;
  consul)                shift; cmd-consul $@;;
  ambassadord)           shift; cmd-ambassadord $@;;
  nginx)                 shift; cmd-nginx $@;;
  haproxy)               shift; cmd-haproxy $@;;
  start)                 shift; cmd-start $@;;
  stop)                  shift; cmd-stop $@;;
  webserver)             shift; cmd-webserver $@;;
  webservers)            shift; cmd-webservers $@;;
  webserver:run)         shift; cmd-webserverrun $@;;
  benchmark)             shift; cmd-benchmark $@;;
	config:nginx)          shift; cmd-nginxconfig; $@;;
  config:haproxy)        shift; cmd-haproxyconfig; $@;;
  *)                     usage;
	esac
}

main "$@"