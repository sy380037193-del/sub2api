#!/usr/bin/env bash
set -euo pipefail

RELEASE_REPO_DIR="${RELEASE_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
DEPLOY_DIR="${DEPLOY_DIR:-/home/ubuntu/sub2api-deploy}"
SERVICE_NAME="${SERVICE_NAME:-sub2api}"
CURRENT_FILE="$RELEASE_REPO_DIR/CURRENT"

if [[ ! -f "$CURRENT_FILE" ]]; then
  echo "CURRENT file not found: $CURRENT_FILE" >&2
  exit 1
fi

ARTIFACT="$(tr -d '\r\n ' < "$CURRENT_FILE")"
PACKAGE="$RELEASE_REPO_DIR/releases/$ARTIFACT.tar.gz"
SHA_FILE="$RELEASE_REPO_DIR/releases/$ARTIFACT.sha256"

if [[ ! -f "$PACKAGE" ]]; then
  echo "Package not found: $PACKAGE" >&2
  exit 1
fi

cd "$RELEASE_REPO_DIR/releases"
if [[ -f "$SHA_FILE" ]]; then
  sha256sum -c "$SHA_FILE"
fi

TAG="github-$ARTIFACT"
RELDIR="$DEPLOY_DIR/releases/$ARTIFACT"
BACKUP="$DEPLOY_DIR/backups/$(date +%Y%m%d-%H%M%S)-$ARTIFACT"
RUNTIME_DIR="$DEPLOY_DIR/local-runtime-build"

mkdir -p "$RELDIR" "$BACKUP" "$RUNTIME_DIR"
rm -rf "$RELDIR"
mkdir -p "$RELDIR"
tar -xzf "$PACKAGE" -C "$RELDIR" --strip-components=1
chmod +x "$RELDIR/sub2api"

cd "$DEPLOY_DIR"
cp docker-compose.yml "$BACKUP/docker-compose.yml"
cp "$RUNTIME_DIR/sub2api" "$BACKUP/sub2api" 2>/dev/null || true
cp -a "$RUNTIME_DIR/resources" "$BACKUP/resources" 2>/dev/null || true

cp "$RELDIR/sub2api" "$RUNTIME_DIR/sub2api"
rm -rf "$RUNTIME_DIR/resources"
cp -a "$RELDIR/resources" "$RUNTIME_DIR/resources"

if [[ ! -f "$RUNTIME_DIR/Dockerfile" ]]; then
  cat > "$RUNTIME_DIR/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.20
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY sub2api /app/sub2api
COPY resources /app/resources
RUN chmod +x /app/sub2api
EXPOSE 8080
ENTRYPOINT ["/app/sub2api"]
DOCKERFILE
fi

docker build -t "sub2api:$TAG" "$RUNTIME_DIR"

export TAG
python3 - <<'PY'
from pathlib import Path
import os

tag = os.environ["TAG"]
p = Path("docker-compose.yml")
text = p.read_text(encoding="utf-8-sig")
lines = text.splitlines()
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("image:") and "sub2api:" in stripped:
        prefix = line[:len(line) - len(line.lstrip())]
        print(f"{stripped} -> image: sub2api:{tag}")
        lines[i] = prefix + f"image: sub2api:{tag}"
        break
else:
    raise SystemExit("sub2api image line not found in docker-compose.yml")
p.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

docker compose up -d --no-deps "$SERVICE_NAME"
docker compose ps "$SERVICE_NAME"