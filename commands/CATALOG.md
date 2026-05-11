# Slash Commands Catalog

**Total: 48 slash commands** organized into 5 categories

All commands available with **`/cf-` prefix** for namespace consistency:

```
/cf-todo [args]
/cf-search [query]
/cf-format [file]
```

All commands support `--help` flag for usage details.

---

## Directory Structure

Commands organized in `.claude/commands/marketplace/`:

```
marketplace/
├── productivity/  (8) — /cf-todo, /cf-timer, /cf-note, /cf-calendar, etc.
├── development/   (12) — /cf-snippets, /cf-format, /cf-lint, /cf-test, etc.
├── writing/       (10) — /cf-grammar-check, /cf-markdown, /cf-word-count, etc.
├── data/          (10) — /cf-csv-tools, /cf-json-tools, /cf-sql-query, etc.
└── research/      (8) — /cf-search, /cf-wikipedia, /cf-scholar, etc.
```

---

## Table of Contents

- [Productivity](#productivity) (8)
- [Development & Code](#development--code) (12)
- [Writing & Content](#writing--content) (10)
- [Data & Analytics](#data--analytics) (10)
- [Research & Learning](#research--learning) (8)

---

## Productivity

**8 productivity and time management commands**

| Command | Trigger | Usage | Description |
|---------|---------|-------|-------------|
| **todo** | `/cf-todo` | `/cf-todo add task \| /cf-todo list` | Create and manage todo lists |
| **timer** | `/cf-timer` | `/cf-timer 25m \| /cf-timer pomodoro` | Set time intervals and reminders |
| **note** | `/cf-note` | `/cf-note save \| /cf-note list` | Quick note taking and storage |
| **calendar** | `/cf-calendar` | `/cf-calendar add event \| /cf-calendar show` | Calendar integration and scheduling |
| **reminders** | `/cf-reminders` | `/cf-reminders me in 30 minutes` | Set reminders and notifications |
| **bookmark** | `/cf-bookmark` | `/cf-bookmark save \| /cf-bookmark list` | Save and organize bookmarks |
| **dictionary** | `/cf-dictionary` | `/cf-dictionary <word> \| /cf-dictionary synonyms` | Word definitions and thesaurus |
| **calculator** | `/cf-calculator` | `/cf-calculator 2+2*3 \| /cf-calculator convert` | Advanced calculations and conversions |

---

## Development & Code

**12 development and code tools**

| Command | Trigger | Usage | Description |
|---------|---------|-------|-------------|
| **snippets** | `/cf-snippets` | `/cf-snippets save <lang> \| /cf-snippets list` | Code snippet management |
| **format** | `/cf-format` | `/cf-format json \| /cf-format xml` | Code formatting and beautification |
| **lint** | `/cf-lint` | `/cf-lint javascript \| /cf-lint python` | Code linting and analysis |
| **test** | `/cf-test` | `/cf-test run \| /cf-test coverage` | Run tests and generate test cases |
| **debug** | `/cf-debug` | `/cf-debug log <var> \| /cf-debug break` | Debugging tools and breakpoints |
| **api-test** | `/cf-api-test` | `/cf-api-test <endpoint> \| /cf-api-test mock` | API testing and mocking |
| **regex** | `/cf-regex` | `/cf-regex test <pattern> \| /cf-regex explain` | Regular expression builder and tester |
| **database** | `/cf-database` | `/cf-database query <sql> \| /cf-database schema show` | Database query builder and explorer |
| **git-assist** | `/cf-git-assist` | `/cf-git-assist log \| /cf-git-assist branch create` | Git commands and workflow helpers |
| **dependency** | `/cf-dependency` | `/cf-dependency list \| /cf-dependency update <package>` | Dependency and package management |
| **docker-cli** | `/cf-docker-cli` | `/cf-docker-cli run \| /cf-docker-cli logs` | Docker container management |
| **env-manager** | `/cf-env-manager` | `/cf-env-manager list \| /cf-env-manager set KEY=value` | Environment variables management |

---

## Writing & Content

**10 writing and content tools**

| Command | Trigger | Usage | Description |
|---------|---------|-------|-------------|
| **grammar-check** | `/cf-grammar-check` | `/cf-grammar-check <text>` | Grammar and spell checking |
| **markdown** | `/cf-markdown` | `/cf-markdown table \| /cf-markdown code block` | Markdown formatting helpers |
| **word-count** | `/cf-word-count` | `/cf-word-count analyze \| /cf-word-count readability` | Document analysis and statistics |
| **paraphrase** | `/cf-paraphrase` | `/cf-paraphrase <text>` | Text paraphrasing and rewriting |
| **summary** | `/cf-summary` | `/cf-summary <text> --length short` | Text summarization |
| **outline** | `/cf-outline` | `/cf-outline generate \| /cf-outline expand` | Document outline and structure |
| **tone-check** | `/cf-tone-check` | `/cf-tone-check analyze \| /cf-tone-check formal` | Tone and sentiment analysis |
| **citation** | `/cf-citation` | `/cf-citation format apa \| /cf-citation from url` | Citation generation (APA, MLA, Chicago) |
| **template** | `/cf-template` | `/cf-template resume \| /cf-template proposal` | Document templates and starters |
| **glossary** | `/cf-glossary` | `/cf-glossary add term \| /cf-glossary list` | Terminology and glossary management |

---

## Data & Analytics

**10 data manipulation and analytics commands**

| Command | Trigger | Usage | Description |
|---------|---------|-------|-------------|
| **csv-tools** | `/cf-csv-tools` | `/cf-csv-tools parse \| /cf-csv-tools convert` | CSV parsing and manipulation |
| **json-tools** | `/cf-json-tools` | `/cf-json-tools validate \| /cf-json-tools transform` | JSON validation and transformation |
| **xml-tools** | `/cf-xml-tools` | `/cf-xml-tools validate \| /cf-xml-tools format` | XML parsing and formatting |
| **sql-query** | `/cf-sql-query` | `/cf-sql-query build select \| /cf-sql-query optimize` | SQL query builder and optimization |
| **chart** | `/cf-chart` | `/cf-chart bar <data> \| /cf-chart line <data>` | Data visualization and charts |
| **stats** | `/cf-stats` | `/cf-stats analyze <dataset>` | Statistical analysis tools |
| **conversion** | `/cf-conversion` | `/cf-conversion 100km to miles` | Unit and format conversion |
| **comparison** | `/cf-comparison` | `/cf-comparison file1 file2 \| /cf-comparison json1 json2` | Data comparison and diff |
| **aggregation** | `/cf-aggregation` | `/cf-aggregation group <column> \| /cf-aggregation sum` | Data aggregation and grouping |
| **validation** | `/cf-validation` | `/cf-validation json schema \| /cf-validation email` | Data validation and schema checking |

---

## Research & Learning

**8 research and learning commands**

| Command | Trigger | Usage | Description |
|---------|---------|-------|-------------|
| **search** | `/cf-search` | `/cf-search <query> \| /cf-search academic` | Web search and research |
| **wikipedia** | `/cf-wikipedia` | `/cf-wikipedia <topic> \| /cf-wikipedia summary` | Wikipedia lookup and summaries |
| **scholar** | `/cf-scholar` | `/cf-scholar search <topic>` | Academic paper and research lookup |
| **translation** | `/cf-translation` | `/cf-translation to spanish \| /cf-translation detect` | Language translation and detection |
| **explain** | `/cf-explain` | `/cf-explain <concept> --level beginner` | Explain complex concepts |
| **compare** | `/cf-compare` | `/cf-compare <item1> <item2>` | Compare concepts or items |
| **timeline** | `/cf-timeline` | `/cf-timeline <event> \| /cf-timeline era` | Historical timeline builder |
| **mindmap** | `/cf-mindmap` | `/cf-mindmap create <topic>` | Mind mapping and brainstorming |

---

## Adding New Commands

To add more slash commands:

1. Create new command file: `.claude/commands/marketplace/<category>/cf-<name>.md`
2. Add YAML frontmatter with description and usage
3. Run `./install.sh` to symlink globally
4. Update this catalog with new entry

**Command file format:**

```markdown
---
name: cf-command-name
description: Brief description of what this does
user-invocable: true
---

# Command implementation here
```

---

**Last updated:** 2026-05-11 | **Location:** `.claude/commands/marketplace/`
