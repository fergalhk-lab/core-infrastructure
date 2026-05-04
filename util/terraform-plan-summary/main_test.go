package main

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestParsePlan(t *testing.T) {
	input := `{
		"resource_changes": [
			{"address": "aws_s3_bucket.example",                            "change": {"actions": ["create"]}},
			{"address": "module.foo.aws_instance.bar",                      "change": {"actions": ["delete"]}},
			{"address": "module.platform.aws_iam_role.worker",              "change": {"actions": ["update"]}},
			{"address": "module.k3s.hcloud_server.node[\"control-0\"]",    "change": {"actions": ["delete", "create"]}},
			{"address": "module.k3s.hcloud_server.node[\"control-1\"]",    "change": {"actions": ["create", "delete"]}},
			{"address": "data.aws_ami.ubuntu",                              "change": {"actions": ["read"]}},
			{"address": "module.unchanged.aws_s3_bucket.logs",              "change": {"actions": ["no-op"]}}
		]
	}`

	rows, err := parsePlan(strings.NewReader(input))
	require.NoError(t, err)
	assert.Equal(t, []row{
		{action: "create", address: "aws_s3_bucket.example"},
		{action: "delete", address: "module.foo.aws_instance.bar"},
		{action: "update", address: "module.platform.aws_iam_role.worker"},
		{action: "replace", address: `module.k3s.hcloud_server.node["control-0"]`},
		{action: "replace", address: `module.k3s.hcloud_server.node["control-1"]`},
	}, rows)
}

func TestParsePlan_Empty(t *testing.T) {
	input := `{"resource_changes": []}`
	rows, err := parsePlan(strings.NewReader(input))
	require.NoError(t, err)
	assert.Empty(t, rows)
}

func TestParsePlan_AllNoOp(t *testing.T) {
	input := `{
		"resource_changes": [
			{"address": "aws_s3_bucket.example", "change": {"actions": ["no-op"]}},
			{"address": "data.aws_ami.ubuntu",   "change": {"actions": ["read"]}}
		]
	}`
	rows, err := parsePlan(strings.NewReader(input))
	require.NoError(t, err)
	assert.Empty(t, rows)
}

func TestWriteTable_WithChanges(t *testing.T) {
	rows := []row{
		{action: "create", address: "aws_s3_bucket.example"},
		{action: "delete", address: "module.foo.aws_instance.bar"},
		{action: "replace", address: `module.k3s.hcloud_server.node["control-0"]`},
	}
	var buf strings.Builder
	writeTable(&buf, rows)
	assert.Equal(t,
		"| Action | Resource |\n"+
			"|--------|----------|\n"+
			"| create | aws_s3_bucket.example |\n"+
			"| delete | module.foo.aws_instance.bar |\n"+
			"| replace | module.k3s.hcloud_server.node[\"control-0\"] |\n",
		buf.String(),
	)
}

func TestWriteTable_NoChanges(t *testing.T) {
	var buf strings.Builder
	writeTable(&buf, nil)
	assert.Equal(t, "_No changes._\n", buf.String())
}

func TestWriteTable_EmptySlice(t *testing.T) {
	var buf strings.Builder
	writeTable(&buf, []row{})
	assert.Equal(t, "_No changes._\n", buf.String())
}

func TestParsePlan_InvalidJSON(t *testing.T) {
	_, err := parsePlan(strings.NewReader("not valid json"))
	require.Error(t, err)
}
