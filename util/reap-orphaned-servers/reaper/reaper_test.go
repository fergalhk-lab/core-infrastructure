package reaper_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/fergalhk-lab/core-infrastructure/util/reap-orphaned-servers/reaper"
	"github.com/fergalhk-lab/core-infrastructure/util/reap-orphaned-servers/reaper/mocks"
	"github.com/hetznercloud/hcloud-go/v2/hcloud"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/mock/gomock"
)

const maxAge = time.Hour

func setup(t *testing.T) (*reaper.Reaper, *mocks.MockServerClient) {
	t.Helper()
	ctrl := gomock.NewController(t)
	client := mocks.NewMockServerClient(ctrl)
	return reaper.New(client), client
}

func listOpts(page int) hcloud.ServerListOpts {
	return hcloud.ServerListOpts{ListOpts: hcloud.ListOpts{Page: page, LabelSelector: "env=test"}}
}

func serverWithAge(id int64, age time.Duration) *hcloud.Server {
	return &hcloud.Server{ID: id, Created: time.Now().Add(-age)}
}

func expectPages(client *mocks.MockServerClient, pages ...[]*hcloud.Server) {
	for i, page := range pages {
		client.EXPECT().List(gomock.Any(), listOpts(i+1)).Return(page, nil, nil)
	}
	client.EXPECT().List(gomock.Any(), listOpts(len(pages)+1)).Return(nil, nil, nil)
}

func reap(t *testing.T, r *reaper.Reaper) error {
	t.Helper()
	return r.Reap(context.Background(), "env=test", maxAge)
}

func TestReap_NoServers(t *testing.T) {
	r, client := setup(t)
	expectPages(client)
	require.NoError(t, reap(t, r))
}

func TestReap_TooYoung(t *testing.T) {
	r, client := setup(t)
	expectPages(client, []*hcloud.Server{serverWithAge(1, maxAge/2)})
	require.NoError(t, reap(t, r))
}

func TestReap_OldEnough(t *testing.T) {
	r, client := setup(t)
	server := serverWithAge(1, maxAge*2)
	expectPages(client, []*hcloud.Server{server})
	client.EXPECT().DeleteWithResult(gomock.Any(), server).Return(&hcloud.ServerDeleteResult{}, nil, nil)
	require.NoError(t, reap(t, r))
}

func TestReap_MixedAges(t *testing.T) {
	r, client := setup(t)
	old, young := serverWithAge(1, maxAge*2), serverWithAge(2, maxAge/2)
	expectPages(client, []*hcloud.Server{old, young})
	client.EXPECT().DeleteWithResult(gomock.Any(), old).Return(&hcloud.ServerDeleteResult{}, nil, nil)
	require.NoError(t, reap(t, r))
}

func TestReap_ListError(t *testing.T) {
	r, client := setup(t)
	listErr := errors.New("network error")
	client.EXPECT().List(gomock.Any(), listOpts(1)).Return(nil, nil, listErr)
	require.ErrorIs(t, reap(t, r), listErr)
}

func TestReap_DeleteError(t *testing.T) {
	r, client := setup(t)
	server := serverWithAge(1, maxAge*2)
	expectPages(client, []*hcloud.Server{server})
	client.EXPECT().DeleteWithResult(gomock.Any(), server).Return(nil, nil, errors.New("delete failed"))
	assert.ErrorIs(t, reap(t, r), reaper.ErrDeleteFailed)
}

// TestReap_DeleteErrorContinues verifies a delete failure doesn't prevent
// attempting to delete remaining servers.
func TestReap_DeleteErrorContinues(t *testing.T) {
	r, client := setup(t)
	s1, s2 := serverWithAge(1, maxAge*2), serverWithAge(2, maxAge*2)
	expectPages(client, []*hcloud.Server{s1, s2})
	client.EXPECT().DeleteWithResult(gomock.Any(), s1).Return(nil, nil, errors.New("delete failed"))
	client.EXPECT().DeleteWithResult(gomock.Any(), s2).Return(&hcloud.ServerDeleteResult{}, nil, nil)
	assert.ErrorIs(t, reap(t, r), reaper.ErrDeleteFailed)
}

func TestReap_Pagination(t *testing.T) {
	r, client := setup(t)
	p1 := []*hcloud.Server{serverWithAge(1, maxAge*2), serverWithAge(2, maxAge*2)}
	p2 := []*hcloud.Server{serverWithAge(3, maxAge*2)}
	expectPages(client, p1, p2)
	for _, s := range append(p1, p2...) {
		client.EXPECT().DeleteWithResult(gomock.Any(), s).Return(&hcloud.ServerDeleteResult{}, nil, nil)
	}
	require.NoError(t, reap(t, r))
}
