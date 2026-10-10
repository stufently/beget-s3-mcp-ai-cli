// Package provider embeds the Beget profile; shared behavior lives in the kit.
package provider

import (
	_ "embed"
	"github.com/stufently/s3-mcp-ai-cli-kit/provider"
)

//go:embed profile.yaml
var data []byte

func Load() (provider.Profile, error) { return provider.Load(data) }
