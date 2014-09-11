FROM ubuntu:trusty

ADD https://get.docker.io/builds/Linux/x86_64/docker-1.2.0 /bin/docker
RUN chmod +x /bin/docker

RUN apt-get update && apt-get install -y apache2-utils curl

ADD ./test.sh /bin/test
RUN chmod +x /bin/test
ADD ./webserver /bin/webserver
RUN chmod +x /bin/webserver

ENTRYPOINT ["/bin/test"]