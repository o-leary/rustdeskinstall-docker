FROM ubuntu:noble
#USER root
#ENV TZ="Pacific/Auckland"

RUN apt-get update
RUN apt-get install curl sudo nano wget unzip tar dnsutils ca-certificates psmisc --no-install-recommends -y

RUN mkdir /app
COPY *.sh /app
COPY *.ps1 /app
RUN chmod +x /app/*.sh

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash", "/app/entrypoint.sh"]
