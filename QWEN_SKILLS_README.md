# Qwen-Style Skills für Kimi CLI

Diese Skills bringen die Kernfunktionen von [Qwen Code](https://github.com/QwenLM/qwen-code) in Kimi CLI — spezialisierte Subagents, hierarchischer Kontext und feingranulare Tool-Permissions.

## Überblick

| Skill | Funktion | Qwen-Äquivalent |
|-------|----------|-----------------|
| `qwen-subagent-delegation` | Spezialisierte Agenten mit eigenen Prompts & Tool-Control | `/agents create`, Subagents |
| `qwen-hierarchical-context` | Hierarchische `CONTEXT.md` Dateien (global → projekt → modul) | `QWEN.md`, `/memory` |
| `qwen-tool-permissions` | Approval-Modes, Allowlists, Blocklists, Path-Rules | `settings.json` permissions |

## Installation

### Option A: Global (empfohlen)

```bash
chmod +x install-qwen-skills.sh
./install-qwen-skills.sh
```

Skills werden nach `~/.config/agents/skills/` kopiert und sind systemweit verfügbar.

### Option B: Projektlokal (bereits aktiv)

Die Skills liegen bereits unter `.agents/skills/` und sind in diesem Projekt automatisch verfügbar.

## Quick-Start

### 1. Hierarchischen Kontext nutzen

Erstelle eine `CONTEXT.md` im Projektroot:

```markdown
# Lake Map Project

## Stack
- Flutter Frontend
- Node.js Backend
- PostgreSQL

## Konventionen
- Deutsche Texte für User-Interface
- Englisch für Code-Kommentare
- Named exports, keine Default exports
```

Kimi lädt diese automatisch als Teil des System-Prompts.

### 2. Subagent für Tests delegieren

```
Lass den testing-expert Unit Tests für das Auth-Modul schreiben.
```

Kimi erkennt die Spezialisierung und spawnt einen Agent mit:
- Fokussiertem Testing-Prompt
- Eingeschränkten Tools (Read, Write, Shell)
- Auto-edit Approval-Mode

Siehe `.agents/skills/qwen-subagent-delegation/references/subagent-examples.md` für 7 fertige Templates.

### 3. Tool-Permissions setzen

```bash
# Nur Analyse, keine Änderungen
kimi --approval-mode plan

# Datei-Edits auto-approven, Shell fragt
kimi --approval-mode auto-edit

# Alles auto-approven (nur in vertrauten Umgebungen)
kimi --approval-mode yolo
```

## Skill-Details

### qwen-subagent-delegation

- **Named Subagents**: Spezialisierte Agenten (testing-expert, code-reviewer, etc.)
- **Fork Subagents**: Parallele Agenten, die Parent-Kontext erben
- **Tool Control**: Allowlists (`tools:`) und Blocklists (`disallowedTools:`)
- **Automatic Delegation**: Kimi wählt automatisch den richtigen Agenten basierend auf der Aufgabenbeschreibung

### qwen-hierarchical-context

- **Loading Order**: Global (`~/.config/agents/CONTEXT.md`) → Projekt (`./CONTEXT.md`) → Modul (`./src/api/CONTEXT.md`)
- **Imports**: Modularisierung via `@path/to/file.md`
- **Progressive Specificity**: Allgemeine Regeln oben, spezifische unten

### qwen-tool-permissions

- **Approval Modes**: `plan` | `default` | `auto-edit` | `yolo`
- **Permission Rules**: `"Bash(git *)"`, `"Read(./secrets/**)"`, `"Edit(/src/**/*.ts)"`
- **Meta-Categories**: `Read` (read+grep+glob+list), `Edit` (edit+write), `Bash` (shell)
- **Bypass Prevention**: Shell-Äquivalente (`cat`, `sed`, `rm`) werden ebenfalls geprüft

## Verfügbare Subagent-Templates

| Template | Zweck | Tools |
|----------|-------|-------|
| `testing-expert` | Unit/Integration Tests | Read, Write, Shell |
| `documentation-writer` | README, API-Docs | Read, Write |
| `code-reviewer` | Security, Performance Review | Read, Grep (plan mode) |
| `react-specialist` | React, Hooks, TypeScript | Read, Write, Shell |
| `python-expert` | Python, FastAPI, Django | Read, Write, Shell |
| `read-only-explorer` | Code-Analyse ohne Änderungen | Read, Grep, Glob (plan mode) |
| `safe-worker` | Shell-Befehle ohne Datei-Mods | Read, Shell (ohne write/edit) |

Alle Templates findest du in:
```
.agents/skills/qwen-subagent-delegation/references/subagent-examples.md
```

## Archiv-Dateien

Für Distribution sind die Skills auch als `.skill`-Archive verfügbar:

- `qwen-subagent-delegation.skill`
- `qwen-hierarchical-context.skill`
- `qwen-tool-permissions.skill`

Diese können mit `unzip` entpackt oder direkt in andere Kimi-Installationen importiert werden.

## Unterschiede zu Qwen Code

| Feature | Qwen Code | Diese Skills |
|---------|-----------|--------------|
| Subagent Storage | `~/.qwen/agents/` | `~/.config/agents/skills/` |
| Context Files | `QWEN.md` | `CONTEXT.md` |
| Approval Mode | `--approval-mode` | `--approval-mode` (gleich) |
| Fork/Parallel | Eingebaut | Via `Agent(run_in_background=true)` |
| Prompt Cache | DashScope-spezifisch | Provider-abhängig |

## Troubleshooting

**Skills werden nicht geladen?**
```bash
# Prüfe, ob das Verzeichnis existiert
ls ~/.config/agents/skills/

# Oder nutze den projektlokalen Pfad
kimi --skills-dir .agents/skills/
```

**Kontext-Dateien werden nicht erkannt?**
- Datei muss `CONTEXT.md` heißen (oder in `KIMI_CONTEXT_FILE` gesetzt)
- Wird automatisch aus Projektroot und Parent-Verzeichnissen geladen

---

*Inspiriert von [Qwen Code](https://github.com/QwenLM/qwen-code) — angepasst für Kimi CLI.*
