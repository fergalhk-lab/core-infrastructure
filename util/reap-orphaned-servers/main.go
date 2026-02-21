package main

import (
	"context"
	"flag"
	"log"
	"os"
	"time"

	"github.com/fergalhk-lab/core-infrastructure/util/reap-orphaned-servers/reaper"
	"github.com/hetznercloud/hcloud-go/v2/hcloud"
)

func main() {
	ctx := context.Background()

	maxAge := flag.Duration("max-age", 2*time.Hour, "delete servers older than this duration")
	labelSelector := flag.String("label-selector", "type=packer-build", "The selector to use to filter servers")
	flag.Parse()

	token := os.Getenv("HCLOUD_TOKEN")
	if token == "" {
		log.Panic("Error: HCLOUD_TOKEN environment variable is required")
	}

	client := hcloud.NewClient(hcloud.WithToken(token))

	err := reaper.New(&client.Server).Reap(ctx, *labelSelector, *maxAge)
	if err != nil {
		log.Panicf("Error reaping servers: %s", err)
	}
}
