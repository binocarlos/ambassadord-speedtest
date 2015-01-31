#!/bin/bash
docker run -ti --rm \
  -e SPEEDTEST_IP \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -v /srv/projects/ambassadord-speedtest/test.sh:/bin/test \
  binocarlos/ambassadord-speedtest "$@"