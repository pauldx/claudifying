---
name: cf-graphify
description: When the user asks to graphify an OpenAPI spec, build a knowledge graph from API specs, analyze API structure for token optimization, or visualize API relationships — activate this skill for OpenAPI-to-graph conversion with gap analysis
---

# Graphify OpenAPI Spec

Convert OpenAPI YAML specs into navigable knowledge graphs for fast traversal, token optimization, and API gap analysis.

## Activation

- "Graphify this API spec"
- "Build knowledge graph from openapi spec"
- "Analyze API structure for token savings"
- "Find gaps in API spec"
- "/cf-graphify"

## Why

LLM agents querying raw OpenAPI specs burn ~145k input tokens + ~4k output tokens per question. A pre-built graph reduces this to ~8k input + ~500 output (95% savings). Output tokens cost 5x more than input — graph eliminates expensive reasoning tokens by pre-computing relationships.

Break-even: ~7 queries on a typical public spec.

## Prerequisites

- `graphifyy` Python package installed (`uv tool install graphifyy` or `pip install graphifyy`)
- `pyyaml` in same Python env as graphify
- OpenAPI spec in YAML format

## Process

### Step 1 — Compress OpenAPI YAML to Graph-Friendly Markdown

Raw YAML is too large and not supported by graphify's detector. Compress first.

**Use the bundled compressor** (`compress_openapi.py`). If not present, create it:

```python
#!/usr/bin/env python3
"""Compress OpenAPI YAML specs into graph-friendly markdown files."""
import yaml, sys, re
from pathlib import Path
from collections import defaultdict

def extract_refs(obj, refs=None):
    if refs is None: refs = set()
    if isinstance(obj, dict):
        if '$ref' in obj:
            ref = obj['$ref']
            if ref.startswith('#/components/schemas/'):
                refs.add(ref.replace('#/components/schemas/', ''))
        for v in obj.values(): extract_refs(v, refs)
    elif isinstance(obj, list):
        for item in obj: extract_refs(item, refs)
    return refs

def compress_spec(yaml_path, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    with open(yaml_path) as f:
        spec = yaml.safe_load(f)

    domain_paths = defaultdict(list)
    for path, methods in spec.get('paths', {}).items():
        domain = re.match(r'^/([a-z-]+)', path).group(1) if re.match(r'^/([a-z-]+)', path) else 'other'
        for method, details in methods.items():
            if method in ['get', 'post', 'put', 'delete', 'patch']:
                domain_paths[domain].append((path, method, details))

    for domain, paths in domain_paths.items():
        lines = [f"# {domain.upper()} API Endpoints\n"]
        for path, method, details in paths:
            summary = details.get('summary', details.get('operationId', ''))
            refs = extract_refs(details.get('requestBody', {})) | extract_refs(details.get('responses', {}))
            lines.append(f"\n## {method.upper()} {path}\nsummary: {summary}\n")
            if refs: lines.append(f"refs: {', '.join(sorted(refs))}\n")
        (out_dir / f"paths_{domain}.md").write_text('\n'.join(lines))

    schemas = spec.get('components', {}).get('schemas', {})
    schema_groups = defaultdict(list)
    for name, defn in schemas.items():
        prefix = name.split('-')[0] if '-' in name else name
        schema_groups[prefix].append((name, defn))

    for prefix, schemas_list in schema_groups.items():
        lines = [f"# {prefix.upper()} Schemas\n"]
        for name, defn in schemas_list:
            props = list(defn.get('properties', {}).keys())[:10]
            refs = extract_refs(defn)
            lines.append(f"\n## {name}\n")
            if props: lines.append(f"fields: {', '.join(props)}\n")
            if refs: lines.append(f"refs: {', '.join(sorted(refs))}\n")
        (out_dir / f"schemas_{prefix}.md").write_text('\n'.join(lines))

if __name__ == '__main__':
    compress_spec(sys.argv[1], sys.argv[2])
```

Run:
```bash
GPYTHON=$(cat graphify-out/.graphify_python 2>/dev/null || echo python3)
$GPYTHON compress_openapi.py <spec>.yaml graphify-staging
```

### Step 2 — Run Graphify on Staged Markdown

```bash
/graphify graphify-staging
```

This runs the full graphify pipeline: detect → extract → cluster → label → viz.

**Model guidance**: Run entire pipeline on **Sonnet**. No model switch needed. Community labeling works fine with auto-labeling by word frequency. Save Opus for exploration/querying phase.

### Step 3 — Post-Build: Normalize IDs and Fix Duplicates

OpenAPI compression creates dual-format IDs (`schema_field_value` vs `schema-field-value`). After graphify completes, run normalization:

