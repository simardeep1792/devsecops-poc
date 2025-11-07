#!/bin/bash
set -e

VERSION=${1:-v1.0.0}
IMAGE="localhost:5000/poc-app:${VERSION}"

echo "Building image ${IMAGE}..."

cd app/
docker build --build-arg VERSION=${VERSION} -t ${IMAGE} .

echo "Scanning image with Trivy..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE}

echo "Generating SBOM with Syft..."
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  anchore/syft:latest ${IMAGE} -o spdx-json > ../sbom-${VERSION}.json

echo "Signing image with Cosign..."
if [ ! -f cosign.key ]; then
  echo "Generating cosign key pair..."
  echo "" | docker run --rm -i -v "$PWD":/workspace -w /workspace \
    gcr.io/projectsigstore/cosign:latest generate-key-pair
fi

COSIGN_PASSWORD="" docker run --rm -v "$PWD":/workspace -v /var/run/docker.sock:/var/run/docker.sock -w /workspace \
  -e COSIGN_PASSWORD \
  gcr.io/projectsigstore/cosign:latest sign --key cosign.key ${IMAGE}

echo "Pushing image to registry..."
docker push ${IMAGE}

echo "Build complete!"
echo "Image: ${IMAGE}"
echo "SBOM: sbom-${VERSION}.json"
echo ""
echo "Deploy with: kubectl argo rollouts set image poc-app poc-app=${IMAGE} -n poc-demo"