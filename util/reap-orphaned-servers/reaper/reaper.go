package reaper

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"github.com/hetznercloud/hcloud-go/v2/hcloud"
)

type (
	ServerClient interface {
		List(ctx context.Context, opts hcloud.ServerListOpts) ([]*hcloud.Server, *hcloud.Response, error)
		DeleteWithResult(ctx context.Context, server *hcloud.Server) (*hcloud.ServerDeleteResult, *hcloud.Response, error)
	}

	Reaper struct {
		serverClient ServerClient
	}
)

var ErrDeleteFailed = errors.New("one or more servers failed to delete")

func New(serverClient ServerClient) *Reaper {
	return &Reaper{serverClient: serverClient}
}

func (r *Reaper) Reap(ctx context.Context, labelSelector string, maxAge time.Duration) error {
	log.Printf("Listing servers with label selector %q", labelSelector)
	servers, err := r.listAll(ctx, labelSelector)
	if err != nil {
		return fmt.Errorf("error listing servers: %w", err)
	}

	failed := false
	for _, server := range servers {
		serverAge := time.Since(server.Created)
		if serverAge <= maxAge {
			log.Printf("Server %d with age %s is not old enough, skipping", server.ID, serverAge)
			continue
		}

		log.Printf("Terminating server %d", server.ID)
		_, _, err := r.serverClient.DeleteWithResult(ctx, server)
		if err != nil {
			log.Printf("Error terminating server %d: %s", server.ID, err)
			failed = true
		}
	}

	if failed {
		return ErrDeleteFailed
	}
	return nil
}

func (r *Reaper) listAll(ctx context.Context, labelSelector string) ([]*hcloud.Server, error) {
	allServers := make([]*hcloud.Server, 0)
	for page := 1; ; page++ {
		servers, _, err := r.serverClient.List(ctx, hcloud.ServerListOpts{
			ListOpts: hcloud.ListOpts{
				Page:          page,
				LabelSelector: labelSelector,
			},
		})
		if err != nil {
			return nil, fmt.Errorf("error listing servers: %w", err)
		}
		if len(servers) == 0 {
			break
		}

		allServers = append(allServers, servers...)
	}

	return allServers, nil
}
