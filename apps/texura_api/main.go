package main

import (
	"log"

	"github.com/sethclim/texura/apps/texura_api/server"
)

func main() {
	if err := server.Start(); err != nil {
		log.Fatal(err)
	}
}
