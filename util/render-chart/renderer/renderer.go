package renderer

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
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

	filename := strings.TrimSuffix(filepath.Base(path), ".yaml")
	if filename != cfg.Name {
		return nil, fmt.Errorf("%w: got %q, expected %q", ErrFilenameMismatch, filename, cfg.Name)
	}

	return &cfg, nil
}

// Render writes the config values to a temp file and runs helm template.
func Render(cfg *Config) error {
	var valuesYAML []byte
	if cfg.Values == nil {
		valuesYAML = []byte("{}\n")
	} else {
		var err error
		valuesYAML, err = yaml.Marshal(cfg.Values)
		if err != nil {
			return fmt.Errorf("marshaling values: %w", err)
		}
	}

	tmp, createErr := os.CreateTemp("", "render-chart-values-*.yaml")
	if createErr != nil {
		return fmt.Errorf("creating temp file: %w", createErr)
	}
	defer os.Remove(tmp.Name())
	defer tmp.Close()

	if _, err := tmp.Write(valuesYAML); err != nil {
		return fmt.Errorf("writing values: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("closing temp file: %w", err)
	}

	fmt.Fprintf(os.Stderr, ">>> Rendering %s version %s as release %q in namespace %q\n",
		cfg.ChartName(), cfg.Chart.Version, cfg.Name, cfg.Namespace)

	cmd := exec.Command("helm", "template", cfg.Name, cfg.ChartName(),
		"--repo", cfg.Chart.Source,
		"--namespace", cfg.Namespace,
		"--version", cfg.Chart.Version,
		"--values", tmp.Name(),
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("helm template: %w", err)
	}
	return nil
}
