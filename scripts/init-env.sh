#!/usr/bin/env bash
# Creates fastbite/.env with random passwords on a new laptop. Does nothing if it already exists.
set -eu
cd "$(dirname "$0")/.."
if [ -f .env ]; then echo ".env already exists - leaving it alone."; exit 0; fi
rand() { head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; }   # hex only, safe inside a URL
sed -e "s/^MONGO_ROOT_PASSWORD=.*/MONGO_ROOT_PASSWORD=$(rand)/" \
    -e "s/^MONGO_APP_PASSWORD=.*/MONGO_APP_PASSWORD=$(rand)/" .env.example > .env
chmod 600 .env
echo "Created .env with fresh random passwords (it is git-ignored)."
