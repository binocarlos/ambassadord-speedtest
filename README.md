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

#### `start`

This starts a single consul and ambassadord - make sure hte IP variable is set to an accessible IP on your machine.

```
$ docker run -ti --rm -e IP=192.168.8.120 -v /var/run/docker.sock:/var/run/docker.sock binocarlos/ambassadord-speedtest start
```

#### `benchmark direct|dns|kv [AB_OPTS...]`

Run apache bench against one of the backends.

AB_OPTS defaults to `-n 200 -c 20`

```
$ docker run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock binocarlos/ambassadord-speedtest benchmark dns
$ docker run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock binocarlos/ambassadord-speedtest benchmark kv
$ docker run -ti --rm -v /var/run/docker.sock:/var/run/docker.sock binocarlos/ambassadord-speedtest benchmark direct -n 1000 -c 100
```

#### `stop`

Stop the containers and cleanup

```
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock binocarlos/ambassadord-speedtest stop
```

## license

MIT