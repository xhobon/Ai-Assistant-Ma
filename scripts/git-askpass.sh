#!/bin/sh
set -eu

prompt="${1:-}"
case "$prompt" in
  *Username*) printf "%s" "${GITHUB_USERNAME:-}" ;;
  *Password*) printf "%s" "${GITHUB_TOKEN:-}" ;;
  *) printf "%s" "" ;;
esac

