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
	channel = os.Getenv("DEPLOYMENT_CHANNEL")
	errorRate = 0.0
	latencyMs = 50
)

func init() {
	if version == "" {
		version = "v1.0.0"
	}
	
	if channel == "" {
		channel = "stable"
	}
	
	switch version {
	case "v1.2.0":
		errorRate = 0.3
	case "v1.3.0":
		latencyMs = 2000
	}
}

func main() {
	http.HandleFunc("/", rootHandler)
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

func rootHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	
	backgroundColor := "#4CAF50"
	channelText := "STABLE"
	
	if channel == "canary" {
		backgroundColor = "#FF9800"
		channelText = "CANARY"
	}
	
	html := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <title>DevSecOps PoC - %s</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: %s;
            color: white;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            text-align: center;
        }
        .container {
            background-color: rgba(0, 0, 0, 0.2);
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        h1 {
            margin: 0 0 20px 0;
            font-size: 4em;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        .info {
            font-size: 1.5em;
            margin: 10px 0;
        }
        .channel {
            font-size: 2em;
            font-weight: bold;
            margin: 20px 0;
            padding: 10px;
            background-color: rgba(0, 0, 0, 0.3);
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>%s</h1>
        <div class="channel">%s RELEASE</div>
        <div class="info">Hostname: %s</div>
        <div class="info">Request Time: %s</div>
    </div>
</body>
</html>
`, version, backgroundColor, version, channelText, hostname, time.Now().Format("15:04:05"))
	
	w.Header().Set("Content-Type", "text/html")
	fmt.Fprint(w, html)
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