package renderer

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/fergalhk-lab/core-infrastructure/util/render-chart/config"
	"sigs.k8s.io/yaml"
)

// Render writes the config values to a temp file and runs helm template.
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

	log.Printf(">>> Rendering %s version %s as release %q in namespace %q",
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
