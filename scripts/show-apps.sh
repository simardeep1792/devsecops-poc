#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

function print_app_status() {
    local name="$1"
    local url="$2"
    local header="$3"
    
    echo -e "${GREEN}[$name]${NC}"
    echo -e "URL: $url"
    if [ -n "$header" ]; then
        echo -e "Header: $header"
    fi
    
    if [ -n "$header" ]; then
        local response=$(curl -s -H "$header" "$url" 2>/dev/null)
    else
        local response=$(curl -s "$url" 2>/dev/null)
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "Response: $response"
        # Extract version if it's JSON
        local version=$(echo "$response" | jq -r '.version // empty' 2>/dev/null)
        if [ -n "$version" ]; then
            echo -e "Version: ${YELLOW}$version${NC}"
        fi
    else
        echo -e "${RED}ERROR: Failed to connect${NC}"
    fi
    echo ""
}

function show_rollout_status() {
    echo -e "${BLUE}Rollout Status:${NC}"
    kubectl argo rollouts get rollout poc-app -n poc-demo --no-color | head -20
    echo ""
}

function show_pods() {
    echo -e "${BLUE}Running Pods:${NC}"
    kubectl get pods -n poc-demo -o wide
    echo ""
}

function continuous_monitoring() {
    print_header "Live Application Monitoring"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${BLUE}$(date)${NC}"
        
        show_rollout_status
        
        echo -e "${BLUE}Application Endpoints:${NC}"
        print_app_status "PRODUCTION (Stable)" "http://poc-app.local/version"
        print_app_status "CANARY (Testing)" "http://poc-app.local/version" "x-testing: true"
        
        echo -e "${BLUE}Health Checks:${NC}"
        print_app_status "Production Health" "http://poc-app.local/health"
        print_app_status "Canary Health" "http://poc-app.local/health" "x-testing: true"
        
        show_pods
        
        sleep 5
    done
}

function side_by_side_demo() {
    print_header "Side-by-Side Application Demo"
    
    echo -e "${GREEN}This demo shows two versions running simultaneously:${NC}"
    echo -e "1. ${BLUE}Production${NC} - Stable version serving normal traffic"
    echo -e "2. ${YELLOW}Canary${NC} - New version accessible via 'x-testing: true' header"
    echo ""
    
    while true; do
        echo -e "${BLUE}Testing Production Application:${NC}"
        print_app_status "PRODUCTION" "http://poc-app.local/version"
        
        echo -e "${YELLOW}Testing Canary Application:${NC}"
        print_app_status "CANARY" "http://poc-app.local/version" "x-testing: true"
        
        echo -e "${GREEN}Want to see:${NC}"
        echo "1. Continue testing"
        echo "2. Live monitoring"
        echo "3. Pod details"
        echo "4. Exit"
        
        read -p "Choose (1-4): " choice
        
        case $choice in
            1)
                continue
                ;;
            2)
                continuous_monitoring
                ;;
            3)
                show_pods
                show_rollout_status
                read -p "Press Enter to continue..."
                ;;
            4)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
        
        echo ""
    done
}

function quick_test() {
    print_header "Quick Application Test"
    
    echo -e "${GREEN}Testing both applications:${NC}"
    echo ""
    
    print_app_status "PRODUCTION (Stable)" "http://poc-app.local/version"
    print_app_status "CANARY (Testing Header)" "http://poc-app.local/version" "x-testing: true"
    
    echo -e "${BLUE}Rollout Summary:${NC}"
    kubectl argo rollouts status poc-app -n poc-demo
}

function show_usage() {
    print_header "Application Viewer Script"
    echo -e "${GREEN}Usage:${NC} $0 [mode]"
    echo ""
    echo -e "${BLUE}Modes:${NC}"
    echo "  quick     - Quick test of both applications"
    echo "  demo      - Interactive side-by-side demo"  
    echo "  monitor   - Continuous live monitoring"
    echo "  status    - Show rollout and pod status"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo "  $0 quick     # Quick test"
    echo "  $0 demo      # Interactive demo"
    echo "  $0 monitor   # Live monitoring"
}

case "$1" in
    "quick")
        quick_test
        ;;
    "demo")
        side_by_side_demo
        ;;
    "monitor")
        continuous_monitoring
        ;;
    "status")
        show_rollout_status
        show_pods
        ;;
    ""|"help")
        show_usage
        ;;
    *)
        echo "Unknown mode: $1"
        show_usage
        ;;
esac