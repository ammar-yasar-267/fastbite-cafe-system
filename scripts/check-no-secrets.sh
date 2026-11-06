#!/usr/bin/env bash
# Fails if a credential-looking string is found in files that git tracks/would track.
# Allowed: ${VARIABLE} placeholders. Blocked: mongodb://user:realpassword@..., Docker Hub tokens, private keys.
cd "$(dirname "$0")/.."
bad=0
FILES=$(find . -type f -not -path '*/node_modules/*' -not -path './.git/*' -not -name '.env' -not -name 'check-no-secrets.sh' -not -name 'package-lock.json')
check() { # description, regex
  hits=$(grep -IEn "$2" $FILES 2>/dev/null | grep -v '\${')
  if [ -n "$hits" ]; then echo "FOUND $1:"; echo "$hits"; bad=1; fi
}
check "MongoDB URL with an embedded password" 'mongodb(\+srv)?://[^/$ "'"'"']+:[^@$ "'"'"']+@'
check "Docker Hub access token"            'dckr_pat_[A-Za-z0-9_-]+'
check "GitHub token"                       'gh[pousr]_[A-Za-z0-9]{20,}'
check "private key"                        'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'
if [ $bad -eq 0 ]; then echo "OK: no credentials found in the source directory."; fi
exit $bad