```python
import json, re
from networkx.readwrite import json_graph
import networkx as nx
from pathlib import Path

data = json.loads(Path('graphify-out/graph.json').read_text())
G = json_graph.node_link_graph(data, edges='links')

def canonicalize(nid):
    n = re.sub(r'^schemas_[a-z]+_', '', nid)
    n = re.sub(r'^paths_', '', n)
    n = n.replace('_', '-')
    n = re.sub(r'-+', '-', n).strip('-')
    return n

# Merge duplicates
canonical_map = {}
for node in list(G.nodes()):
    canonical_map.setdefault(canonicalize(node), []).append(node)

for canon, variants in canonical_map.items():
    if len(variants) <= 1: continue
    variants.sort(key=lambda n: G.degree(n), reverse=True)
    primary = variants[0]
    for secondary in variants[1:]:
        if secondary not in G: continue
        for neighbor in list(G.neighbors(secondary)):
            if neighbor != primary and not G.has_edge(primary, neighbor):
                G.add_edge(primary, neighbor, **dict(G.edges[secondary, neighbor]))
        G.remove_node(secondary)

# Rename remaining underscore nodes
renames = {n: canonicalize(n) for n in list(G.nodes()) if canonicalize(n) != n and canonicalize(n) not in G}
G = nx.relabel_nodes(G, renames)

# Wire orphans to domain hubs
for orphan in [n for n in G.nodes() if G.degree(n) == 0]:
    for suffix in ['-request', '-response']:
        if orphan.endswith(suffix):
            base = orphan[:-len(suffix)]
            if base in G and G.degree(base) > 0:
                G.add_edge(orphan, base, relation='request_response_for', confidence='INFERRED', confidence_score=0.9)
                break
    else:
        domain = orphan.split('-')[0]
        candidates = [n for n in G.nodes() if n.startswith(domain) and G.degree(n) > 0]
        if candidates:
            orphan_words = set(orphan.split('-'))
            best = max(candidates, key=lambda c: len(orphan_words & set(c.split('-'))))
            if len(orphan_words & set(best.split('-'))) >= 2:
                G.add_edge(orphan, best, relation='belongs_to_domain', confidence='INFERRED', confidence_score=0.7)
```

### Step 4 — Analyze Gaps

After normalization, identify isolated clusters:

```python
components = sorted(nx.connected_components(G), key=len, reverse=True)
main = components[0]
islands = [c for c in components[1:] if len(c) > 1]
```

Report each island: nodes, domain, what it should connect to in main component.

### Step 5 — Explore

Open `graphify-out/graph.html` in browser. Use `/graphify query` for traversal queries.

## Expected Results

| Metric | Typical Public Spec | Typical Internal Spec |
|---|---|---|
| Endpoints | ~212 | ~1120 |
| Graph nodes | ~1,200-1,400 | ~6,000-8,000 |
| Graph edges | ~1,500-2,000 | ~8,000-12,000 |
| Communities | ~50-70 | ~200-400 |
| Main component | 90%+ | 85%+ |
| Build cost | ~$1.60 | ~$8-12 |
| Break-even | ~7 queries | ~3 queries |

## Token Economics

| Scenario (per query) | Without Graph | With Graph | Savings |
|---|---|---|---|
| Input tokens | 145k | 8k | 95% |
| Output tokens | 4k | 500 | 87% |
| Cost (Sonnet) | $0.50 | $0.03 | 94% |

Output tokens cost 5x more than input. Graph eliminates reasoning tokens (pre-computed edges) — the most expensive token class.

### 3-Layer Stack for Maximum Savings

```
Layer 1: Caveman     → compress LANGUAGE    (~75% output reduction, free)
Layer 2: Graph       → compress REASONING   (~87% output reduction, one-time build)
Layer 3: Memory      → compress CONTEXT     (~97% input reduction, accumulates)
Combined: 98-99% total token reduction
```

## Gotchas

- **YAML with exotic tags**: Internal specs may have unquoted `<` or `<=` in enum values. Use `yaml.unsafe_load()` or pre-sanitize.
- **Dual ID format**: Compressor produces `schema_field_value` IDs, LLM agents produce `schema-field-value`. Always run normalization (Step 3).
- **Subagent token limits**: Chunks with many schemas may exceed 32k output limit. Fall back to direct Python extraction for those chunks (zero LLM cost).
- **Singleton communities**: OpenAPI specs produce many leaf schemas. 459 singletons is normal pre-normalization — drops to <10 after.
- **Error schemas**: Every API returns error types but specs rarely cross-reference them. Expect `error-*` schemas as an isolated island.
- **Request/Response split**: OpenAPI connects request↔response at path level, not schema level. Graph exposes this as islands — bridge with inferred edges.
