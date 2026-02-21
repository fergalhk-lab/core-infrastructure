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

func TestGenerate_NoChangedFiles_ReturnsAllModules(t *testing.T) {
	entries, err := matrix.Generate(testConfig, nil)
	require.NoError(t, err)
	assert.Len(t, entries, 3)
}

func TestGenerate_ChangedFileUnderModule_ReturnsOnlyThatModule(t *testing.T) {
	entries, err := matrix.Generate(testConfig, []string{"infra/networking/main.tf"})
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "infra/networking", entries[0].Dir)
}

func TestGenerate_ChangedFileMatchesMultipleModules(t *testing.T) {
	entries, err := matrix.Generate(testConfig, []string{"infra/networking/main.tf", "infra/dns/zones.tf"})
	require.NoError(t, err)
	assert.Len(t, entries, 2)
}

func TestGenerate_ChangedFileMatchesNoModule_ReturnsEmpty(t *testing.T) {
	entries, err := matrix.Generate(testConfig, []string{"untracked/file.tf"})
	require.NoError(t, err)
	assert.Empty(t, entries)
}

func TestGenerate_AWSModule_PopulatesCredentials(t *testing.T) {
	entries, err := matrix.Generate(testConfig, []string{"infra/networking/main.tf"})
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Equal(t, "arn:aws:iam::123456789012:role/github", entries[0].RoleARN)
	assert.Equal(t, "eu-west-1", entries[0].AWSRegion)
}

func TestGenerate_NonAWSModule_OmitsCredentials(t *testing.T) {
	entries, err := matrix.Generate(testConfig, []string{"edge/cloudflare/main.tf"})
	require.NoError(t, err)
	require.Len(t, entries, 1)
	assert.Empty(t, entries[0].RoleARN)
	assert.Empty(t, entries[0].AWSRegion)
}

func TestGenerate_UnknownAccount_ReturnsError(t *testing.T) {
	cfg := config.Config{
		AWSAccounts: map[string]config.AWSAccount{},
		Modules: []config.Module{
			{Path: "infra/networking", AWS: &config.ModuleAWS{Account: "nonexistent", Region: "eu-west-1"}},
		},
	}
	_, err := matrix.Generate(cfg, nil)
	require.Error(t, err)
}

func TestGenerate_DoesNotMatchPathPrefix(t *testing.T) {
	// "infra/networking-extra/main.tf" must not match the "infra/networking" module
	entries, err := matrix.Generate(testConfig, []string{"infra/networking-extra/main.tf"})
	require.NoError(t, err)
	assert.Empty(t, entries)
}
