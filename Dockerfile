FROM ubuntu:noble
#USER root
#ENV TZ="Pacific/Auckland"

RUN apt-get update
RUN apt-get install curl sudo nano wget --no-install-recommends -y

RUN ./install.sh install-http

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
