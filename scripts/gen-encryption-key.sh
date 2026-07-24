#!/usr/bin/env bash
set -euo pipefail
# 32-byte AES key as hex for TOKEN_ENCRYPTION_KEY
openssl rand -hex 32
