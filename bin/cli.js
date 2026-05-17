#!/usr/bin/env node
/**
 * claudifying CLI — install/update/uninstall the Claudifying extension library.
 *
 * Usage:
 *   npx github:pauldx/claudifying              # install (default)
 *   npx github:pauldx/claudifying update       # pull latest + re-link
 *   npx github:pauldx/claudifying uninstall    # remove all symlinks
 *   npx github:pauldx/claudifying status       # show what's installed
 *
 * Flags:
 *   --target <dir>   Custom clone location (default: ~/.claudifying)
 *   --force          Overwrite existing symlinks
 *   --dry-run        Preview without changes
 *   --branch <name>  Clone a specific branch (default: main)
 *   --help, -h       Show this help
 *   --version, -v    Show version
 */

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PKG = require('../package.json');
const REPO_URL = 'https://github.com/pauldx/claudifying.git';
const DEFAULT_TARGET = path.join(os.homedir(), '.claudifying');
const CLAUDE_DIR = path.join(os.homedir(), '.claude');

const C = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m',
};

function color(c, s) {
  return process.stdout.isTTY ? `${C[c]}${s}${C.reset}` : s;
}

function log(msg) {
  console.log(msg);
}

function info(msg) {
  log(`${color('cyan', 'ℹ')}  ${msg}`);
}

function ok(msg) {
  log(`${color('green', '✓')}  ${msg}`);
}

function warn(msg) {
  log(`${color('yellow', '⚠')}  ${msg}`);
}

function err(msg) {
  console.error(`${color('red', '✗')}  ${msg}`);
}

function exists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function ensureDir(p) {
  if (!exists(p)) fs.mkdirSync(p, { recursive: true });
}

function which(bin) {
  const result = spawnSync('which', [bin], { encoding: 'utf8' });
  return result.status === 0 ? result.stdout.trim() : null;
}

function parseArgs(argv) {
  const args = { command: 'install', flags: {} };
  const positional = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') {
      args.flags.help = true;
    } else if (a === '--version' || a === '-v') {
      args.flags.version = true;
    } else if (a === '--force') {
      args.flags.force = true;
    } else if (a === '--dry-run') {
      args.flags.dryRun = true;
    } else if (a === '--target') {
      args.flags.target = argv[++i];
    } else if (a === '--branch') {
      args.flags.branch = argv[++i];
    } else if (!a.startsWith('--')) {
      positional.push(a);
    } else {
      warn(`Unknown flag: ${a}`);
    }
  }
  if (positional.length > 0) args.command = positional[0];
  return args;
}

function printHelp() {
  log(`${color('bold', 'claudifying')} ${color('dim', `v${PKG.version}`)}
${color('dim', 'Unified Claude Code extension library installer')}

${color('bold', 'Usage:')}
  npx github:pauldx/claudifying [command] [flags]

${color('bold', 'Commands:')}
  install       Install all extensions globally (default)
  update        Pull latest changes and re-link
  uninstall     Remove all claudifying symlinks
  status        Show what's installed
  help          Show this help

${color('bold', 'Flags:')}
  --target <dir>   Clone location (default: ~/.claudifying)
  --branch <name>  Branch to use (default: main)
  --force          Overwrite existing symlinks
  --dry-run        Preview without changes
  --help, -h       Show help
  --version, -v    Show version

${color('bold', 'Examples:')}
  ${color('dim', '# Install everything globally')}
  npx github:pauldx/claudifying

  ${color('dim', '# Update to latest')}
  npx github:pauldx/claudifying update

  ${color('dim', '# Preview install without changes')}
  npx github:pauldx/claudifying --dry-run

  ${color('dim', '# Remove all symlinks')}
  npx github:pauldx/claudifying uninstall

${color('bold', 'After install:')}
  Try any /cf-<skill> in Claude Code — works in every repo.
  Full catalog: https://github.com/pauldx/claudifying
`);
}

function preflight() {
  if (!which('git')) {
    err('git not found on PATH. Install git first.');
    process.exit(1);
  }
  if (!which('bash')) {
    err('bash not found on PATH. Install bash first.');
    process.exit(1);
  }
  if (!exists(CLAUDE_DIR)) {
    warn(`~/.claude/ does not exist. Creating it.`);
    ensureDir(CLAUDE_DIR);
  }
}

function cloneOrUpdate(target, branch) {
  if (exists(path.join(target, '.git'))) {
    info(`Updating existing clone at ${color('dim', target)}`);
    const result = spawnSync('git', ['-C', target, 'pull', '--ff-only'], { stdio: 'inherit' });
    if (result.status !== 0) {
      warn('git pull failed — continuing with existing checkout');
    }
    if (branch && branch !== 'main') {
      spawnSync('git', ['-C', target, 'checkout', branch], { stdio: 'inherit' });
    }
  } else {
    info(`Cloning ${color('magenta', REPO_URL)} → ${color('dim', target)}`);
    const cloneArgs = ['clone', '--depth', '1'];
    if (branch && branch !== 'main') cloneArgs.push('--branch', branch);
    cloneArgs.push(REPO_URL, target);
    const result = spawnSync('git', cloneArgs, { stdio: 'inherit' });
    if (result.status !== 0) {
      err('git clone failed');
      process.exit(1);
    }
  }
  ok(`Repo ready at ${color('dim', target)}`);
}

