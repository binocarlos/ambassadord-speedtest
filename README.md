ambassadord-speedtest
=====================

Run Apache Bench against [ambassadord](https://github.com/progrium/ambassadord) backends to compare latency.

Also a useful test that ambassadord is doing its magic.

The script runs 3 web servers that say 'hello world' and registers them as both consul services and in the key value store.

You can then run Apache Bench via the ambassador hooked up in different ways to the webservers to see the effect it has on latency.

There are 3 types of connection to test:

 * direct - connect directly to a webserver
 * dns - use the consul DNS lookup
 * kv - use the consul Key Value store

## usage

The script runs in docker and needs the docker socket mounted as a volume.

#### set IP

First export the IP address of the host you are running these tests on:

```
$ export SPEEDTEST_IP=192.168.8.120
```

#### `config:nginx`

To run the nginx test we must generate a config file:

```
$ docker run --rm \
	-e SPEEDTEST_IP \
	binocarlos/ambassadord-speedtest config:nginx > /tmp/nginx.conf
```

#### `config:haproxy`

With haproxy we have to name the file `haproxy.cfg` and pass the folder that is in to `start`

```
$ docker run --rm \
	-e SPEEDTEST_IP \
	binocarlos/ambassadord-speedtest config:haproxy > /tmp/haproxy.cfg
```

#### `start <nginxconf> <haproxyconf>`

Now we have `/tmp/nginx.conf` we pass it to `start`

We pass the folder that `haproxy.cfg` is in:

This starts a single consul and ambassadord - make sure the IP variable is set to an accessible IP on your machine.

```
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker \:/usr/bin/docker \
	binocarlos/ambassadord-speedtest start /tmp/nginx.conf /tmp
```

#### `benchmark direct|dns|kv|nginx|haproxy [AB_OPTS...]`

Run apache bench against one of the backends.

AB_OPTS defaults to `-n 200 -c 20`

```
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest benchmark dns
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest benchmark nginx
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest benchmark haproxy	
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest benchmark kv
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest benchmark direct -n 1000 -c 100
```

#### `stop`

Stop the containers and cleanup

```
$ docker run --rm \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest stop
```

## weave

First - install it:

```
$ sudo wget -O /usr/local/bin/weave \
  https://raw.githubusercontent.com/zettio/weave/master/weaver/weave
$ sudo chmod a+x /usr/local/bin/weave
```

Now start it:

```
$ sudo weave launch 10.0.0.1/16
```

Then start a web-server:

```
$ WEBSERVER=$(sudo weave run 10.0.1.1/24 binocarlos/ambassadord-speedtest webserver:run)
```

Now we can run the benchmark:

```
$ BENCHMARK=$(sudo weave run 10.0.1.2/24 -ti --entrypoint="/bin/bash" binocarlos/ambassadord-speedtest)
$ docker attach $BENCHMARK
$ ab -n 200 -c 20 http://10.0.1.1:8080/
$ exit
$ docker rm $BENCHMARK
```

## data

The output from running the 3 benchmarks on a vagrant:

This is running with ab settings of `-n 200 -c 20`

```
direct:

	Requests per second:    1345.86 [#/sec] (mean)
	Time per request:       14.860 [ms] (mean)
	Time per request:       0.743 [ms] (mean, across all concurrent requests)

haproxy:

	Requests per second:    811.37 [#/sec] (mean)
	Time per request:       24.650 [ms] (mean)
	Time per request:       1.232 [ms] (mean, across all concurrent requests)

nginx:

	Requests per second:    754.53 [#/sec] (mean)
	Time per request:       26.507 [ms] (mean)
	Time per request:       1.325 [ms] (mean, across all concurrent requests)

kv:

	Requests per second:    606.32 [#/sec] (mean)
	Time per request:       32.986 [ms] (mean)
	Time per request:       1.649 [ms] (mean, across all concurrent requests)

dns:

	Requests per second:    263.57 [#/sec] (mean)
	Time per request:       75.881 [ms] (mean)
	Time per request:       3.794 [ms] (mean, across all concurrent requests)
```

## license

MIT
