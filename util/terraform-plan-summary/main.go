package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

type row struct {
	action  string
	address string
}

type planJSON struct {
	ResourceChanges []resourceChange `json:"resource_changes"`
}

type resourceChange struct {
	Address string `json:"address"`
	Change  change `json:"change"`
}

type change struct {
	Actions []string `json:"actions"`
}

func actionLabel(actions []string) (string, bool) {
	switch strings.Join(actions, ",") {
	case "create":
		return "create", true
	case "update":
		return "update", true
	case "delete":
		return "delete", true
	case "delete,create", "create,delete":
		return "replace", true
	default:
		return "", false
	}
}

func parsePlan(r io.Reader) ([]row, error) {
	var plan planJSON
	if err := json.NewDecoder(r).Decode(&plan); err != nil {
		return nil, err
	}
	var rows []row
	for _, rc := range plan.ResourceChanges {
		label, ok := actionLabel(rc.Change.Actions)
		if !ok {
			continue
		}
		rows = append(rows, row{action: label, address: rc.Address})
	}
	return rows, nil
}

func writeTable(w io.Writer, rows []row) {
	if len(rows) == 0 {
		fmt.Fprintln(w, "_No changes._")
		return
	}
	fmt.Fprintln(w, "| Action | Resource |")
	fmt.Fprintln(w, "|--------|----------|")
	for _, r := range rows {
		fmt.Fprintf(w, "| %s | %s |\n", r.action, r.address)
	}
}

func main() {
	rows, err := parsePlan(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error parsing plan JSON: %v\n", err)
		os.Exit(1)
	}
	writeTable(os.Stdout, rows)
}
