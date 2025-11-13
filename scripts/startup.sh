#!/bin/bash
set -e  # Exit on error

# Warte auf App
for i in {1..24}; do
  if curl -f http://localhost:8080/api/health &>/dev/null; then
    echo "✅ App is healthy"
    break
  fi
  if [ $i -eq 24 ]; then
    echo "❌ App failed to start"
    exit 1
  sleep 5
done

# Erstelle Caddyfile
cat > /tmp/Caddyfile <<'EOF'
meine-app.de {
    reverse_proxy 127.0.0.1:8080
}
EOF

# Starte Caddy
docker run -d \
  --name caddy \
  --restart unless-stopped \
  --network host \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v /tmp/Caddyfile:/etc/caddy/Caddyfile:ro \
  caddy:latest