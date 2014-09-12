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
	local nginxconf="$1"; shift
	local haproxyconf="$1"; shift
	$(docker run --rm -e EXPECT=1 progrium/consul cmd:run $IP -d)
	docker run -d -v /var/run/docker.sock:/var/run/docker.sock --name backends progrium/ambassadord --omnimode
	docker run --rm --privileged --net container:backends progrium/ambassadord --setup-iptables
	docker run -d -p 8080 --name nginx -v $nginxconf:/etc/nginx.conf:ro nginx
	docker run -d -p 8080 --name haproxy -v $haproxyconf:/haproxy-override dockerfile/haproxy
	sleep 1
	cmd-webserver web1 8081
	cmd-webserver web2 8082
	cmd-webserver web3 8083
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
		backend="consul://$IP:8500/web"
	elif [[ "$mode" == "direct" ]]; then
		address="http://$IP:8081/"
	elif [[ "$mode" == "nginx" ]]; then
		link="nginx:backends"
	elif [[ "$mode" == "haproxy" ]]; then
		link="haproxy:backends"
	fi

	echo
	echo "--------------------------------------"
	echo
	echo "$mode Benchmark $abargs $address"
	echo
	echo "--------------------------------------"
	echo
	docker run -ti --rm --link $link -e "BACKEND_8080=$backend" --entrypoint="/usr/bin/ab" binocarlos/ambassadord-speedtest $abargs $address
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
   server web1 $IP:8081 check
   server web2 $IP:8082 check
   server web3 $IP:8083 check

frontend http
	bind *:8080
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
        server $IP:8081;
        server $IP:8082;
        server $IP:8083;
    }

    server {
        listen 8080;

        location / {
            proxy_pass http://myapp1;
        }
    }
}

daemon off;
EOF
}

main() {
	case "$1" in
	start)                 shift; cmd-start $@;;
  stop)                  shift; cmd-stop $@;;
  webserver)             shift; cmd-webserver $@;;
  webserver:run)         shift; cmd-webserverrun $@;;
  benchmark)             shift; cmd-benchmark $@;;
	config:nginx)          shift; cmd-nginxconfig; $@;;
  config:haproxy)        shift; cmd-haproxyconfig; $@;;
	esac
}

main "$@"