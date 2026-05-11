import fs from 'fs';
import path from 'path';

const repoRoot = '.';

// Load existing catalog from sibling repo
const existingPath = path.join(repoRoot, 'plugins-expanded', 'catalog.json');
const existingCatalog = JSON.parse(fs.readFileSync(existingPath, 'utf-8'));

// Load aitmpl full catalog
const aitmplPath = path.join(repoRoot, 'plugins', 'aitmpl_full_catalog.json');
const aitmplData = JSON.parse(fs.readFileSync(aitmplPath, 'utf-8'));

// Merge plugins with deduplication
const mergedPlugins = {};
const seen = new Set();

// Process existing catalog
for (const [category, catData] of Object.entries(existingCatalog.categories || {})) {
  if (!mergedPlugins[category]) mergedPlugins[category] = { count: 0, plugins: [] };
  
  for (const plugin of catData.plugins || []) {
    const key = `${plugin.name || ''}:${plugin.original || ''}`.toLowerCase();
    if (!seen.has(key)) {
      mergedPlugins[category].plugins.push(plugin);
      seen.add(key);
    }
  }
}

// Process aitmpl collections
let addedFromAitmpl = 0;
for (const collection of aitmplData.collections) {
  const collectionCategory = `cf-${collection.collection_name
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')}`;

  if (!mergedPlugins[collectionCategory]) {
    mergedPlugins[collectionCategory] = { count: 0, plugins: [] };
  }

  for (const plugin of collection.plugins || []) {
    const key = `${plugin.name || ''}:${plugin.original || ''}`.toLowerCase();
    
    if (!seen.has(key)) {
      const pluginEntry = {
        name: `cf-${(plugin.name || plugin.original || 'unknown')
          .toLowerCase()
          .replace(/\s+/g, '-')
          .replace(/[^a-z0-9-]/g, '')}`,
        original: plugin.name || plugin.original || '',
        description: plugin.description || '',
        category: collection.collection_name,
        source_collection: collection.collection_url,
        author: plugin.author || collection.author || '',
        stars: plugin.stars || 0,
        url: plugin.url || plugin.github_url || ''
      };
      
      mergedPlugins[collectionCategory].plugins.push(pluginEntry);
      seen.add(key);
      addedFromAitmpl++;
    }
  }
}

// Count totals
let totalPlugins = 0;
for (const category in mergedPlugins) {
  mergedPlugins[category].count = mergedPlugins[category].plugins.length;
  totalPlugins += mergedPlugins[category].count;
}

// Generate merged catalog
const mergedCatalog = {
  generated: new Date().toISOString(),
  source: 'Merged: sibling repo (430) + aitmpl collections (1,072 total)',
  total: totalPlugins,
  categories: mergedPlugins
};

// Write merged catalog
fs.writeFileSync(
  path.join(repoRoot, 'plugins-merged', 'catalog.json'),
  JSON.stringify(mergedCatalog, null, 2)
);

console.log(`✓ Merged plugins catalog:`);
console.log(`  Existing: 430 plugins from sibling repo`);
console.log(`  Added from aitmpl: ${addedFromAitmpl}`);
console.log(`  Total: ${totalPlugins} plugins`);
console.log(`  Categories: ${Object.keys(mergedPlugins).length}`);
console.log(`  Output: plugins-merged/catalog.json`);
