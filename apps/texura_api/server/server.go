package server

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
)

type InferenceRequest struct {
	Prompt string `json:"prompt"`
}

func Start() error {
	r := chi.NewRouter()
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})
	r.Post("/inference", func(w http.ResponseWriter, r *http.Request) {

		var inferReq InferenceRequest
		decoder := json.NewDecoder(r.Body)
		decoder.DisallowUnknownFields() // catch unexpected fields

		if err := decoder.Decode(&inferReq); err != nil {
			http.Error(w, "Invalid JSON: "+err.Error(), http.StatusBadRequest)
			return
		}

		log.Printf("Received: %+v\n", inferReq)

		url := os.Getenv("STABLE_DIFFUSION_SERVICE_URL")

		// Create your payload (as a struct or map)
		payload := map[string]interface{}{
			"image_scale": 1,
			"prompt":      inferReq.Prompt,
		}

		// Encode the payload to JSON
		jsonData, err := json.Marshal(payload)
		if err != nil {
			log.Fatalf("JSON encoding failed: %v", err)
		}

		req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
		if err != nil {
			// handle error
		}

		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			// handle error
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			fmt.Println("Read error:", err)
			return
		}
		fmt.Println("Response:", string(body))

		w.Write([]byte(string(body)))
	})
	return http.ListenAndServe(":7070", r)
}
