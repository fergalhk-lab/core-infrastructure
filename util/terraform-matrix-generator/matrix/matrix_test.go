package matrix_test

import (
	"testing"

	"github.com/fergalhk-lab/core-infrastructure/util/terraform-matrix-generator/config"
	"github.com/fergalhk-lab/core-infrastructure/util/terraform-matrix-generator/matrix"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var testConfig = config.Config{
	AWSAccounts: map[string]config.AWSAccount{
		"platform": {RoleARN: "arn:aws:iam::123456789012:role/github"},
	},
	Modules: []config.Module{
		{
			Path: "infra/networking",
			AWS:  &config.ModuleAWS{Account: "platform", Region: "eu-west-1"},
		},
		{
			Path: "infra/dns",
			AWS:  &config.ModuleAWS{Account: "platform", Region: "us-east-1"},
		},
		{
			Path: "edge/cloudflare",
			AWS:  nil,
		},
	},
}

func TestGenerate(t *testing.T) {
	entries, err := matrix.Generate(testConfig)
	require.NoError(t, err)
	assert.Equal(t, []matrix.Entry{
		{Dir: "infra/networking", RoleARN: "arn:aws:iam::123456789012:role/github", AWSRegion: "eu-west-1"},
		{Dir: "infra/dns", RoleARN: "arn:aws:iam::123456789012:role/github", AWSRegion: "us-east-1"},
		{Dir: "edge/cloudflare"},
	}, entries)
}

func TestGenerate_UnknownAccount_ReturnsError(t *testing.T) {
	cfg := config.Config{
		AWSAccounts: map[string]config.AWSAccount{},
		Modules: []config.Module{
			{Path: "infra/networking", AWS: &config.ModuleAWS{Account: "nonexistent", Region: "eu-west-1"}},
		},
	}
	_, err := matrix.Generate(cfg)
	require.Error(t, err)
}
