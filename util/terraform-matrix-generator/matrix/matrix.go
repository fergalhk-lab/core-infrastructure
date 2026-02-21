package matrix

import (
	"fmt"

	"github.com/fergalhk-lab/core-infrastructure/util/terraform-matrix-generator/config"
)

type Entry struct {
	Dir       string `json:"dir"`
	RoleARN   string `json:"roleARN,omitempty"`
	AWSRegion string `json:"awsRegion,omitempty"`
}

// Generate returns a matrix entry for each module in cfg.
func Generate(cfg config.Config) ([]Entry, error) {
	entries := make([]Entry, 0)

	for _, module := range cfg.Modules {
		entry := Entry{Dir: module.Path}

		if module.AWS != nil {
			account, ok := cfg.AWSAccounts[module.AWS.Account]
			if !ok {
				return nil, fmt.Errorf("module %q references unknown AWS account %q", module.Path, module.AWS.Account)
			}
			entry.RoleARN = account.RoleARN
			entry.AWSRegion = module.AWS.Region
		}

		entries = append(entries, entry)
	}

	return entries, nil
}
