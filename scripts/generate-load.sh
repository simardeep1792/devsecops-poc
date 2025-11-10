#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Initialize counters
TOTAL_REQUESTS=0
STABLE_REQUESTS=0
CANARY_REQUESTS=0
STABLE_SUCCESS=0
CANARY_SUCCESS=0
STABLE_ERRORS=0
CANARY_ERRORS=0
START_TIME=$(date +%s)

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Stopping load generator...${NC}"
    print_summary
    exit 0
}

# Trap Ctrl+C
trap cleanup INT TERM

# Function to print summary
print_summary() {
    local END_TIME=$(date +%s)
    local DURATION=$((END_TIME - START_TIME))
    
    echo -e "\n${BLUE}=== Load Generation Summary ===${NC}"
    echo -e "Duration: ${DURATION} seconds"
    echo -e "Total Requests: ${CYAN}${TOTAL_REQUESTS}${NC}"
    echo ""
    echo -e "${GREEN}Stable Traffic (80% - no header):${NC}"
    echo -e "  Requests: ${STABLE_REQUESTS}"
    echo -e "  Success: ${GREEN}${STABLE_SUCCESS}${NC}"
    echo -e "  Errors: ${RED}${STABLE_ERRORS}${NC}"
    if [ $STABLE_REQUESTS -gt 0 ]; then
        local STABLE_SUCCESS_RATE=$((STABLE_SUCCESS * 100 / STABLE_REQUESTS))
        echo -e "  Success Rate: ${STABLE_SUCCESS_RATE}%"
    fi
    echo ""
    echo -e "${YELLOW}QA Traffic (canary validation):${NC}"
    echo -e "  Requests: ${CANARY_REQUESTS}"
    echo -e "  Success: ${GREEN}${CANARY_SUCCESS}${NC}"
    echo -e "  Errors: ${RED}${CANARY_ERRORS}${NC}"
    if [ $CANARY_REQUESTS -gt 0 ]; then
        local CANARY_SUCCESS_RATE=$((CANARY_SUCCESS * 100 / CANARY_REQUESTS))
        echo -e "  Success Rate: ${CANARY_SUCCESS_RATE}%"
    fi
}

# Function to make request and track response
make_request() {
    local USE_HEADER=$1
    local ENDPOINT=$2
    local START=$(date +%s%N)
    
    if [ "$USE_HEADER" = "true" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" "http://poc-app-qa.local${ENDPOINT}" 2>/dev/null)
        ((CANARY_REQUESTS++))
    else
        RESPONSE=$(curl -s -w "\n%{http_code}" "http://poc-app.local${ENDPOINT}" 2>/dev/null)
        ((STABLE_REQUESTS++))
    fi
    
    local END=$(date +%s%N)
    local LATENCY=$(( (END - START) / 1000000 )) # Convert to milliseconds
    
    # Extract status code (last line)
    local STATUS_CODE=$(echo "$RESPONSE" | tail -1)
    local BODY=$(echo "$RESPONSE" | head -n -1)
    
    # Track success/errors
    if [[ "$STATUS_CODE" =~ ^2[0-9][0-9]$ ]]; then
        if [ "$USE_HEADER" = "true" ]; then
            ((CANARY_SUCCESS++))
        else
            ((STABLE_SUCCESS++))
        fi
    else
        if [ "$USE_HEADER" = "true" ]; then
            ((CANARY_ERRORS++))
        else
            ((STABLE_ERRORS++))
        fi
    fi
    
    ((TOTAL_REQUESTS++))
    
    # Extract version if available
    local VERSION=""
    if [[ "$ENDPOINT" == "/version" ]] && [[ "$STATUS_CODE" =~ ^2[0-9][0-9]$ ]]; then
        VERSION=$(echo "$BODY" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
    fi
    
    # Return latency, status, and version
    echo "$LATENCY $STATUS_CODE $VERSION"
}

# Function to print live stats
print_stats() {
    local CURRENT_TIME=$(date +%s)
    local ELAPSED=$((CURRENT_TIME - START_TIME))
    
    # Clear previous lines and print updated stats
    echo -e "\033[7A\r" # Move up 7 lines
    echo -e "${BLUE}=== Live Traffic Stats (${ELAPSED}s) ===${NC}"
    echo -e "Total Requests: ${CYAN}${TOTAL_REQUESTS}${NC} | Rate: $((TOTAL_REQUESTS / (ELAPSED + 1)))/s"
    echo -e "${GREEN}Stable:${NC} ${STABLE_REQUESTS} requests (${GREEN}${STABLE_SUCCESS}${NC} OK, ${RED}${STABLE_ERRORS}${NC} ERR)"
    echo -e "${YELLOW}Canary:${NC} ${CANARY_REQUESTS} requests (${GREEN}${CANARY_SUCCESS}${NC} OK, ${RED}${CANARY_ERRORS}${NC} ERR)"
    
    # Calculate and display success rates
    local STABLE_RATE=0
    local CANARY_RATE=0
    if [ $STABLE_REQUESTS -gt 0 ]; then
        STABLE_RATE=$((STABLE_SUCCESS * 100 / STABLE_REQUESTS))
    fi
    if [ $CANARY_REQUESTS -gt 0 ]; then
        CANARY_RATE=$((CANARY_SUCCESS * 100 / CANARY_REQUESTS))
    fi
    echo -e "Success Rates: Stable=${STABLE_RATE}% | Canary=${CANARY_RATE}%"
    echo -e "Press ${RED}Ctrl+C${NC} to stop"
    echo ""
}

# Main execution
echo -e "${BLUE}Starting load generator...${NC}"
echo -e "Traffic destinations: Stable URL for production, QA URL for canary validation"
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""
echo ""

# Background process to update stats every 5 seconds
(
    while true; do
        sleep 5
        print_stats
    done
) &
STATS_PID=$!

# Main load generation loop
while true; do
    # Generate random number 1-100
    RAND=$((RANDOM % 100 + 1))
    
    # 80% chance for stable traffic, 20% for canary
    if [ $RAND -le 80 ]; then
        USE_HEADER="false"
    else
        USE_HEADER="true"
    fi
    
    # Alternate between endpoints
    case $((TOTAL_REQUESTS % 3)) in
        0) ENDPOINT="/health" ;;
        1) ENDPOINT="/version" ;;
        2) ENDPOINT="/work" ;;
    esac
    
    # Make the request in background to maintain rate
    make_request "$USE_HEADER" "$ENDPOINT" &
    
    # Small delay to control rate (10 requests per second)
    sleep 0.1
    
    # Limit background processes
    while [ $(jobs -r | wc -l) -ge 10 ]; do
        sleep 0.01
    done
done

# Cleanup stats process on exit
trap "kill $STATS_PID 2>/dev/null; cleanup" EXIT