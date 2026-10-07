#!/bin/sh
# Tests skills/security against a fixture repo with planted threats, using the real `claude`.
# Run: sh skills/security/security-test.sh. It takes minutes and uses your Claude account.
# It writes ~/.warstack/runs/<yyyymmdd>-adhoc/security.md and the ledger
# ~/.warstack/repos/local-warstack-security-fixture/, and removes that ledger afterwards.

PLUGIN=$(cd "$(dirname "$0")/../.." && pwd)
TMP=$(mktemp -d); FIX=$TMP/warstack-security-fixture
LEDGER=$HOME/.warstack/repos/local-warstack-security-fixture
trap 'rm -rf "$TMP" "$LEDGER"' EXIT
mkdir -p "$FIX/src" "$FIX/.github/workflows" && cd "$FIX" || exit 1
git init -q && git config user.email t@example.com && git config user.name t

# A token-shaped value (random, never live), committed then deleted: it must be found in history.
TOKEN=ghp_$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 36)
echo "module.exports = { githubToken: '$TOKEN' };" > src/config.js
git add -A && git commit -qm "add config"
git rm -q src/config.js && git commit -qm "remove config"
mkdir -p src

cat > package.json <<'EOF'
{ "name": "fixture", "version": "1.0.0", "dependencies": { "express": "4.17.1", "lodash": "4.17.4", "cors": "2.8.5" } }
EOF
cat > src/server.js <<'EOF'
const express = require('express');
const cors = require('cors');
const _ = require('lodash');
const db = require('./db');
const app = express();
app.use(cors());
app.use(express.json());
app.get('/users', (req, res) => db.query("SELECT * FROM users WHERE id = " + req.query.id).then(r => res.json(r)));
app.post('/prefs', (req, res) => res.json(_.defaultsDeep({}, req.body)));
app.listen(3000);
EOF
echo "module.exports = { query: async (sql) => [] };" > src/db.js
cat > .github/workflows/pr.yml <<'EOF'
on: pull_request_target
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { ref: "${{ github.event.pull_request.head.sha }}" }
      - run: npm install && npm test
        env: { NPM_TOKEN: "${{ secrets.NPM_TOKEN }}" }
EOF
git add -A && git commit -qm "add server"

OUT=$HOME/.warstack/runs/$(date +%Y%m%d)-adhoc/security.md
rm -f "$OUT"
claude -p "/warstack:security $FIX" --plugin-dir "$PLUGIN" --permission-mode auto </dev/null > "$TMP/claude.log" 2>&1

fail=0
t() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fail=1; fi; }
# One line per threat: its heading, Location and Threat lines joined.
threats() { awk '/^### S-/{if(l)print l; l=$0; next} /^## /{if(l)print l; l=""} l&&/^(Location|Threat):/{l=l" "$0} END{if(l)print l}' "$OUT"; }
found() { threats | grep -iE "\[($1)\]" | grep -iqE "$2"; } # severities, keyword

t "writes security.md"                         '[ -s "$OUT" ]'
t "SQL injection on a public route: critical"  'found critical "sql"'
t "deleted token in history: high+"            'found "critical|high" "token|secret|credential"'
t "lodash 4.17.4 prototype pollution: high+"   'found "critical|high" "lodash"'
t "pull_request_target with secrets: high+"    'found "critical|high" "pull_request_target|workflow"'
t "permissive CORS: reported"                  'found "critical|high|medium|low" "cors"'
t "token value never written (Rule 2)"         '! grep -qF "$TOKEN" "$OUT"'
t "every angle in Coverage"                    'grep -q "^## Coverage" "$OUT"'
t "ledger written"                             '[ -s "$LEDGER/security.md" ]'

[ $fail = 0 ] || { echo "--- claude output (tail)"; tail -30 "$TMP/claude.log"; echo "--- report: $OUT"; }
exit $fail
