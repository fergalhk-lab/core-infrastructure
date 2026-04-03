package main

import (
	"flag"
	"log"
	"os"

	"github.com/fergalhk-lab/core-infrastructure/util/render-chart/renderer"
)

func main() {
	configPath := flag.String("config", "", "path to chart config YAML file (required)")
	flag.Parse()

	if *configPath == "" {
		flag.Usage()
		os.Exit(1)
	}

	cfg, err := renderer.ParseConfig(*configPath)
	if err != nil {
		log.Fatalf("Error: %s", err)
	}

	if err := renderer.Render(cfg); err != nil {
		log.Fatalf("Error: %s", err)
	}
}
