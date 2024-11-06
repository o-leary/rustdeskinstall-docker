# Rustdesk server Docker Install
Easy install for Rustdesk in ubuntu docker container. Based on the great work of techahold: https://github.com/techahold/rustdeskinstall. This includes the gohttp server with preconfigured install scripts for clients.<br>
For Rustdesk visit https://rustdesk.com

# Install
Forward the following ports to your docker host:
```
21115:21119/tcp
8000/tcp
21116/udp
```
Clone or download this repo and edit the http_user.txt and http_pass.txt files then:
```
docker compose up -d
```
If you'd rather not use docker secret files remove the secrets sections in the docker-compose.yml file and hardcode them in entrypoint.sh.

# How to update the server
The update script has not been tested in this environment and is highly unlikely to work.
