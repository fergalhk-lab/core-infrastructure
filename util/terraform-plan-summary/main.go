package main

import (
	"io"
)

type row struct {
	action  string
	address string
}

func parsePlan(r io.Reader) ([]row, error) {
	panic("not implemented")
}

func writeTable(w io.Writer, rows []row) {
	panic("not implemented")
}

func main() {}
