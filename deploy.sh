#!/usr/bin/env bash
  set -euo pipefail
  cd "$(dirname "$0")"

  VERSION=${1:?укажите версию: bash deploy.sh 5.0}
  PREFIX=serebryakov-08
  PORT=8024
  REGISTRY=localhost:6008
  IMAGE=$REGISTRY/$PREFIX/probe:$VERSION

  echo "=== Swarm ==="
  if [ "$(docker info --format '{{.Swarm.LocalNodeState}}')" != active ]; then
    docker swarm init --advertise-addr eth0
  fi

  echo "=== Registry: $REGISTRY ==="
  if docker container inspect "$PREFIX-registry" >/dev/null 2>&1; then
    docker start "$PREFIX-registry" >/dev/null
  else
    docker run -d \
      --name "$PREFIX-registry" \
      --restart unless-stopped \
      -p 6008:5000 \
      -v "$PREFIX-registry:/var/lib/registry" \
      registry:2.8.2
  fi

  SECONDS=0
  until curl -sf -m 2 "$REGISTRY/v2/" >/dev/null; do
    if [ "$SECONDS" -ge 90 ]; then
      echo "реестр не ответил за 90 секунд" >&2
      exit 1
    fi
    sleep 1
  done

  echo "=== Build: $IMAGE ==="
  docker build --build-arg VERSION="$VERSION" -t "$IMAGE" .

  echo "=== Push: $IMAGE ==="
  docker push "$IMAGE"

  echo "=== Deploy: $PREFIX, version $VERSION ==="
  VERSION="$VERSION" docker stack deploy \
    --detach=false -c stack.yaml "$PREFIX"

  SECONDS=0
  until curl -sf -m 2 "127.0.0.1:$PORT/notes" >/dev/null; do
    if [ "$SECONDS" -ge 90 ]; then
      echo "приложение не ответило за 90 секунд" >&2
      exit 1
    fi
    sleep 2
  done

  curl -fsS "127.0.0.1:$PORT/notes"
  echo
