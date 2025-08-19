### Modernize certificate generation (eliminate need for `-legacy`)

Problem
- OpenSSL 3.x requires the legacy provider for old algorithms and formats (e.g., PKCS#12 with 3DES/SHA1, PKCS#8 PBES1, deprecated commands like `genrsa`). Our current flows use defaults that trigger legacy (notably PKCS#12 export), which forces `-legacy` when generating/reading artifacts.

Goals
- Default to modern, widely supported algorithms so OpenSSL 3.x works without `-legacy`.
- Keep an option to produce RSA keys for compatibility while preferring EC by default.
- Ensure certs include SANs and use appropriate X.509 extensions.

Proposed changes (high-level)
- Default key type: EC (P‑256 / `prime256v1`). Provide RSA fallback via configuration.
- Use `openssl genpkey` (not `genrsa`/`ecparam`) and store keys in PKCS#8 with modern encryption.
- Make PKCS#12 export use AES and SHA‑256, not legacy PBE (3DES/SHA1).
- Remove deprecated extensions (`nsCertType`) and reduce overly long lifetimes.

Configuration knobs (new)
- `KEY_TYPE`: `ec` (default) | `rsa`
- `EC_CURVE`: `prime256v1` (default) | `secp384r1`
- `RSA_BITS`: `3072` (default) | `4096`
- `SERVER_SANS`: comma-separated SANs, e.g. `DNS:api.local,DNS:api,IP:10.0.0.10`
- `PFX_ITER`: PBKDF2 iterations for PKCS#12 (default: `204000`)
- `PKCS8_ITER`: PBKDF2 iterations for PKCS#8 (default: `204000`)
- `LEAF_DAYS`: server cert validity (default: `398`)

Concrete edits to scripts
1) Key generation: switch to `genpkey` and PKCS#8
- Root/intermediate (password prompts unchanged):
  - RSA example (when `KEY_TYPE=rsa`):
    - `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:${RSA_BITS:-3072} -aes-256-cbc -pass pass:"$PASS" -out <path>.key.pem`
  - EC example (default):
    - `openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:${EC_CURVE:-prime256v1} -pkeyopt ec_param_enc:named_curve -aes-256-cbc -pass pass:"$PASS" -out <path>.key.pem`
- For server key if storing a PKCS#8 copy for apps, use PBES2 + AES and PBKDF2:
  - `openssl pkcs8 -topk8 -v2 aes-256-cbc -iter ${PKCS8_ITER:-204000} -passin pass:"$PASS" -passout pass:"$PASS" -in <server>.key.pem -out <server>.pkcs8.key.pem`

2) CSR and SANs
- Continue `-addext` for SANs, but read from `SERVER_SANS` if provided:
  - `-addext "subjectAltName = ${SERVER_SANS:-DNS:${SERVER_CN}}"`
- Keep `-sha256` for all CSRs.

3) Signing
- Use `-batch` to avoid interactive prompts:
  - `openssl ca -config $intermediateConfig -extensions server_cert -days ${LEAF_DAYS:-398} -notext -md sha256 -batch -passin pass:"$INT_PASS" -in $serverCsr -out $serverCert`

4) PKCS#12 export (eliminate legacy provider)
- Explicitly choose AES and SHA‑256, and modern iteration counts:
  - `openssl pkcs12 -export -inkey $serverKey -passin pass:"$PASS" -in $serverCert -certfile $certificateChain -out $serverPfx -keypbe AES-256-CBC -certpbe AES-256-CBC -macalg sha256 -iter ${PFX_ITER:-204000} -maciter`
- This avoids 3DES/SHA1 PBEs that require the legacy provider.

5) OpenSSL config cleanup (`src/openssl-*.cnf`)
- Remove deprecated lines:
  - `nsCertType = ...` and `nsComment = ...`
- Keep/ensure:
  - `default_md = sha256`
  - `copy_extensions = copy` (already present in intermediate)
  - For server certs: `keyUsage = critical, digitalSignature, keyEncipherment` and `extendedKeyUsage = serverAuth` (already present)
- Optional: add AIA/CRL fields if you plan to distribute CRLs/OCSP.

6) Validity periods
- Current server cert validity is 2920 days (~8 years). Reduce to <= 825 days (public CAB baseline) or 398 days (common enterprise policy). Make it configurable via `LEAF_DAYS`.

7) Backwards compatibility
- Keep RSA as a selectable option (`KEY_TYPE=rsa`). Default to RSA‑3072 or RSA‑4096 for CA keys; RSA‑3072 for server keys unless `KEY_TYPE=ec` is set globally or per‑request.
- Document which clients might still require RSA and how to switch via env vars.

8) Dockerfile hygiene (recommended)
- Pin base image and install a pinned OpenSSL package to ensure consistent behavior:
  - `FROM alpine:3.20` and `RUN apk add --no-cache openssl=~3.1` (adjust to repo availability)
- Consider adding a non‑root user and tini; see repo docker rules.

9) CI/validation (quick tests to prove `-legacy` is not needed)
- Inspect cert:
  - `openssl x509 -noout -text -in ${SERVER_CN}.cert.pem | grep -E "Signature Algorithm|Subject Alternative Name"`
- Verify chain:
  - `openssl verify -CAfile ca-chain.cert.pem ${SERVER_CN}.cert.pem`
- Verify PKCS#12 without legacy:
  - `openssl pkcs12 -in ${SERVER_CN}.pfx -nodes -passin pass:"$PASS" -info >/dev/null`
- Verify PKCS#8 without legacy:
  - `openssl pkcs8 -in ${SERVER_CN}.pkcs8.key.pem -passin pass:"$PASS" -nocrypt -out /dev/null`

Suggested file-level changes
- `src/init.sh`:
  - Replace `genrsa` calls with `genpkey` based on `KEY_TYPE`.
  - Keep signing with `-sha256`/`-sha512` as today.
- `src/request-server-cert.sh`:
  - Generate key via `genpkey` per `KEY_TYPE` and curve/bits.
  - Read SANs from `SERVER_SANS` if present; otherwise default to `DNS:${SERVER_CN}`.
  - Add `-batch` to `openssl ca`.
  - Update PKCS#8 conversion to `-v2 aes-256-cbc -iter ${PKCS8_ITER}`.
  - Update PKCS#12 export to specify `-keypbe AES-256-CBC -certpbe AES-256-CBC -macalg sha256 -iter ${PFX_ITER} -maciter`.
- `src/openssl-root.cnf` and `src/openssl-intermediate.cnf`:
  - Remove `nsCertType`/`nsComment` lines.
  - Optionally set stronger defaults (no functional change if set in CLI): `default_md = sha256` already present.
- `Dockerfile`:
  - Pin base image and OpenSSL package version.

Notes
- These changes avoid the legacy provider by removing dependencies on 3DES/SHA1 PBE and deprecated commands.
- EC (P‑256) will produce smaller/faster keys and signatures, with excellent client support. Keep RSA fallback for legacy clients/policies.
- Iteration counts (`204000`) are a balanced starting point; adjust to your performance envelope.
