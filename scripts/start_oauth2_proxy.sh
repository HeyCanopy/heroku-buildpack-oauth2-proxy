#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

if [ -z ${PORT+x} ]; then echo "please set PORT"; exit 1; fi
if [ -z ${OAUTH2_PROXY_PROVIDER+x} ]; then echo "please set OAUTH2_PROXY_PROVIDER"; exit 1; fi
if [ -z ${OAUTH2_PROXY_CLIENT_ID+x} ]; then echo "please set OAUTH2_PROXY_CLIENT_ID"; exit 1; fi
if [ -z ${OAUTH2_PROXY_CLIENT_SECRET+x} ]; then echo "please set OAUTH2_PROXY_CLIENT_SECRET"; exit 1; fi
if [ -z ${OAUTH2_PROXY_COOKIE_SECRET+x} ]; then echo "please set OAUTH2_PROXY_COOKIE_SECRET"; exit 1; fi

OAUTH2_PROXY_SET_XAUTHREQUEST="${OAUTH2_PROXY_SET_XAUTHREQUEST:-true}"
export OAUTH2_PROXY_SET_XAUTHREQUEST

OAUTH2_PROXY_PASS_ACCESS_TOKEN="${OAUTH2_PROXY_PASS_ACCESS_TOKEN:-true}"
export OAUTH2_PROXY_PASS_ACCESS_TOKEN

OAUTH2_PROXY_UPSTREAMS="${OAUTH2_PROXY_UPSTREAMS:-http://127.0.0.1:8080}"
export OAUTH2_PROXY_UPSTREAMS

OAUTH2_PROXY_HTTP_ADDRESS="${OAUTH2_PROXY_HTTP_ADDRESS:-http://:$PORT}"
export OAUTH2_PROXY_HTTP_ADDRESS

if [ -n "${OAUTH2_EMAIL_DOMAIN}" ]; then
    OAUTH2_PROXY_EMAIL_DOMAINS="${OAUTH2_EMAIL_DOMAIN}"
else
    OAUTH2_PROXY_EMAIL_DOMAINS="*"
fi
export OAUTH2_PROXY_EMAIL_DOMAINS

if [ -n "${OAUTH2_GITHUB_ORG}" ]; then
    OAUTH2_PROXY_GITHUB_ORG="${OAUTH2_GITHUB_ORG}"
    export OAUTH2_PROXY_GITHUB_ORG
fi

echo "starting oauth2-proxy..."
exec ./oauth2-proxy --custom-templates-dir ../assets/
