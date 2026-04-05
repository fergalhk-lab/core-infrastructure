package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"sigs.k8s.io/yaml"
)

var ErrFilenameMismatch = errors.New("filename does not match release name")

type Config struct {
	Name         string           `json:"name"`
	Chart        ChartConfig      `json:"chart"`
	Values       map[string]any   `json:"values"`
	ExtraObjects []map[string]any `json:"extraObjects"`
	// ConfigDir is the directory containing the config file; set by ParseConfig.
	ConfigDir string `json:"-"`
}

type ChartConfig struct {
	Source  string `json:"source"`
	Version string `json:"version"`
	Name    string `json:"name"`
}

// IsLocal reports whether the chart source is a local filesystem path rather
// than a remote Helm repository URL.
func (c *ChartConfig) IsLocal() bool {
	return !strings.HasPrefix(c.Source, "http://") && !strings.HasPrefix(c.Source, "https://")
}

// ChartName returns the chart name, falling back to the release name if not set.
func (c *Config) ChartName() string {
	if c.Chart.Name != "" {
		return c.Chart.Name
	}
	return c.Name
}

func (c *Config) Namespace() string {
	return c.Name
}

// ParseConfig reads and validates the config file at path.
func ParseConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("reading config: %w", err)
	}

	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("parsing config: %w", err)
	}

	if cfg.Name == "" || cfg.Chart.Source == "" {
		return nil, fmt.Errorf("config missing required fields: name and chart.source must be set")
	}
	if !cfg.Chart.IsLocal() && cfg.Chart.Version == "" {
		return nil, fmt.Errorf("config missing required fields: chart.version must be set for remote charts")
	}

	filename := strings.TrimSuffix(filepath.Base(path), ".yaml")
	if filename != cfg.Name {
		return nil, fmt.Errorf("%w: got %q, expected %q", ErrFilenameMismatch, filename, cfg.Name)
	}

	cfg.ConfigDir = filepath.Dir(path)
	return &cfg, nil
}
