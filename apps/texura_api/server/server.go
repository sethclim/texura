package server

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"

	// s3presign "github.com/aws/aws-sdk-go-v2/service/s3/presign"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/cors"
)

type InferenceRequest struct {
	Prompt string `json:"prompt"`
}

func CreatePresignURL(key string) string {
	fmt.Println("CreatePresignURL:", key)
	fmt.Println("CreatePresignURL debug:")
	fmt.Println("  MINIO_ENDPOINT:", os.Getenv("MINIO_ENDPOINT"))
	fmt.Println("  MINIO_REGION:", os.Getenv("MINIO_REGION"))
	fmt.Println("  AWS_ACCESS_KEY_ID:", os.Getenv("AWS_ACCESS_KEY_ID"))
	fmt.Println("  AWS_SECRET_ACCESS_KEY:", os.Getenv("AWS_SECRET_ACCESS_KEY"))
	fmt.Println("  BUCKET:", os.Getenv("BUCKET"))
	fmt.Println("  KEY:", key)
	ctx := context.Background()

	// Manually configure for MinIO
	customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, _ ...interface{}) (aws.Endpoint, error) {
		return aws.Endpoint{
			URL:           os.Getenv("MINIO_ENDPOINT"),
			SigningRegion: os.Getenv("MINIO_REGION"),
		}, nil
	})

	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(os.Getenv("MINIO_REGION")),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(os.Getenv("AWS_ACCESS_KEY_ID"), os.Getenv("AWS_SECRET_ACCESS_KEY"), "")),
		config.WithEndpointResolverWithOptions(customResolver),
	)
	if err != nil {
		panic(err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	presignClient := s3.NewPresignClient(client)

	presigned, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(os.Getenv("BUCKET")),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(15*time.Minute))

	if err != nil {
		panic(err)
	}

	fmt.Println("Presigned URL:", presigned.URL)

	return presigned.URL
}

func Start() error {
	r := chi.NewRouter()

	fe_url := os.Getenv("FRONTEND_URL")

	// CORS middleware
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{fe_url},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-CSRF-Token"},
		ExposedHeaders:   []string{"Link"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

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
			fmt.Println("reqc create error:", err)
			return
		}

		req.Header.Set("Content-Type", "application/json")

		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			fmt.Println("req error:", err)
			return
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			fmt.Println("Read error:", err)
			return
		}
		fmt.Println("Response:", string(body))

		fmt.Println("Calling CreatePresignURL...")
		presignURL := CreatePresignURL(string(body))

		fmt.Println("presignURL:", string(presignURL))

		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(string(presignURL)))
	})
	return http.ListenAndServe(":7070", r)
}
