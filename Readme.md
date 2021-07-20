# Dockerized: Certificate Authority

This is not meant to be used as a production ready CA for all use cases.
The goal is to provide a simple CA utility to be able to generate ssl certs for client server authentication within a closed system like a kubernetes cluster.

The example use case is a cluster where a api facade needs to communicate with underlying services over tls.

Use the image to setup a root and intermediate CA, and then generate and sign server certificates.
The certificate chain would be placed with the client, to verify the servers.

Inspiration taken from: 
- [https://karneliuk.com/2021/02/sec-3-building-your-own-containerised-pki-root-ca-with-linux-and-docker-to-simplify-and-secure-network-automation/]
- [https://jamielinux.com/docs/openssl-certificate-authority]


## Build docker image
```bash
docker build . -t osorenan/simpleca
```
## To setup a ca
Change values in the [.env](./.env)

run
```bash
./create-ca
```

to create a server certificate run
```bash
./request-cert
```
## debug
```bash
./debug
```