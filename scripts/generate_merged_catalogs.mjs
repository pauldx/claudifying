import fs from 'fs';
import path from 'path';

const catalog = JSON.parse(fs.readFileSync('plugins-merged/catalog.json', 'utf-8'));

// Sort categories
const sortedCategories = Object.keys(catalog.categories)
  .sort()
  .reduce((obj, key) => {
    obj[key] = catalog.categories[key];
    return obj;
  }, {});

// Generate markdown
let md = `# Plugins Catalog (Merged)

**Total: ${catalog.total} plugins** from sibling repo (430) + aitmpl.com collections (179 additional)

All plugins available with **\`/cf-\` prefix** for namespace consistency.

Source: ${catalog.source}

---

## Table of Contents

| Category | Count |
|----------|-------|
`;

for (const [cat, data] of Object.entries(sortedCategories)) {
  const displayName = cat.replace(/^cf-/, '').replace(/-/g, ' ');
  md += `| [${displayName}](#${cat}) | ${data.count} |\n`;
}

md += `\n---\n\n`;

// Generate category sections
for (const [cat, data] of Object.entries(sortedCategories)) {
  const displayName = cat.replace(/^cf-/, '').replace(/-/g, ' ').toUpperCase();
  
  md += `## ${cat}\n\n`;
  md += `**${data.count} ${displayName.toLowerCase()}**\n\n`;
  md += `| Name | Description | Author |\n`;
  md += `|------|-------------|--------|\n`;
  
  for (const plugin of data.plugins.slice(0, 10)) {
    const name = plugin.name || plugin.original || 'unknown';
    const desc = (plugin.description || '').substring(0, 80);
    const author = plugin.author || 'N/A';
    md += `| \`${name}\` | ${desc}... | ${author} |\n`;
  }
  
  if (data.plugins.length > 10) {
    md += `| ... | ... (${data.plugins.length - 10} more) | ... |\n`;
  }
  
  md += `\n`;
}

md += `\n---\n\n**Last updated:** ${new Date().toISOString().split('T')[0]} | **Source:** Merged catalog`;

fs.writeFileSync('plugins-merged/CATALOG.md', md);

console.log(`✓ Generated plugins-merged/CATALOG.md`);
