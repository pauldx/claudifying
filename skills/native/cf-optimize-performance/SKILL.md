---
name: cf-optimize-performance
description: When the user asks to optimize build performance, speed up compilation, reduce bundle size, improve API response time, or implement caching — activate this performance optimization skill
---

# Performance Optimization

Multi-domain performance optimization that profiles first, identifies bottlenecks, and suggests fixes ranked by impact-to-effort ratio. Never guess — always measure before recommending.

## Activation

- User says "speed up builds", "reduce bundle size", "optimize API", "improve performance"
- User reports slow compilation, large bundles, or sluggish endpoints
- User wants caching strategy, code splitting, or query optimization

## Domains

### Build Optimization

Analyze the build toolchain and identify slow steps:

```bash
# Measure current build time
time npm run build 2>&1

# Check bundle output sizes
ls -lh dist/ build/ .next/ 2>/dev/null
```

Areas to investigate:
- **Webpack**: Check for missing `cache` config, unoptimized loaders, lack of `thread-loader`
- **Vite**: Verify pre-bundling config, check for unnecessary full-page reloads in dev
- **esbuild/SWC**: Ensure transpile-only mode, no redundant transforms
- **General**: Code splitting opportunities, tree shaking failures, duplicate dependencies

### Bundle Analysis

Run the appropriate analyzer for the project's bundler:

```bash
# Webpack projects
npx webpack-bundle-analyzer dist/stats.json

# Vite projects
npx vite-bundle-visualizer

# Next.js
ANALYZE=true npm run build
```

Identify: oversized dependencies, duplicate packages, unshaken imports, missing dynamic imports.

### API Optimization

Profile endpoint response times and identify bottlenecks:

- **Caching strategies**: HTTP cache headers (ETag, Cache-Control), Redis/Memcached for hot data, in-memory LRU for computed values
- **N+1 queries**: Spot patterns where a list fetch triggers individual fetches per item — suggest batching or eager loading
- **Payload size**: Identify over-fetching, suggest field selection or pagination
- **Concurrency**: Find sequential calls that can be parallelized with `Promise.all`

### Database Query Optimization

Identify and fix slow queries:

```bash
# PostgreSQL: find slow queries
EXPLAIN ANALYZE SELECT ...;

# Check missing indexes
SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
```

Focus areas: missing indexes, full table scans, inefficient joins, unneeded `SELECT *`, missing pagination.

## Process

### 1. Profile

Measure current performance to establish a baseline:

- Build time (`time npm run build`)
- Bundle size (`du -sh dist/`)
- API response time (representative endpoints)
- Identify the specific metric the user cares about

### 2. Identify Bottlenecks

Rank issues by impact:

| Issue | Impact | Effort | Priority |
|-------|--------|--------|----------|
| Missing code splitting | High | Low | P0 |
| N+1 query in /api/users | High | Medium | P0 |
| Large moment.js import | Medium | Low | P1 |

### 3. Recommend Fixes

For each bottleneck, provide:
- What the issue is and why it matters
- The specific fix with code or config changes
- Expected improvement (quantified when possible)
- Any tradeoffs or risks

### 4. Implement

Apply fixes one at a time with the user's approval. Re-measure after each change to validate improvement.

## Output

- Baseline performance metrics
- Bottleneck analysis ranked by impact/effort
- Specific fixes with expected improvements
- Before/after comparison for applied changes

## Gotchas

- **Premature optimization**: Always profile first — the actual bottleneck is rarely where developers assume
- **Bundle analyzers** require a production build — dev mode bundles are not representative
- **Code splitting** adds HTTP requests — splitting too aggressively can hurt performance on slow connections
- **Redis caching** introduces cache invalidation complexity — only suggest for data with clear TTL semantics
- **Tree shaking** only works with ES modules — CommonJS `require()` calls prevent dead code elimination
- **Parallel builds** (thread-loader, worker threads) have overhead — only beneficial for large projects
- **next/dynamic and React.lazy** require error boundaries — missing them causes white screens on chunk load failure
- **Database indexes** speed up reads but slow down writes — always consider the write pattern before adding indexes
- Measure in production-like environments — dev mode performance is not representative of real-world behavior
