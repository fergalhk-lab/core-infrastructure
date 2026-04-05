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
}

type ChartConfig struct {
	Source  string `json:"source"`
	Version string `json:"version"`
	Name    string `json:"name"`
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

	if cfg.Name == "" || cfg.Chart.Source == "" || cfg.Chart.Version == "" {
		return nil, fmt.Errorf("config missing required fields: name, namespace, chart.source, and chart.version must all be set")
	}

	filename := strings.TrimSuffix(filepath.Base(path), ".yaml")
	if filename != cfg.Name {
		return nil, fmt.Errorf("%w: got %q, expected %q", ErrFilenameMismatch, filename, cfg.Name)
	}

	return &cfg, nil
}
