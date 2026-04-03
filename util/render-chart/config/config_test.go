package config_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/fergalhk-lab/core-infrastructure/util/render-chart/config"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func writeConfig(t *testing.T, name, content string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	require.NoError(t, os.WriteFile(path, []byte(content), 0o644))
	return path
}

func TestParseConfig_Valid(t *testing.T) {
	path := writeConfig(t, "my-release.yaml", `
name: my-release
namespace: default
chart:
  source: https://charts.example.com
  version: 1.2.3
  name: example-chart
values:
  replicaCount: 2
  image:
    tag: latest
`)
	cfg, err := config.ParseConfig(path)
	require.NoError(t, err)
	assert.Equal(t, "my-release", cfg.Name)
	assert.Equal(t, "default", cfg.Namespace)
	assert.Equal(t, "https://charts.example.com", cfg.Chart.Source)
	assert.Equal(t, "1.2.3", cfg.Chart.Version)
	assert.Equal(t, "example-chart", cfg.Chart.Name)
	assert.Equal(t, map[string]any{"replicaCount": float64(2), "image": map[string]any{"tag": "latest"}}, cfg.Values)
}

func TestParseConfig_ChartNameFallback(t *testing.T) {
	path := writeConfig(t, "my-release.yaml", `
name: my-release
namespace: default
chart:
  source: https://charts.example.com
  version: 1.2.3
`)
	cfg, err := config.ParseConfig(path)
	require.NoError(t, err)
	assert.Equal(t, "my-release", cfg.ChartName())
	assert.Empty(t, cfg.Chart.Name)
}

func TestParseConfig_NoValues(t *testing.T) {
	path := writeConfig(t, "my-release.yaml", `
name: my-release
namespace: default
chart:
  source: https://charts.example.com
  version: 1.2.3
  name: example-chart
`)
	cfg, err := config.ParseConfig(path)
	require.NoError(t, err)
	assert.Nil(t, cfg.Values)
}

func TestParseConfig_FilenameMismatch(t *testing.T) {
	path := writeConfig(t, "wrong-name.yaml", `
name: my-release
namespace: default
chart:
  source: https://charts.example.com
  version: 1.2.3
  name: example-chart
`)
	_, err := config.ParseConfig(path)
	require.Error(t, err)
	assert.ErrorIs(t, err, config.ErrFilenameMismatch)
}

func TestParseConfig_MissingFile(t *testing.T) {
	_, err := config.ParseConfig("/nonexistent/path/foo.yaml")
	require.Error(t, err)
}

func TestParseConfig_MissingRequiredFields(t *testing.T) {
	path := writeConfig(t, "my-release.yaml", `
name: my-release
namespace: default
chart:
  source: https://charts.example.com
`)
	_, err := config.ParseConfig(path)
	require.Error(t, err)
	assert.Contains(t, err.Error(), "missing required fields")
}
