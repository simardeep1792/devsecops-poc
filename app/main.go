package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

var (
	version = os.Getenv("APP_VERSION")
	errorRate = 0.0
	latencyMs = 50
)

func init() {
	if version == "" {
		version = "v1.0.0"
	}
	
	switch version {
	case "v1.2.0":
		errorRate = 0.3
	case "v1.3.0":
		latencyMs = 2000
	}
}

func main() {
	http.HandleFunc("/version", versionHandler)
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/work", workHandler)
	
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	
	log.Printf("Starting server on port %s (version %s)", port, version)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}

func versionHandler(w http.ResponseWriter, r *http.Request) {
	resp := map[string]string{
		"version": version,
		"status": "healthy",
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if errorRate > 0 && rand.Float64() < errorRate {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	
	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "OK")
}

func workHandler(w http.ResponseWriter, r *http.Request) {
	time.Sleep(time.Duration(latencyMs) * time.Millisecond)
	
	if errorRate > 0 && rand.Float64() < errorRate {
		http.Error(w, "Internal Server Error", http.StatusInternalServerError)
		return
	}
	
	resp := map[string]interface{}{
		"version": version,
		"processed": true,
		"latency_ms": latencyMs,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}