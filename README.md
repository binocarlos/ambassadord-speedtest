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

```bash
$ export SPEEDTEST_IP=192.168.8.120
```

## run all tests

The tests are all encompassed inside the container - to run them:

```bash
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	-v /tmp:/tmp \
	binocarlos/ambassadord-speedtest all
```

This will:

 * setup nginx / haproxy config
 * start consul
 * start 3 webservers and register them with consul
 * run the benchmarks (nginx / haproxy / key value / dns)
 * stop and remove the containers

## breakdown

Here is a breakdown of the individual steps that the container will do:


#### `config:nginx`

To run the nginx test we must generate a config file:

```bash
$ docker run --rm \
	-e SPEEDTEST_IP \
	binocarlos/ambassadord-speedtest config:nginx > /tmp/nginx.conf
```

#### `config:haproxy`

With haproxy we have to name the file `haproxy.cfg` and pass the folder that is in to `start`

```bash
$ docker run --rm \
	-e SPEEDTEST_IP \
	binocarlos/ambassadord-speedtest config:haproxy > /tmp/haproxy.cfg
```

#### `start <nginxconf> <haproxyconf>`

Now we have `/tmp/nginx.conf` we pass it to `start`

We pass the folder that `haproxy.cfg` is in:

This starts a single consul and ambassadord - make sure the IP variable is set to an accessible IP on your machine.

```bash
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	binocarlos/ambassadord-speedtest start /tmp/nginx.conf /tmp
```

#### `benchmark dns|kv|nginx|haproxy [AB_OPTS...]`

Run apache bench against one of the backends.

AB_OPTS defaults to `-n 200 -c 20`

```bash
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	binocarlos/ambassadord-speedtest benchmark dns
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	binocarlos/ambassadord-speedtest benchmark nginx
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	binocarlos/ambassadord-speedtest benchmark haproxy
$ docker run -ti --rm \
	-e SPEEDTEST_IP \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v /usr/bin/docker:/usr/bin/docker \
	binocarlos/ambassadord-speedtest benchmark kv
```

#### `stop`

Stop the containers and cleanup

```bash
$ docker run --rm \
	-v /var/run/docker.sock:/var/run/docker.sock \
	binocarlos/ambassadord-speedtest stop
```

## weave

First - install it:

```bash
$ sudo wget -O /usr/local/bin/weave \
  https://raw.githubusercontent.com/zettio/weave/master/weaver/weave
$ sudo chmod a+x /usr/local/bin/weave
```

Now start it:

```bash
$ sudo weave launch
```

Then start a web-server:

```bash
$ WEBSERVER=$(sudo weave run 10.0.1.1/24 binocarlos/ambassadord-speedtest webserver:run)
```

Now we can run the benchmark:

```bash
$ BENCHMARK=$(sudo weave run 10.0.1.2/24 -ti --entrypoint="/bin/bash" binocarlos/ambassadord-speedtest)
$ docker attach $BENCHMARK
$ ab -n 200 -c 20 http://10.0.1.1:8080/
$ exit
$ docker rm $BENCHMARK
```

## data

The output from running the 5 benchmarks:

This is running with ab settings of `-n 200 -c 20`:


```bash

weave:

	Requests per second:    2733.85 [#/sec] (mean)
	Time per request:       7.316 [ms] (mean)
	Time per request:       0.366 [ms] (mean, across all concurrent requests)

nginx:

	Requests per second:    2682.44 [#/sec] (mean)
	Time per request:       7.456 [ms] (mean)
	Time per request:       0.373 [ms] (mean, across all concurrent requests)

haproxy:

	Requests per second:    1074.30 [#/sec] (mean)
	Time per request:       18.617 [ms] (mean)
	Time per request:       0.931 [ms] (mean, across all concurrent requests)

ambassadord kv:

	Requests per second:    789.35 [#/sec] (mean)
	Time per request:       25.337 [ms] (mean)
	Time per request:       1.267 [ms] (mean, across all concurrent requests)

ambassadord dns:

	Requests per second:    353.34 [#/sec] (mean)
	Time per request:       56.603 [ms] (mean)
	Time per request:       2.830 [ms] (mean, across all concurrent requests)
	
```


Summary - the weave result is not load balancing but connecting to a single IP.

However - it is many times faster than `ambassadord kv` and many many times faster than `ambassadord dns`.

## license

MIT
