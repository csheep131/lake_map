---
name: qwen-hierarchical-context
description: Manage hierarchical instructional context through layered CONTEXT.md files loaded from global, project, and subdirectory levels. Use when Kimi needs to (1) provide project-specific coding conventions and guidelines, (2) establish reusable instructions across multiple projects, (3) create layered memory that becomes more specific deeper in the directory tree, or (4) modularize context with imports.
---

# Qwen-Style Hierarchical Context

Manage AI instructional context through hierarchical `CONTEXT.md` files — layered memory that becomes more specific as you go deeper into the directory tree, exactly like Qwen Code's `QWEN.md` system.

## Quick Start

Create a `CONTEXT.md` in your project root with project-specific instructions:

```markdown
# Project Context

## Coding Standards
- Use TypeScript strict mode
- 2 spaces indentation
- Prefer functional components

## Architecture
- API layer in `src/api/`
- Components in `src/components/`
- Utilities in `src/lib/`
```

## Hierarchical Loading

Context files are loaded from most general to most specific. More specific files override or supplement general ones.

### Loading Order (least to most specific)

1. **Global context**: `~/.config/agents/CONTEXT.md` — default instructions for ALL projects
2. **Project root context**: `./CONTEXT.md` — instructions for the current project
3. **Subdirectory contexts**: `./src/api/CONTEXT.md` — instructions for specific modules

### Concatenation Behavior

All found context files are concatenated into the system prompt with separators indicating their origin. The AI sees them in loading order, with later files taking precedence on conflicting instructions.

## File Format

Context files are standard Markdown with free-form instructions:

```markdown
# Project: My Awesome Library

## General Instructions
- Follow existing coding style for new code
- All functions need JSDoc comments
- Prefer functional programming paradigms

## Coding Style
- Use 2 spaces for indentation
- Interface names prefixed with `I`
- Private members prefixed with `_`
- Always use strict equality (`===`)

## Specific File Notes
### `src/api/client.ts`
- Handles all outbound API requests
- Use `fetchWithRetry` utility for GET requests
- Include robust error handling

## Dependencies
- Avoid new dependencies unless absolutely necessary
- State reason if new dependency is required
```

## Context Imports

Modularize context by importing other Markdown files:

```markdown
# Main Context

@references/coding-style.md
@references/architecture.md
@references/deployment.md
```

The imported files are inlined at the `@path` location.

## Configuration

### Default Filename

By default, look for `CONTEXT.md`. Customize by setting in your environment:

```bash
export KIMI_CONTEXT_FILE="CONTEXT.md,PROJECT.md"
```

### Include Directories

Add extra directories to the workspace context:

```bash
# Via CLI flag
kimi --include-directories /path/to/shared-lib

# Multiple directories
kimi --include-directories /path/lib1,/path/lib2
```

## Commands

### Refresh Context

Force re-scan and reload of all context files:

```
/memory refresh
```

### Show Context

Display the combined instructional context currently loaded:

```
/memory show
```

## Best Practices

### Keep It Relevant

Only include information the AI needs to do its job:

**Include**: coding standards, architecture patterns, file conventions, dependency rules  
**Exclude**: project history, team org charts, setup tutorials for humans

### Progressive Specificity

- **Global**: Language-agnostic best practices, personal preferences
- **Project root**: Tech stack, framework conventions, project structure
- **Subdirectories**: Module-specific patterns, API contracts, implementation details

### Avoid Conflicts

Be explicit about overrides. If a subdirectory needs DIFFERENT rules:

```markdown
# In ./tests/CONTEXT.md

## Override: Testing Standards
- Use 4 spaces for test files (overrides project 2-space rule)
- Test files MUST end with `.test.ts`
```

### File Filtering

Respect `.gitignore` and `.agentsignore` for performance:

```gitignore
# .agentsignore — exclude from context scanning
node_modules/
dist/
*.log
```

## Example: Multi-Project Setup

### Global (`~/.config/agents/CONTEXT.md`)

```markdown
# Global Preferences

## Communication
- Respond in the same language as the user
- Be concise, avoid unnecessary explanations

## General Coding
- Prefer immutable data structures
- Write self-documenting code with clear names
```

### Project (`./CONTEXT.md`)

```markdown
# Lake Map Project

## Stack
- Flutter frontend
- Node.js backend
- PostgreSQL database

## Conventions
- Use named exports, not default exports
- Error messages in German for user-facing text
- English for code comments and internal messages
```

### Module (`./server/CONTEXT.md`)

```markdown
# Server Module

## API Design
- RESTful endpoints under `/api/v1/`
- JSON responses with `{ success, data, error }` wrapper
- Rate limiting: 100 req/min per IP
```

## Comparison with AGENTS.md

| File | Purpose | Scope |
|------|---------|-------|
| `AGENTS.md` | Agent-focused instructions (build steps, test commands, conventions) | Directory + subdirectories |
| `CONTEXT.md` | Hierarchical instructional context (coding style, architecture, preferences) | Global → Project → Subdirectory |

Use both together: `AGENTS.md` for "how to work in this codebase", `CONTEXT.md` for "what the AI should know about this project".
