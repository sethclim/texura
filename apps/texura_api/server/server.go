package server

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

func Start() error {
	r := chi.NewRouter()
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("OK"))
	})
	return http.ListenAndServe(":8080", r)
}
