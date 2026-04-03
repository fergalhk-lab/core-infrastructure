package config

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

var ErrFilenameMismatch = errors.New("filename does not match release name")

type Config struct {
	Name      string         `yaml:"name"`
	Namespace string         `yaml:"namespace"`
	Chart     ChartConfig    `yaml:"chart"`
	Values    map[string]any `yaml:"values"`
}

type ChartConfig struct {
	Source  string `yaml:"source"`
	Version string `yaml:"version"`
	Name    string `yaml:"name"`
}

// ChartName returns the chart name, falling back to the release name if not set.
func (c *Config) ChartName() string {
	if c.Chart.Name != "" {
		return c.Chart.Name
	}
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

	if cfg.Name == "" || cfg.Namespace == "" || cfg.Chart.Source == "" || cfg.Chart.Version == "" {
		return nil, fmt.Errorf("config missing required fields: name, namespace, chart.source, and chart.version must all be set")
	}

	filename := strings.TrimSuffix(filepath.Base(path), ".yaml")
	if filename != cfg.Name {
		return nil, fmt.Errorf("%w: got %q, expected %q", ErrFilenameMismatch, filename, cfg.Name)
	}

	return &cfg, nil
}