function runInstaller(target, script, flags) {
  const scriptPath = path.join(target, script);
  if (!exists(scriptPath)) {
    err(`${script} not found at ${scriptPath}`);
    process.exit(1);
  }
  try {
    fs.chmodSync(scriptPath, 0o755);
  } catch {}

  const args = [];
  if (flags.dryRun) args.push('--dry-run');
  if (flags.force) args.push('--force');

  info(`Running ${color('bold', script)} ${args.join(' ')}`.trim());
  const result = spawnSync('bash', [scriptPath, ...args], { cwd: target, stdio: 'inherit' });
  if (result.status !== 0) {
    err(`${script} exited with status ${result.status}`);
    process.exit(result.status || 1);
  }
}

function cmdInstall(target, flags) {
  preflight();
  cloneOrUpdate(target, flags.branch);
  runInstaller(target, 'install.sh', flags);
  log('');
  ok(color('bold', 'Claudifying installed.'));
  log(`${color('dim', '  • Try any /cf-<skill> in Claude Code.')}`);
  log(`${color('dim', '  • Full catalog: https://github.com/pauldx/claudifying')}`);
  log(`${color('dim', `  • Update later: npx github:pauldx/claudifying update`)}`);
}

function cmdUpdate(target, flags) {
  preflight();
  if (!exists(path.join(target, '.git'))) {
    warn(`No clone found at ${target}. Running install instead.`);
    return cmdInstall(target, flags);
  }
  cloneOrUpdate(target, flags.branch);
  runInstaller(target, 'install.sh', { ...flags, force: true });
  ok(color('bold', 'Claudifying updated.'));
}

function cmdUninstall(target, flags) {
  preflight();
  if (!exists(path.join(target, '.git'))) {
    err(`No clone at ${target}. Nothing to uninstall.`);
    process.exit(1);
  }
  runInstaller(target, 'uninstall.sh', flags);
  ok(color('bold', 'Claudifying symlinks removed.'));
  info(`Clone still exists at ${color('dim', target)} — delete manually if desired.`);
}

function cmdStatus(target) {
  log(color('bold', 'Claudifying status'));
  log('');
  log(`  ${color('dim', 'Clone:')}      ${exists(path.join(target, '.git')) ? color('green', target) : color('yellow', 'not installed')}`);
  log(`  ${color('dim', '~/.claude:')}  ${exists(CLAUDE_DIR) ? color('green', CLAUDE_DIR) : color('red', 'missing')}`);

  if (exists(CLAUDE_DIR)) {
    const dirs = ['skills', 'plugins', 'commands', 'agents', 'hooks', 'rules'];
    for (const d of dirs) {
      const p = path.join(CLAUDE_DIR, d);
      if (!exists(p)) continue;
      let count = 0;
      try {
        count = fs.readdirSync(p).length;
      } catch {}
      log(`  ${color('dim', d.padEnd(10))} ${color('cyan', String(count).padStart(5))} ${color('dim', 'entries')}`);
    }
  }

  if (exists(path.join(target, '.git'))) {
    try {
      const sha = execSync('git rev-parse --short HEAD', { cwd: target, encoding: 'utf8' }).trim();
      const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd: target, encoding: 'utf8' }).trim();
      log('');
      log(`  ${color('dim', 'Branch:')}    ${color('magenta', branch)} @ ${color('dim', sha)}`);
    } catch {}
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.flags.version) {
    log(`claudifying ${PKG.version}`);
    process.exit(0);
  }
  if (args.flags.help || args.command === 'help') {
    printHelp();
    process.exit(0);
  }

  const target = args.flags.target ? path.resolve(args.flags.target) : DEFAULT_TARGET;

  log('');
  log(`${color('bold', '╭─ claudifying')} ${color('dim', `v${PKG.version}`)}${color('bold', ' ───────────────────')}`);
  log(`${color('bold', '│')}  Unified Claude Code extension library`);
  log(`${color('bold', '╰────────────────────────────────────────')}`);
  log('');

  try {
    switch (args.command) {
      case 'install':
        cmdInstall(target, args.flags);
        break;
      case 'update':
        cmdUpdate(target, args.flags);
        break;
      case 'uninstall':
      case 'remove':
        cmdUninstall(target, args.flags);
        break;
      case 'status':
      case 'info':
        cmdStatus(target);
        break;
      default:
        err(`Unknown command: ${args.command}`);
        printHelp();
        process.exit(1);
    }
  } catch (e) {
    err(e.message || String(e));
    if (process.env.DEBUG) console.error(e.stack);
    process.exit(1);
  }
}

main();
