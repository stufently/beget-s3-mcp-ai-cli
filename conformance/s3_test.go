//go:build conformance

package conformance

import (
	"github.com/stufently/beget-s3-mcp-ai-cli/internal/provider"
	"github.com/stufently/s3-mcp-ai-cli-kit/conformance"
	"testing"
)

func TestS3(t *testing.T) {
	p, e := provider.Load()
	if e != nil {
		t.Fatal(e)
	}
	conformance.RunS3(t, p)
}
func TestMCP(t *testing.T) {
	p, e := provider.Load()
	if e != nil {
		t.Fatal(e)
	}
	conformance.RunMCP(t, p)
}
func TestCLI(t *testing.T) {
	p, e := provider.Load()
	if e != nil {
		t.Fatal(e)
	}
	conformance.RunCLI(t, p)
}
