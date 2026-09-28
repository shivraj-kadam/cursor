#!/bin/bash
set -e
echo "=== Backend local health ==="
curl -fsS http://127.0.0.1:8080/api/health || true
echo
echo "=== Frontend local health ==="
curl -fsS http://127.0.0.1/health || true
echo
echo "=== Nginx config ==="
nginx -t || true