package main

import (
	"log"

	"songothon/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		log.Fatalf("error executing root command: %v", err)
	}
}
