#!/bin/bash

echo "Generating traffic to poc-app..."
echo "Press Ctrl+C to stop"

while true; do
  curl -s http://poc-app.local/health > /dev/null 2>&1 || true
  curl -s http://poc-app.local/work > /dev/null 2>&1 || true
  curl -s http://canary.poc-app.local/health > /dev/null 2>&1 || true
  curl -s http://canary.poc-app.local/work > /dev/null 2>&1 || true
  sleep 0.1
done