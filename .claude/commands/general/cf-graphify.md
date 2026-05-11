---
description: Convert any folder to knowledge graph - install graphify, build interactive visualization, generate audit report
---

# cf-graphify

Turn any codebase, corpus, or folder into a navigable knowledge graph. Auto-installs graphify, extracts entities and relationships, detects communities, generates interactive HTML + Obsidian vault.

## Usage

```
/cf-graphify                       # build graph on current directory (.)
/cf-graphify <path>               # build graph on specific path
/cf-graphify https://github.com/<owner>/<repo>  # clone repo, build graph
/cf-graphify <path> --mode deep   # thorough extraction, richer inferred edges
/cf-graphify <path> --update      # incremental re-extraction (new/changed files only)
/cf-graphify <path> --obsidian    # generate Obsidian vault
/cf-graphify <path> --no-viz      # skip HTML visualization
/cf-graphify <path> --watch       # auto-rebuild on file changes
/cf-graphify query "<question>"   # query the graph (BFS)
/cf-graphify query "<question>" --dfs  # query with DFS traversal
/cf-graphify path "NodeA" "NodeB"      # shortest path between concepts
/cf-graphify explain "ConceptName"     # explain a node and its connections
```

## What it does

1. **Detects files** - scans for code, docs, papers, images, video
2. **Extracts relationships** - AST for code, LLM for semantic relationships
3. **Clusters** - detects communities of related concepts
4. **Generates outputs** - interactive HTML graph + GRAPH_REPORT.md + graph.json
5. **Saves state** - incremental updates skip re-extraction if files haven't changed

## Outputs

All outputs saved to `graphify-out/`:
- `graph.html` - interactive visualization (open in browser)
- `GRAPH_REPORT.md` - audit report with god nodes and surprising connections
- `graph.json` - raw graph data (JSON)
- `obsidian/` - Obsidian vault (if `--obsidian` flag given)
- `cost.json` - token usage tracking

## Example workflow

```bash
# 1. Build initial graph
/cf-graphify ~/my-project

# 2. Query the graph
/cf-graphify query "How does authentication work?"

# 3. Find paths between concepts
/cf-graphify path "LoginHandler" "Database"

# 4. After editing code, incrementally update
/cf-graphify ~/my-project --update

# 5. Watch for changes (auto-rebuild on code changes)
/cf-graphify ~/my-project --watch
```

## Implementation

This command installs graphify if needed, then invokes the `/graphify` skill with the provided arguments and flags. All graphify features (detection, extraction, clustering, visualization, querying, path-finding) are available.

**Note:** Large corpora (>200 files) may take 2-5 minutes. The graph saves state so subsequent `--update` runs are fast.
