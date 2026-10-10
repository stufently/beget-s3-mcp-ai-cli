package main

import (
	"errors"
	"fmt"
	"github.com/stufently/beget-s3-mcp-ai-cli/internal/provider"
	"github.com/stufently/s3-mcp-ai-cli-kit/cli"
	"os"
)

var version = "0.1.0"
var commit = "dev"

func main() {
	p, e := provider.Load()
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
	if e = cli.New(p, version, commit).Execute(); e != nil {
		fmt.Fprintln(os.Stderr, e)
		var exit *cli.ExitError
		if errors.As(e, &exit) {
			os.Exit(exit.Code)
		}
		os.Exit(1)
	}
}
