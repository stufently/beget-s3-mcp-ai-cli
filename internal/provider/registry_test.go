package provider

import (
	"encoding/json"
	"github.com/google/jsonschema-go/jsonschema"
	"os"
	"testing"
)

func TestRegistrySchema(t *testing.T) {
	raw, e := os.ReadFile("../../testdata/server.schema.json")
	if e != nil {
		t.Fatal(e)
	}
	var schema jsonschema.Schema
	if e = json.Unmarshal(raw, &schema); e != nil {
		t.Fatal(e)
	}
	resolved, e := schema.Resolve(nil)
	if e != nil {
		t.Fatal(e)
	}
	data, e := os.ReadFile("../../server.json")
	if e != nil {
		t.Fatal(e)
	}
	var manifest map[string]any
	if e = json.Unmarshal(data, &manifest); e != nil {
		t.Fatal(e)
	}
	if e = resolved.Validate(manifest); e != nil {
		t.Fatal(e)
	}
	invalid := map[string]any{"name": "bad", "version": "0.1.0"}
	if e = resolved.Validate(invalid); e == nil {
		t.Fatal("schema validation failed to enforce required properties")
	}
}
