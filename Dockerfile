FROM alpine:latest

LABEL maintainer="sohan@graceful.nu"

RUN apk update; apk add openssl

RUN mkdir -p /opt/ca/root; mkdir -p /opt/ca/intermediate; mkdir /opt/ca/output; mkdir /opt/ca/export; mkdir /opt/tools
WORKDIR /opt/tools
COPY src/ /opt/tools/

ENTRYPOINT [ "./main.sh" ]
