package renderer

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/fergalhk-lab/core-infrastructure/util/render-chart/config"
	"sigs.k8s.io/yaml"
)

// Render writes the config values to a temp file, runs helm template, then
// appends any top-level extraObjects as additional YAML documents.
func Render(cfg *config.Config) error {
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

	if _, err := tmp.Write(valuesYAML); err != nil {
		return fmt.Errorf("writing values: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return fmt.Errorf("closing temp file: %w", err)
	}

	chart := cfg.ChartName()
	var repoArgs []string
	var workDir string
	if cfg.Chart.IsLocal() {
		log.Printf(">>> Rendering local chart %s as release %q in namespace %q",
			cfg.Chart.Source, cfg.Name, cfg.Namespace())
		chart = cfg.Chart.Source
		workDir = cfg.ConfigDir
	} else {
		log.Printf(">>> Rendering %s version %s as release %q in namespace %q",
			cfg.ChartName(), cfg.Chart.Version, cfg.Name, cfg.Namespace())
		repoArgs = []string{"--repo", cfg.Chart.Source, "--version", cfg.Chart.Version}
	}

	args := append([]string{"template", cfg.Name, chart,
		"--namespace", cfg.Namespace(),
		"--include-crds",
		"--values", tmp.Name(),
	}, repoArgs...)

	cmd := exec.Command("helm", args...)
	cmd.Dir = workDir
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("helm template: %w", err)
	}

	for _, obj := range cfg.ExtraObjects {
		data, err := yaml.Marshal(obj)
		if err != nil {
			return fmt.Errorf("marshaling extra object: %w", err)
		}
		if _, err := fmt.Fprint(os.Stdout, "---\n"); err != nil {
			return fmt.Errorf("writing extra object separator: %w", err)
		}
		if _, err := os.Stdout.Write(data); err != nil {
			return fmt.Errorf("writing extra object: %w", err)
		}
	}

	return nil
}
