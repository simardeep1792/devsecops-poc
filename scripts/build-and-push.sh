#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

VERSION=${1:-v1.0.0}
IMAGE="simardeep1792/poc-app:${VERSION}"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_step "Building image ${IMAGE}..."

cd app/ || {
    print_error "Failed to change to app directory"
    exit 1
}

docker build --build-arg VERSION=${VERSION} -t ${IMAGE} . || {
    print_error "Docker build failed"
    exit 1
}

print_step "Scanning image with Trivy..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE} || {
    print_error "Trivy scan failed or found critical vulnerabilities"
    # Continue anyway for demo purposes
    print_info "Continuing despite scan results (demo mode)"
}

print_step "Generating SBOM with Syft..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest ${IMAGE} -o spdx-json > ../sbom-${VERSION}.json || {
    print_error "SBOM generation failed"
    exit 1
}

print_step "Pushing image to Docker Hub..."
docker push ${IMAGE} || {
    print_error "Failed to push image. Are you logged in to Docker Hub?"
    print_info "Run: docker login"
    exit 1
}

print_info "Build complete!"
echo -e "${GREEN}Image:${NC} ${IMAGE}"
echo -e "${GREEN}SBOM:${NC} sbom-${VERSION}.json"
echo ""
print_info "Deploy with: kubectl argo rollouts set image poc-app poc-app=${IMAGE} -n poc-demo"