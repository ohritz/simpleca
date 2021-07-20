# Dockerized: Simple Certificate Authority

This is not meant to be used as a production ready CA for all use cases.
The goal is to provide a simple CA utility to be able to generate ssl certs for client server authentication within a closed system like a kubernetes cluster.

The example use case is a cluster where a api facade needs to communicate with underlying services over tls.

Use the image to setup a root and intermediate CA, and then generate and sign server certificates.
The certificate chain would be placed with the client, to verify the servers.

Inspiration taken from: 
- [https://karneliuk.com/2021/02/sec-3-building-your-own-containerised-pki-root-ca-with-linux-and-docker-to-simplify-and-secure-network-automation/]
- [https://jamielinux.com/docs/openssl-certificate-authority]

## Environment variables.
The following environment variables needs to be passed in in the init phase, these correspond to values in the certificate Subject.
```
ROOT_ORG=[organizationName]
ROOT_COUNTRY=[countryName]
ROOT_STATE=[stateOrProvinceName]
ROOT_LOCALITY=[localityName]
```
## Volume
It is recommended to run the container with a volume mounted to /opt/ca to persist the certificates.
```bash
docker volume create ca-vol
```
An idea is to use some other volume pluggins to place the certificates in a cloud storage.
see: https://docs.docker.com/engine/extend/legacy_plugins/#volume-plugins

## Build docker image
```bash
docker build . -t osorenan/simpleca
```
## To setup a ca
Change values in the [.env](./.env)

run
```bash
./create-ca
# or
docker run \
-it --rm \
--env-file ./.env \
--mount source=ca-vol,target=/opt/ca \
osorenan/simpleca init
```

to create a server certificate run
```bash
./request-cert
# or 
mkdir ${PWD}/certs

docker run \
-it --rm \
--mount source=ca-vol,target=/opt/ca \
-v ${PWD}/certs:/opt/ca/export \
osorenan/simpleca \
[hostname]

```
## debug
```bash
./debug
```

## Further ideas to develop.

- A more configurable request process.
    - Be able to add more hostnames to a request. 
- Ability to pass in a certificate signing request (csr) to be signed.
- Ability to "eject" the root CA private key, for safe storage separately.
- Support Certificate revocation.
    - How the use case would be for that, is not worked out yet.