#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dir, '..');

// Source repo path from command-line argument or environment variable
const sourceRepoRoot = process.argv[2] || process.env.SOURCE_REPO;
if (!sourceRepoRoot) {
  console.error('Usage: node scripts/generate-catalog.mjs <path-to-source-repo>');
  console.error('Or set SOURCE_REPO environment variable');
  process.exit(1);
}

if (!fs.existsSync(sourceRepoRoot)) {
  console.error(`Source repo not found: ${sourceRepoRoot}`);
  process.exit(1);
}

const pluginsCatalogPath = path.join(repoRoot, 'plugins', 'catalog.json');
const pluginsCatalogMd = path.join(repoRoot, 'plugins', 'CATALOG.md');
const skillsCatalogPath = path.join(repoRoot, 'skills', 'catalog.json');
const skillsCatalogMd = path.join(repoRoot, 'skills', 'CATALOG.md');

// Category display names for plugins
const pluginCategoryNames = {
  'saas-packs': 'SaaS Packs',
  'ai-ml': 'AI/ML',
  'ai-agency': 'AI Agency',
  'api-development': 'API Development',
  'business-tools': 'Business Tools',
  'skill-enhancers': 'Skill Enhancers',
  'crypto': 'Crypto & Blockchain',
  'database': 'Database',
  'design': 'Design',
  'devops': 'DevOps',
  'examples': 'Examples',
  'mcp': 'MCP',
  'performance': 'Performance',
  'productivity': 'Productivity',
  'security': 'Security',
  'testing': 'Testing',
  'community': 'Community'
};

// Category display names for skills
const skillCategoryNames = {
  '01-devops-basics': 'DevOps Basics',
  '02-devops-advanced': 'DevOps Advanced',
  '03-security-fundamentals': 'Security Fundamentals',
  '04-security-advanced': 'Security Advanced',
  '05-frontend-dev': 'Frontend Development',
  '06-backend-dev': 'Backend Development',
  '07-ml-training': 'ML Training',
  '08-ml-deployment': 'ML Deployment',
  '09-test-automation': 'Test Automation',
  '10-performance-testing': 'Performance Testing',
  '11-data-pipelines': 'Data Pipelines',
  '12-data-analytics': 'Data Analytics',
  '13-aws-skills': 'AWS Skills',
  '14-gcp-skills': 'GCP Skills',
  '15-api-development': 'API Development',
  '16-api-integration': 'API Integration',
  '17-technical-docs': 'Technical Docs',
  '18-visual-content': 'Visual Content',
  '19-business-automation': 'Business Automation',
  '20-enterprise-workflows': 'Enterprise Workflows'
};

// Ordered for logical flow
const pluginCategoryOrder = [
  'devops',
  'security',
  'testing',
  'performance',
  'ai-ml',
  'ai-agency',
  'api-development',
  'database',
  'crypto',
  'business-tools',
  'saas-packs',
  'productivity',
  'mcp',
  'design',
  'skill-enhancers',
  'community',
  'examples'
];

const skillCategoryOrder = Object.keys(skillCategoryNames).sort();

// Parse YAML frontmatter from SKILL.md (simple key: value parser)
function parseSkillFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const frontmatter = {};
  const lines = match[1].split('\n');

  for (const line of lines) {
    if (!line.trim()) continue;
    const colonIdx = line.indexOf(':');
    if (colonIdx === -1) continue;

    const key = line.slice(0, colonIdx).trim();
    let value = line.slice(colonIdx + 1).trim();

    // Remove quotes if present
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    // Simple array parsing: [item1, item2]
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.slice(1, -1).split(',').map(v => v.trim());
    }

    frontmatter[key] = value;
  }

  return frontmatter;
}

// Scan plugins
function scanPlugins() {
  const pluginsDir = path.join(sourceRepoRoot, 'plugins');
  const catalog = {
    generated: new Date().toISOString(),
    source: 'jeremylongshore/claude-code-plugins-plus-skills',
    total: 0,
    categories: {}
  };

  for (const category of pluginCategoryOrder) {
    const categoryDir = path.join(pluginsDir, category);
    if (!fs.existsSync(categoryDir)) continue;

    const plugins = [];
    const entries = fs.readdirSync(categoryDir);

    for (const pluginName of entries) {
      const pluginPath = path.join(categoryDir, pluginName);
      const stat = fs.statSync(pluginPath);
      if (!stat.isDirectory()) continue;

      const jsonPath = path.join(pluginPath, '.claude-plugin', 'plugin.json');
      if (!fs.existsSync(jsonPath)) continue;

      try {
        const jsonContent = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
        plugins.push({
          name: jsonContent.name || pluginName,
          description: jsonContent.description || '',
          version: jsonContent.version || '1.0.0',
          keywords: jsonContent.keywords || [],
          author: jsonContent.author?.name || 'Claude Code Plugins',
          install: `ccpi install ${jsonContent.name || pluginName}`,
          plugin_cmd: `/plugin install ${jsonContent.name || pluginName}@claude-code-plugins-plus`
        });
      } catch (e) {
        console.warn(`Failed to parse ${jsonPath}:`, e.message);
      }
    }

    if (plugins.length > 0) {
      catalog.categories[category] = {
        count: plugins.length,
        display_name: pluginCategoryNames[category] || category,
        plugins: plugins.sort((a, b) => a.name.localeCompare(b.name))
      };
      catalog.total += plugins.length;
    }
  }

  return catalog;
}

