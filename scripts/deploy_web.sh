#!/usr/bin/env bash
# deploy_web.sh — Deploy hosting/index.html (and assets) to Firebase Hosting
# Usage: bash scripts/deploy_web.sh
set -e

cd "$(dirname "$0")/.."

echo "🚀 Deploying JuiceDates website to Firebase Hosting..."
firebase deploy --only hosting
echo "✅ Done! Live at https://juicedates-2ebf0.web.app"
