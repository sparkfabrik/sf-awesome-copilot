# Dockerfile Templates

Template Dockerfiles for each stack. The skill uses these as a basis when
generating per-stack containers during Phase 2.

Each template installs the tools listed in the SKILL.md tool matrix for that
stack. Tool versions are pinned where practical.

## Universal container

Handles cross-cutting scanners: SAST (multi-language), dependency CVEs,
secret detection, SBOM generation, and IaC misconfiguration.

```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# semgrep
RUN pip install --no-cache-dir semgrep

# trivy
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# gitleaks
RUN curl -sSfL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin gitleaks

# grype + syft (Anchore)
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
RUN curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# checkov
RUN pip install --no-cache-dir checkov

COPY scan.sh /usr/local/bin/scan
RUN chmod +x /usr/local/bin/scan

WORKDIR /src
ENTRYPOINT ["scan"]
```

### Universal scan.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

SKIP="${SKIP_TOOLS:-}"
OUTPUT="/output"
MANIFEST="$OUTPUT/manifest.json"

mkdir -p "$OUTPUT"

tools_json="[]"

run_tool() {
  local name="$1"; shift
  if echo ",$SKIP," | grep -qi ",$name,"; then
    tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': 'already run in Phase 3'})
json.dump(t, sys.stdout)")
    return
  fi
  echo "Running $name..."
  "$@"
  local ec=$?
  local outfile="$name.json"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': $ec, 'outputFile': '$outfile', 'status': 'success' if $ec == 0 else 'findings'})
json.dump(t, sys.stdout)")
}

run_tool "semgrep" semgrep scan --config auto --json --output "$OUTPUT/semgrep.json" /src
run_tool "trivy" trivy fs --format json --severity HIGH,CRITICAL --output "$OUTPUT/trivy.json" /src
run_tool "gitleaks" gitleaks detect --source /src --report-format json --report-path "$OUTPUT/gitleaks.json"
run_tool "grype" sh -c "grype dir:/src -o json > $OUTPUT/grype.json"
run_tool "syft" sh -c "syft dir:/src -o json > $OUTPUT/syft.json"

