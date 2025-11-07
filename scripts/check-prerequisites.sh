#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

MISSING_TOOLS=""
WARNINGS=""

function check_tool() {
    local tool="$1"
    local version_arg="$2"
    local min_version="$3"
    
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_TOOLS="$MISSING_TOOLS $tool"
        return 1
    fi
    
    if [ -n "$version_arg" ] && [ -n "$min_version" ]; then
        local current_version
        current_version=$($tool $version_arg 2>/dev/null | head -1 || echo "unknown")
        echo "  $tool: $current_version"
    else
        echo "  $tool: installed"
    fi
    
    return 0
}

function check_port() {
    local port="$1"
    if lsof -i :$port >/dev/null 2>&1; then
        WARNINGS="$WARNINGS\n  Port $port is in use"
    fi
}

function check_docker_daemon() {
    if ! docker info >/dev/null 2>&1; then
        MISSING_TOOLS="$MISSING_TOOLS docker-daemon"
        return 1
    fi
}

function check_hosts_file() {
    if ! grep -q "poc-app.local" /etc/hosts 2>/dev/null; then
        WARNINGS="$WARNINGS\n  poc-app.local not in /etc/hosts - you'll need to add it"
    fi
}

echo "Checking prerequisites..."
echo ""

echo "Required tools:"
check_tool "docker" "--version" "20.0"
check_docker_daemon
check_tool "kubectl" "version --client --short" "1.20" || true
check_tool "kind" "version" "0.11" || true  
check_tool "helm" "version --short" "3.0" || true
check_tool "curl" "--version" || true
check_tool "jq" "--version" || true

echo ""
echo "System checks:"

echo "  Memory: $(docker system info --format '{{.MemTotal}}' 2>/dev/null | numfmt --to=iec 2>/dev/null || echo 'unknown')"
echo "  OS: $(uname -s) $(uname -r)"

check_port 80
check_port 443
check_hosts_file

echo ""

if [ -n "$MISSING_TOOLS" ]; then
    echo -e "${RED}Missing required tools:$MISSING_TOOLS${NC}"
    echo ""
    echo "Installation commands:"
    for tool in $MISSING_TOOLS; do
        case $tool in
            "docker")
                echo "  Docker: https://docs.docker.com/get-docker/"
                ;;
            "docker-daemon")
                echo "  Start Docker daemon (Docker Desktop or dockerd)"
                ;;
            "kubectl")
                echo "  kubectl: curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname | tr '[:upper:]' '[:lower:]')/amd64/kubectl"
                ;;
            "kind")
                echo "  kind: https://kind.sigs.k8s.io/docs/user/quick-start/#installation"
                ;;
            "helm")
                echo "  helm: https://helm.sh/docs/intro/install/"
                ;;
            "curl")
                echo "  curl: brew install curl (macOS) or apt install curl (Linux)"
                ;;
            "jq")
                echo "  jq: brew install jq (macOS) or apt install jq (Linux)"
                ;;
        esac
    done
    echo ""
    exit 1
fi

if [ -n "$WARNINGS" ]; then
    echo -e "${YELLOW}Warnings:$WARNINGS${NC}"
    echo ""
fi

echo -e "${GREEN}All prerequisites met${NC}"
echo ""
echo "Next steps:"
echo "  make setup    # Create cluster"
echo "  make build    # Build application"  
echo "  make deploy   # Deploy application"
echo "  make demo     # Run demonstrations"