// Scan skills
function scanSkills() {
  const skillsDir = path.join(sourceRepoRoot, 'skills');
  const catalog = {
    generated: new Date().toISOString(),
    source: 'jeremylongshore/claude-code-plugins-plus-skills',
    total: 0,
    categories: {}
  };

  for (const category of skillCategoryOrder) {
    const categoryDir = path.join(skillsDir, category);
    if (!fs.existsSync(categoryDir)) continue;

    const skills = [];
    const entries = fs.readdirSync(categoryDir);

    for (const skillName of entries) {
      const skillPath = path.join(categoryDir, skillName);
      const stat = fs.statSync(skillPath);
      if (!stat.isDirectory()) continue;

      const mdPath = path.join(skillPath, 'SKILL.md');
      if (!fs.existsSync(mdPath)) continue;

      try {
        const mdContent = fs.readFileSync(mdPath, 'utf-8');
        const frontmatter = parseSkillFrontmatter(mdContent);

        skills.push({
          name: frontmatter.name || skillName,
          description: frontmatter.description || '',
          version: frontmatter.version || '1.0.0',
          author: frontmatter.author || 'Jeremy Longshore',
          'allowed-tools': frontmatter['allowed-tools'] || 'All',
          'compatible-with': frontmatter['compatible-with'] || 'claude-code'
        });
      } catch (e) {
        console.warn(`Failed to parse ${mdPath}:`, e.message);
      }
    }

    if (skills.length > 0) {
      catalog.categories[category] = {
        count: skills.length,
        display_name: skillCategoryNames[category] || category,
        skills: skills.sort((a, b) => a.name.localeCompare(b.name))
      };
      catalog.total += skills.length;
    }
  }

  return catalog;
}

// Generate plugins markdown
function generatePluginsMd(catalog) {
  let md = `# Plugins Catalog

**Total: ${catalog.total} plugins** across ${Object.keys(catalog.categories).length} categories from [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills)

Install any plugin via CLI:
\`\`\`bash
ccpi install <plugin-name>
\`\`\`

Or in Claude Code:
\`\`\`
/plugin install <plugin-name>@claude-code-plugins-plus
\`\`\`

---

## Table of Contents

`;

  // Generate TOC
  for (const category of pluginCategoryOrder) {
    if (catalog.categories[category]) {
      const displayName = catalog.categories[category].display_name;
      const anchor = category.replace(/[^a-z0-9]/g, '-').toLowerCase();
      md += `- [${displayName}](#${anchor}) (${catalog.categories[category].count})\n`;
    }
  }

  md += '\n---\n\n';

  // Generate category sections
  for (const category of pluginCategoryOrder) {
    const cat = catalog.categories[category];
    if (!cat) continue;

    const anchor = category.replace(/[^a-z0-9]/g, '-').toLowerCase();
    md += `## ${cat.display_name}\n\n`;
    md += `**${cat.count} plugins**\n\n`;
    md += '| Plugin | Description | Install |\n';
    md += '|--------|-------------|----------|\n';

    for (const plugin of cat.plugins) {
      const desc = (plugin.description || '').slice(0, 60).replace(/\|/g, '\\|');
      md += `| **${plugin.name}** | ${desc}${plugin.description && plugin.description.length > 60 ? '...' : ''} | \`${plugin.install}\` |\n`;
    }

    md += '\n';
  }

  return md;
}

// Generate skills markdown
function generateSkillsMd(catalog) {
  let md = `# Skills Catalog

**Total: ${catalog.total} skills** across ${Object.keys(catalog.categories).length} categories from [jeremylongshore/claude-code-plugins-plus-skills](https://github.com/jeremylongshore/claude-code-plugins-plus-skills)

Skills are triggered by specific phrases or commands in Claude Code. See each skill's description for usage.

---

## Table of Contents

`;

  // Generate TOC
  for (const category of skillCategoryOrder) {
    if (catalog.categories[category]) {
      const displayName = catalog.categories[category].display_name;
      const anchor = category.replace(/[^a-z0-9]/g, '-').toLowerCase();
      md += `- [${displayName}](#${anchor}) (${catalog.categories[category].count})\n`;
    }
  }

  md += '\n---\n\n';

  // Generate category sections
  for (const category of skillCategoryOrder) {
    const cat = catalog.categories[category];
    if (!cat) continue;

    const anchor = category.replace(/[^a-z0-9]/g, '-').toLowerCase();
    md += `## ${cat.display_name}\n\n`;
    md += `**${cat.count} skills**\n\n`;
    md += '| Skill | Description | Author |\n';
    md += '|-------|-------------|--------|\n';

    for (const skill of cat.skills) {
      const desc = (skill.description || '').slice(0, 60).replace(/\|/g, '\\|');
      md += `| **${skill.name}** | ${desc}${skill.description && skill.description.length > 60 ? '...' : ''} | ${skill.author} |\n`;
    }

    md += '\n';
  }

  return md;
}

// Main
console.log('Scanning plugins...');
const pluginsCatalog = scanPlugins();
fs.writeFileSync(pluginsCatalogPath, JSON.stringify(pluginsCatalog, null, 2));
fs.writeFileSync(pluginsCatalogMd, generatePluginsMd(pluginsCatalog));
console.log(`✓ Generated plugins catalog: ${pluginsCatalog.total} plugins in ${Object.keys(pluginsCatalog.categories).length} categories`);

console.log('Scanning skills...');
const skillsCatalog = scanSkills();
fs.writeFileSync(skillsCatalogPath, JSON.stringify(skillsCatalog, null, 2));
fs.writeFileSync(skillsCatalogMd, generateSkillsMd(skillsCatalog));
console.log(`✓ Generated skills catalog: ${skillsCatalog.total} skills in ${Object.keys(skillsCatalog.categories).length} categories`);

console.log('\nCatalog generation complete!');
