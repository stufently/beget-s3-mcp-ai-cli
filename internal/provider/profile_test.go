package provider

import (
	"net/url"
	"strings"
	"testing"
)

func TestProfile(t *testing.T) {
	p, e := Load()
	if e != nil {
		t.Fatal(e)
	}
	if p.ID != "beget" || p.Binary != "beget-s3" || p.EnvPrefix != "BEGET_S3_" || p.URIScheme != "beget-s3" {
		t.Fatalf("provider identity: %+v", p)
	}
	found := false
	for _, pool := range p.Pools {
		u, e := url.Parse(pool.Endpoint)
		if e != nil || u.Scheme != "https" || u.Hostname() == "" {
			t.Fatalf("pool endpoint %s: %v", pool.ID, e)
		}
		if pool.ID == p.DefaultPool {
			found = true
		}
	}
	if !found || len(p.DocsURLs) == 0 || p.PresignMaxSeconds < 1 || p.Verified {
		t.Fatal("unverified profile metadata missing")
	}
	for _, source := range p.DocsURLs {
		if !strings.HasPrefix(source, "https://") {
			t.Fatalf("documentation source: %s", source)
		}
	}
}
