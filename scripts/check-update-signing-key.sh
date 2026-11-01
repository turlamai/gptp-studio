#!/usr/bin/env bash
# Fail closed when a release signing private key cannot be verified against
# the exact Ed25519 public trust root shipped to installed gPTP Studio clients.
# Never print private key material or read production secrets in PR CI.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
public="$root/app/keys/updater/public.pem"

verify_pair() {
  local private_key="$1" expected_public="$2" temporary
  test -s "$private_key" || { echo "error: release signing key is missing or empty" >&2; return 1; }
  test -s "$expected_public" || { echo "error: updater trust root is missing" >&2; return 1; }
  temporary="$(mktemp -d)"
  # Private key and derived public bytes remain local to a permission-restricted
  # temporary directory; OpenSSL stderr is suppressed to avoid dumping secrets.
  chmod 700 "$temporary"
  if ! openssl pkey -in "$private_key" -pubout -outform DER \
      > "$temporary/derived.der" 2>/dev/null ||
     ! openssl pkey -pubin -in "$expected_public" -pubout -outform DER \
      > "$temporary/trusted.der" 2>/dev/null; then
    rm -rf "$temporary"
    echo "error: malformed Ed25519 signing key or public trust root" >&2
    return 1
  fi
  if ! cmp -s "$temporary/derived.der" "$temporary/trusted.der"; then
    rm -rf "$temporary"
    echo "error: signing key does not match the shipped updater public key" >&2
    return 1
  fi
  rm -rf "$temporary"
}

self_test() {
  local temporary
  temporary="$(mktemp -d)"
  chmod 700 "$temporary"
  trap 'rm -rf "$temporary"' EXIT
  # Check the real shipped trust root has valid OpenSSL Ed25519 SPKI shape.
  openssl pkey -pubin -in "$public" -pubout -outform DER \
    > "$temporary/shipped.der" 2>/dev/null
  local hex
  hex="$(od -An -tx1 -N12 "$temporary/shipped.der" | tr -d ' \n')"
  [[ "$hex" == 302a300506032b6570032100 ]] || {
    echo "error: shipped updater trust root is not Ed25519" >&2
    return 1
  }
  openssl genpkey -algorithm Ed25519 -out "$temporary/valid.pem" >/dev/null 2>&1
  openssl pkey -in "$temporary/valid.pem" -pubout -out "$temporary/valid-public.pem" >/dev/null 2>&1
  openssl genpkey -algorithm Ed25519 -out "$temporary/wrong.pem" >/dev/null 2>&1
  printf 'invalid private key\n' > "$temporary/invalid.pem"
  verify_pair "$temporary/valid.pem" "$temporary/valid-public.pem"
  if verify_pair "$temporary/wrong.pem" "$temporary/valid-public.pem"; then
    echo "error: mismatched private key was accepted" >&2
    return 1
  fi
  if verify_pair "$temporary/invalid.pem" "$temporary/valid-public.pem"; then
    echo "error: malformed private key was accepted" >&2
    return 1
  fi
  echo "gPTP release key contract: correct, mismatched and invalid key tests passed"
}

umask 077
case "${1:-}" in
  --self-test)
    [[ "$#" -eq 1 ]] || { echo "usage: $0 --self-test | <signer.pem>" >&2; exit 2; }
    self_test
    ;;
  *)
    [[ "$#" -eq 1 ]] || { echo "usage: $0 --self-test | <signer.pem>" >&2; exit 2; }
    verify_pair "$1" "$public"
    echo "gPTP release signing key matches the embedded updater trust root"
    ;;
esac
