package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/fergalhk-lab/core-infrastructure/util/terraform-matrix-generator/config"
	"github.com/fergalhk-lab/core-infrastructure/util/terraform-matrix-generator/matrix"
	"go.yaml.in/yaml/v2"
)

func main() {
	configPath := flag.String("config", "config/terraform.yaml", "path to terraform config file")
	flag.Parse()

	data, err := os.ReadFile(*configPath)
	if err != nil {
		log.Fatalf("error reading config: %s", err)
	}

	var cfg config.Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		log.Fatalf("error parsing config: %s", err)
	}

	entries, err := matrix.Generate(cfg)
	if err != nil {
		log.Fatalf("error generating matrix: %s", err)
	}

	out, err := json.Marshal(entries)
	if err != nil {
		log.Fatalf("error marshaling output: %s", err)
	}

	fmt.Println(string(out))
}