# checkov: only if IaC files exist
if ls /src/*.tf /src/Dockerfile /src/docker-compose.yml /src/k8s/ 2>/dev/null | head -1 > /dev/null; then
  run_tool "checkov" sh -c "checkov -d /src -o json > $OUTPUT/checkov.json 2>&1"
fi

echo "$tools_json" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
manifest = {'stack': 'universal', 'tools': tools}
json.dump(manifest, sys.stdout, indent=2)
" > "$MANIFEST"

echo "Done. Results in $OUTPUT/"
```

## PHP container

For PHP and Drupal projects. Includes dependency auditing, coding standards,
static analysis with taint tracking, and Drupal-specific checks.

```dockerfile
FROM php:8.3-cli

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# phpcs + Drupal coding standards
RUN composer global require \
    "squizlabs/php_codesniffer=*" \
    "drupal/coder=*" \
    --no-interaction --no-progress \
    && /root/.composer/vendor/bin/phpcs --config-set installed_paths /root/.composer/vendor/drupal/coder/coder_sniffer

# psalm
RUN composer global require "vimeo/psalm=*" --no-interaction --no-progress

# phpstan
RUN composer global require "phpstan/phpstan=*" --no-interaction --no-progress

# drupal-check
RUN composer global require "mglaman/drupal-check=*" --no-interaction --no-progress

# local-php-security-checker
RUN curl -sSfL https://github.com/fabpot/local-php-security-checker/releases/latest/download/local-php-security-checker_linux_amd64 \
    -o /usr/local/bin/local-php-security-checker \
    && chmod +x /usr/local/bin/local-php-security-checker

ENV PATH="/root/.composer/vendor/bin:${PATH}"

COPY scan.sh /usr/local/bin/scan
RUN chmod +x /usr/local/bin/scan

WORKDIR /src
ENTRYPOINT ["scan"]
```

### PHP scan.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

SKIP="${SKIP_TOOLS:-}"
OUTPUT="/output"
MANIFEST="$OUTPUT/manifest.json"

mkdir -p "$OUTPUT"

tools_json="[]"

run_tool() {
  local name="$1"; shift
  if echo ",$SKIP," | grep -qi ",$name,"; then
    tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': 'already run in Phase 3'})
json.dump(t, sys.stdout)")
    return
  fi
  echo "Running $name..."
  "$@"
  local ec=$?
  local outfile="$name.json"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': $ec, 'outputFile': '$outfile', 'status': 'success' if $ec == 0 else 'findings'})
json.dump(t, sys.stdout)")
}

skip_tool() {
  local name="$1"
  local reason="$2"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': '$reason'})
json.dump(t, sys.stdout)")
}

# composer audit (works without vendor/)
if [ -f /src/composer.lock ]; then
  run_tool "composer-audit" sh -c "cd /src && composer audit --format=json > $OUTPUT/composer-audit.json 2>&1"
fi

# local-php-security-checker (works without vendor/)
if [ -f /src/composer.lock ]; then
  run_tool "security-checker" sh -c "local-php-security-checker --path=/src/composer.lock --format=json > $OUTPUT/security-checker.json 2>&1"
fi

# phpcs (works without vendor/ for basic analysis)
run_tool "phpcs" sh -c "phpcs --standard=Drupal,DrupalPractice --extensions=php,module,inc,install,theme --report=json /src > $OUTPUT/phpcs.json 2>&1"

# Tools that need vendor/ for full analysis
if [ -d /src/vendor ]; then
  run_tool "psalm" sh -c "cd /src && psalm --taint-analysis --output-format=json > $OUTPUT/psalm.json 2>&1"
  run_tool "phpstan" sh -c "cd /src && phpstan analyse --error-format=json --no-progress > $OUTPUT/phpstan.json 2>&1"
else
  skip_tool "psalm" "vendor/ not found -- run composer install first"
  skip_tool "phpstan" "vendor/ not found -- run composer install first"
fi

# drupal-check
run_tool "drupal-check" sh -c "drupal-check --no-progress --format=json /src/web/modules/custom > $OUTPUT/drupal-check.json 2>&1"

echo "$tools_json" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
manifest = {'stack': 'php', 'tools': tools}
json.dump(manifest, sys.stdout, indent=2)
" > "$MANIFEST"

echo "Done. Results in $OUTPUT/"
```

## Node.js container

For Node.js backends and frontend projects.

```dockerfile
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# retire.js
RUN npm install -g retire

COPY scan.sh /usr/local/bin/scan
RUN chmod +x /usr/local/bin/scan

WORKDIR /src
ENTRYPOINT ["scan"]
```

### Node.js scan.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

SKIP="${SKIP_TOOLS:-}"
OUTPUT="/output"
MANIFEST="$OUTPUT/manifest.json"

mkdir -p "$OUTPUT"

# Note: npm audit should be run directly (Phase 3) since npm ships locally.
# This container focuses on tools the project doesn't already have.

echo "Running retire.js..."
retire --path /src --outputformat json --outputpath "$OUTPUT/retire.json" 2>/dev/null
RETIRE_EC=$?

cat > "$MANIFEST" <<EOFMANIFEST
{
  "stack": "node",
  "tools": [
    {
      "name": "retire",
      "exitCode": $RETIRE_EC,
      "outputFile": "retire.json",
      "status": "$([ $RETIRE_EC -eq 0 ] && echo 'success' || echo 'findings')"
    }
  ]
}
EOFMANIFEST

echo "Done. Results in $OUTPUT/"
```

## Go container

For Go applications and services.

```dockerfile
FROM golang:1.22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# gosec
RUN go install github.com/securego/gosec/v2/cmd/gosec@latest

# govulncheck
RUN go install golang.org/x/vuln/cmd/govulncheck@latest

COPY scan.sh /usr/local/bin/scan
RUN chmod +x /usr/local/bin/scan

WORKDIR /src
ENTRYPOINT ["scan"]
```

### Go scan.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

SKIP="${SKIP_TOOLS:-}"
OUTPUT="/output"
MANIFEST="$OUTPUT/manifest.json"

mkdir -p "$OUTPUT"

tools_json="[]"

run_tool() {
  local name="$1"; shift
  if echo ",$SKIP," | grep -qi ",$name,"; then
    tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': 'already run in Phase 3'})
json.dump(t, sys.stdout)")
    return
  fi
  echo "Running $name..."
  "$@"
  local ec=$?
  local outfile="$name.json"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': $ec, 'outputFile': '$outfile', 'status': 'success' if $ec == 0 else 'findings'})
json.dump(t, sys.stdout)")
}

skip_tool() {
  local name="$1"
  local reason="$2"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': '$reason'})
json.dump(t, sys.stdout)")
}

if [ -f /src/go.sum ]; then
  run_tool "gosec" sh -c "cd /src && gosec -fmt json ./... > $OUTPUT/gosec.json 2>&1"
  run_tool "govulncheck" sh -c "cd /src && govulncheck -json ./... > $OUTPUT/govulncheck.json 2>&1"
else
  skip_tool "gosec" "go.sum not found -- run go mod tidy first"
  skip_tool "govulncheck" "go.sum not found -- run go mod tidy first"
fi

echo "$tools_json" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
manifest = {'stack': 'go', 'tools': tools}
json.dump(manifest, sys.stdout, indent=2)
" > "$MANIFEST"

echo "Done. Results in $OUTPUT/"
```

## Python container

For Python applications and libraries.

```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# bandit
RUN pip install --no-cache-dir bandit

# pip-audit
RUN pip install --no-cache-dir pip-audit

COPY scan.sh /usr/local/bin/scan
RUN chmod +x /usr/local/bin/scan

WORKDIR /src
ENTRYPOINT ["scan"]
```

### Python scan.sh

```bash
#!/usr/bin/env bash
set -uo pipefail

SKIP="${SKIP_TOOLS:-}"
OUTPUT="/output"
MANIFEST="$OUTPUT/manifest.json"

mkdir -p "$OUTPUT"

tools_json="[]"

run_tool() {
  local name="$1"; shift
  if echo ",$SKIP," | grep -qi ",$name,"; then
    tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': None, 'outputFile': None, 'status': 'skipped', 'reason': 'already run in Phase 3'})
json.dump(t, sys.stdout)")
    return
  fi
  echo "Running $name..."
  "$@"
  local ec=$?
  local outfile="$name.json"
  tools_json=$(echo "$tools_json" | python3 -c "
import sys, json
t = json.load(sys.stdin)
t.append({'name': '$name', 'exitCode': $ec, 'outputFile': '$outfile', 'status': 'success' if $ec == 0 else 'findings'})
json.dump(t, sys.stdout)")
}

run_tool "bandit" sh -c "bandit -r /src -f json -o $OUTPUT/bandit.json 2>&1"
run_tool "pip-audit" sh -c "cd /src && pip-audit --format=json -o $OUTPUT/pip-audit.json 2>&1"

echo "$tools_json" | python3 -c "
import sys, json
tools = json.load(sys.stdin)
manifest = {'stack': 'python', 'tools': tools}
json.dump(manifest, sys.stdout, indent=2)
" > "$MANIFEST"

echo "Done. Results in $OUTPUT/"
```
