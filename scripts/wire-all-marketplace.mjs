#!/usr/bin/env node
/**
 * Wire all marketplace extensions from claude-code-plugins-plus-skills
 * Scans: 425 plugins, 2,810 skills, 200 agents
 * Output: Catalogs with cf- namespacing + categorization
 *
 * Usage: node scripts/wire-all-marketplace.mjs /path/to/source-repo
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dir, '..');

const sourceRepo = process.argv[2];
if (!sourceRepo) {
  console.error('Usage: node scripts/wire-all-marketplace.mjs /path/to/source-repo');
  process.exit(1);
}

if (!fs.existsSync(sourceRepo)) {
  console.error(`Source repo not found: ${sourceRepo}`);
  process.exit(1);
}

console.log('🔍 Scanning marketplace...\n');

// Ensure output dirs exist
['agents-expanded', 'skills-expanded', 'plugins-expanded'].forEach(dir => {
  const fullPath = path.join(repoRoot, dir);
  if (!fs.existsSync(fullPath)) {
    fs.mkdirSync(fullPath, { recursive: true });
  }
});

// Category mappings
const cfCategoryMap = {
  // Skills categories (01-20 packs)
  '01-devops-basics': 'cf-devops-basics',
  '02-devops-advanced': 'cf-devops-advanced',
  '03-security-fundamentals': 'cf-security-fundamentals',
  '04-security-advanced': 'cf-security-advanced',
  '05-frontend-dev': 'cf-frontend-dev',
  '06-backend-dev': 'cf-backend-dev',
  '07-ml-training': 'cf-ml-training',
  '08-ml-deployment': 'cf-ml-deployment',
  '09-test-automation': 'cf-test-automation',
  '10-performance-testing': 'cf-performance-testing',
  '11-data-pipelines': 'cf-data-pipelines',
  '12-data-analytics': 'cf-data-analytics',
  '13-aws-skills': 'cf-aws-skills',
  '14-gcp-skills': 'cf-gcp-skills',
  '15-api-development': 'cf-api-development',
  '16-api-integration': 'cf-api-integration',
  '17-technical-docs': 'cf-technical-docs',
  '18-visual-content': 'cf-visual-content',
  '19-business-automation': 'cf-business-automation',
  '20-enterprise-workflows': 'cf-enterprise-workflows',

  // Plugin categories
  'ai-agency': 'cf-ai-agency',
  'ai-ml': 'cf-ai-ml',
  'api-development': 'cf-api-dev',
  'business-tools': 'cf-business-tools',
  'community': 'cf-community',
  'crypto': 'cf-crypto',
  'database': 'cf-database',
  'design': 'cf-design',
  'devops': 'cf-devops',
  'mcp': 'cf-mcp',
  'performance': 'cf-performance',
  'productivity': 'cf-productivity',
  'saas-packs': 'cf-saas-packs',
  'security': 'cf-security',
  'skill-enhancers': 'cf-skill-enhancers',
  'testing': 'cf-testing'
};

// Parse SKILL.md frontmatter
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

    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }

    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.slice(1, -1).split(',').map(v => v.trim());
    }

    frontmatter[key] = value;
  }

  return frontmatter;
}

// Scan skills
function scanSkills() {
  const skillsDir = path.join(sourceRepo, 'skills');
  const allSkills = {};
  let totalSkills = 0;

  if (!fs.existsSync(skillsDir)) {
    console.warn('⚠️  Skills directory not found');
    return { allSkills, totalSkills };
  }

  const categories = fs.readdirSync(skillsDir);

  for (const category of categories) {
    const categoryPath = path.join(skillsDir, category);
    if (!fs.statSync(categoryPath).isDirectory()) continue;

    const cfCategory = cfCategoryMap[category];
    if (!cfCategory) {
      console.warn(`Unknown skill category: ${category}`);
      continue;
    }

    allSkills[cfCategory] = { count: 0, skills: [] };

    const skillDirs = fs.readdirSync(categoryPath);
    for (const skillName of skillDirs) {
      const skillPath = path.join(categoryPath, skillName);
      if (!fs.statSync(skillPath).isDirectory()) continue;

      const mdPath = path.join(skillPath, 'SKILL.md');
      if (!fs.existsSync(mdPath)) continue;

      try {
        const content = fs.readFileSync(mdPath, 'utf-8');
        const frontmatter = parseSkillFrontmatter(content);

        allSkills[cfCategory].skills.push({
          name: frontmatter.name || skillName,
          description: frontmatter.description || '',
          version: frontmatter.version || '1.0.0',
          author: frontmatter.author || 'Jeremy Longshore',
          'allowed-tools': frontmatter['allowed-tools'] || 'All',
          trigger: `/cf-${skillName.replace(/_/g, '-')}`,
          path: `${category}/${skillName}/SKILL.md`
        });

        totalSkills++;
      } catch (e) {
        console.warn(`Failed to parse ${skillName}: ${e.message}`);
      }
    }

    allSkills[cfCategory].count = allSkills[cfCategory].skills.length;
  }

  return { allSkills, totalSkills };
}

// Scan agents
function scanAgents() {
  const agents = [];
  const agentsDir = path.join(sourceRepo, '.claude', 'agents');

  if (!fs.existsSync(agentsDir)) {
    console.warn('⚠️  Agents directory not found');
    return { agents, totalAgents: 0 };
  }

  const files = fs.readdirSync(agentsDir).filter(f => f.endsWith('.yml') || f.endsWith('.yaml'));

  for (const file of files) {
    const ymlPath = path.join(agentsDir, file);
    try {
      const content = fs.readFileSync(ymlPath, 'utf-8');

      // Simple YAML name extraction
      const nameMatch = content.match(/name:\s*["']?([^"'\n]+)["']?/);
      const descMatch = content.match(/description:\s*["']?([^"'\n]+)["']?/);

      if (nameMatch) {
        agents.push({
          name: `cf-${nameMatch[1].toLowerCase().replace(/\s+/g, '-')}`,
          original: nameMatch[1],
          description: descMatch ? descMatch[1] : '',
          path: `.claude/agents/${file}`
        });
      }
    } catch (e) {
      console.warn(`Failed to parse agent ${file}: ${e.message}`);
    }
  }

  return { agents, totalAgents: agents.length };
}

// Scan plugins
function scanPlugins() {
  const pluginsDir = path.join(sourceRepo, 'plugins');
  const allPlugins = {};
  let totalPlugins = 0;

  if (!fs.existsSync(pluginsDir)) {
    console.warn('⚠️  Plugins directory not found');
    return { allPlugins, totalPlugins };
  }

  const categories = fs.readdirSync(pluginsDir);

  for (const category of categories) {
    if (category.startsWith('.') || category === 'README') continue;

    const categoryPath = path.join(pluginsDir, category);
    if (!fs.statSync(categoryPath).isDirectory()) continue;

    const cfCategory = cfCategoryMap[category] || `cf-${category}`;
    allPlugins[cfCategory] = { count: 0, plugins: [] };

    const pluginDirs = fs.readdirSync(categoryPath);
    for (const pluginName of pluginDirs) {
      const pluginPath = path.join(categoryPath, pluginName);
      if (!fs.statSync(pluginPath).isDirectory()) continue;

      const jsonPath = path.join(pluginPath, '.claude-plugin', 'plugin.json');
      if (!fs.existsSync(jsonPath)) continue;

      try {
        const json = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
        allPlugins[cfCategory].plugins.push({
          name: `cf-${(json.name || pluginName).toLowerCase().replace(/\s+/g, '-')}`,
          original: json.name || pluginName,
          description: json.description || '',
          version: json.version || '1.0.0',
          keywords: json.keywords || [],
          author: json.author?.name || 'Claude Code Plugins',
          install: `ccpi install ${json.name || pluginName}`,
          plugin_cmd: `/plugin install ${json.name || pluginName}@claude-code-plugins-plus`,
          path: `plugins/${category}/${pluginName}`
        });

        totalPlugins++;
      } catch (e) {
        console.warn(`Failed to parse plugin ${pluginName}: ${e.message}`);
      }
    }

    allPlugins[cfCategory].count = allPlugins[cfCategory].plugins.length;
  }

  return { allPlugins, totalPlugins };
}

// Generate catalogs
function generateCatalogs(skills, agents, plugins) {
  // Skills expanded catalog
  const skillsCatalog = {
    generated: new Date().toISOString(),
    source: 'jeremylongshore/claude-code-plugins-plus-skills',
    total: Object.values(skills).reduce((sum, cat) => sum + cat.count, 0),
    categories: skills
  };

  fs.writeFileSync(
    path.join(repoRoot, 'skills-expanded', 'catalog.json'),
    JSON.stringify(skillsCatalog, null, 2)
  );

  // Agents catalog
  const agentsCatalog = {
    generated: new Date().toISOString(),
    source: 'jeremylongshore/claude-code-plugins-plus-skills',
    total: agents.length,
    agents: agents.sort((a, b) => a.name.localeCompare(b.name))
  };

  fs.writeFileSync(
    path.join(repoRoot, 'agents-expanded', 'catalog.json'),
    JSON.stringify(agentsCatalog, null, 2)
  );

  // Plugins expanded catalog
  const pluginsCatalog = {
    generated: new Date().toISOString(),
    source: 'jeremylongshore/claude-code-plugins-plus-skills',
    total: Object.values(plugins).reduce((sum, cat) => sum + cat.count, 0),
    categories: plugins
  };

  fs.writeFileSync(
    path.join(repoRoot, 'plugins-expanded', 'catalog.json'),
    JSON.stringify(pluginsCatalog, null, 2)
  );
}

// Main
async function main() {
  try {
    const { allSkills, totalSkills } = scanSkills();
    console.log(`✓ Scanned ${totalSkills} skills across ${Object.keys(allSkills).length} categories`);

    const { agents, totalAgents } = scanAgents();
    console.log(`✓ Scanned ${totalAgents} agents`);

    const { allPlugins, totalPlugins } = scanPlugins();
    console.log(`✓ Scanned ${totalPlugins} plugins across ${Object.keys(allPlugins).length} categories`);

    generateCatalogs(allSkills, agents, allPlugins);

    console.log('\n✅ Complete wireup:');
    console.log(`   ${totalSkills} skills → skills-expanded/catalog.json`);
    console.log(`   ${totalAgents} agents → agents-expanded/catalog.json`);
    console.log(`   ${totalPlugins} plugins → plugins-expanded/catalog.json`);
    console.log(`\n   All namespaced with cf- prefix & categorized`);

  } catch (e) {
    console.error('Fatal error:', e);
    process.exit(1);
  }
}

main();
