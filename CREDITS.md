# Credits & Upstream Attribution

Claudifying is a curated, organized library of Claude Code extensions. The
vast majority of the bundled skills, plugins, agents, and commands originate
from **upstream open-source projects and marketplaces**. This file records
those sources so that authorship and licensing trails remain intact even
after the `author:` metadata fields were normalized for namespace
consistency.

If you authored any of the items below and want your attribution surfaced
differently (added back to frontmatter, swapped, removed entirely, etc.),
open an issue on the repo and we will adjust.

---

## Upstream Sources

| Source | What's bundled | License |
|---|---|---|
| [aitmpl.com / claude-code-templates](https://www.aitmpl.com) | ~500 marketplace skills, 48 marketplace slash commands, the bulk of `plugins/` | MIT (per source repo) |
| [claudecodeplugins.io](https://www.claudecodeplugins.io) | Plugins authored under `Claude Code Plugins`, `Mattyp`, and related identities | As-published (typically MIT) |
| [Anthropic](https://www.anthropic.com) | Concept of slash commands, skills, agents, hooks, the underlying [Claude Code](https://docs.anthropic.com/en/docs/claude-code) runtime | Anthropic terms apply |
| [charmbracelet/vhs](https://github.com/charmbracelet/vhs) | Deterministic terminal GIFs in `docs/demos/` | MIT |
| Individual marketplace authors | Skill / plugin authorship — see list below | Per-package licenses (predominantly MIT) |

The original `author:` YAML metadata was removed from skill and plugin
frontmatter so the public README and catalog can render a clean, uniform
namespace. **Removing the field does not strip copyright.** Per-package
`LICENSE` files (where present in the upstream package) remain untouched in
this repo and continue to govern reuse.

---

## Individual Authors Detected at Import Time

The following names appeared in `author:` fields of imported skills/plugins
before normalization. They are credited collectively here so attribution is
preserved at the repo level.

- affaan-m
- Ahmed Khaled Mohamed
- amalsam18
- Amit Rathiesh
- B12.io
- Bayram Annakov
- Bubble Invest
- builtbyzac
- Burak Bayir
- Claude Code Plugins
- claude-code-plugins
- Damien Laine
- FastMCP Community
- Intent Solutions
- Jack Reis
- Jake Kozloski
- Jeremy Longshore
- Kairo Official
- Kemeny Studio
- manim-community
- Martin Gontovnikas
- Mattyp
- motion-canvas
- Nate Nelson
- Nestor Magalhaes
- Numman Ali
- openai (OpenAI-authored cookbook references only — no model usage)
- Orchestra Research
- Promptbook
- Railway
- remotion-dev
- renat
- Rohit Hazra
- Rowan Brooks
- severity1
- Srinivas Vaddisrinivas
- Steven Leggett
- suhaibjanjua
- tonone-ai
- Vercel Engineering
- ykotik

Entries that look like placeholder values (`{{AUTHOR_NAME}}`, `Your Name`,
`Author Name`, `Name`, template tokens) were also present and have been
dropped — they were never genuine attributions.

---

## Native Content

The following files are original to this repository (Debashis Paul,
[@pauldx](https://github.com/pauldx)) and licensed MIT per `LICENSE`:

- `README.md`, `CLAUDE.md`, `INDEX.md`, `LICENSE`, `CREDITS.md`
- `install.sh`, `uninstall.sh`, `update-marketplace-*.sh`
- The four native agents in `.claude/agents/`
- The four native hooks in `.claude/hooks/`
- The two native rules in `.claude/rules/`
- The five native slash commands in `.claude/commands/general/`
- `skills/native/cf-code-review/`, `skills/native/cf-refactor/`,
  `skills/native/cf-security-audit/`, `skills/native/cf-test-writer/` and
  the other 40 native skills enumerated in `CLAUDE.md`
- `docs/demos/` (recordings, tapes, scripts, simulator)
- `docs/charts/` (sample data + matplotlib generators)
- `.gitleaks.toml`

---

## License Summary

The umbrella `LICENSE` for this repository is MIT. Imported third-party
content retains its own license where one is shipped inside the package
directory. If a particular skill or plugin is missing an upstream `LICENSE`
file and you believe it should ship with one, file an issue.

---

## How To Request Changes

- **Add back attribution to a specific skill:** open a PR re-adding the
  `author:` line in that skill's frontmatter.
- **Take a skill down:** open an issue with the package path; we will
  remove it from the bundle in the next release.
- **Add yourself to the list above:** open a PR editing this file.
