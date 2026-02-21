package config

type (
	Config struct {
		AWSAccounts map[string]AWSAccount `yaml:"awsAccounts"`
		Modules     []Module              `yaml:"modules"`
	}

	AWSAccount struct {
		RoleARN string `yaml:"roleARN"`
	}

	Module struct {
		Path string     `yaml:"path"`
		AWS  *ModuleAWS `yaml:"aws"`
	}

	ModuleAWS struct {
		Account string `yaml:"account"`
		Region  string `yaml:"region"`
	}
)
