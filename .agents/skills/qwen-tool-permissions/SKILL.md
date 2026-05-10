---
name: qwen-tool-permissions
description: Fine-grained permission control for AI tool usage with approval modes, tool allowlists/blocklists, path-based rules, and meta-categories. Use when Kimi needs to (1) restrict which tools can run without approval, (2) block dangerous operations in sensitive directories, (3) set different permission levels for different tasks, or (4) enforce security policies on file edits and shell commands.
---

# Qwen-Style Tool Permissions

Fine-grained permission control for AI tool usage — approval modes, tool allowlists/blocklists, path-based rules, and meta-categories, matching Qwen Code's `permissions` system.

## Quick Start

Set approval mode via CLI flag:

```bash
# Analyze only — no file changes or commands
kimi --approval-mode plan

# Auto-approve edits, prompt for shell
kimi --approval-mode auto-edit

# Auto-approve everything (dangerous)
kimi --approval-mode yolo
```

## Approval Modes

| Mode | File Edits | Shell Commands | Use Case |
|------|-----------|----------------|----------|
| `plan` | ❌ Blocked | ❌ Blocked | Architecture review, analysis only |
| `default` | ⚠️ Prompt | ⚠️ Prompt | Safe default, manual approval |
| `auto-edit` | ✅ Auto | ⚠️ Prompt | Most coding tasks (recommended) |
| `yolo` | ✅ Auto | ✅ Auto | Trusted environments, automation |

### Mode Inheritance

- Subagents inherit parent's mode by default
- A `plan` parent cannot escalate through subagents
- A `yolo` parent overrides subagent restrictions
- Subagent-specific `approvalMode` only works if parent is equally or less permissive

## Permission Rules

Rules follow the format `"ToolName"` or `"ToolName(specifier)"`.

**Decision priority** (highest first): `deny` > `ask` > `allow` > default

First matching rule wins.

### Rule Syntax

| Rule | Meaning |
|------|---------|
| `"Bash"` | All shell commands |
| `"Bash(git *)"` | Shell commands starting with `git` |
| `"Bash(git push *)"` | Specific git push commands |
| `"Read"` | All read operations (read, grep, glob, list) |
| `"Read(./secrets/**)"` | Read any file under `./secrets/` |
| `"Edit(/src/**/*.ts)"` | Edit TypeScript files under `/src/` |
| `"WriteFile(/tmp/*)"` | Write to `/tmp/` directory |

### Path Pattern Prefixes

| Prefix | Meaning | Example |
|--------|---------|---------|
| `//` | Absolute from filesystem root | `//etc/passwd` |
| `~/` | Relative to home directory | `~/Documents/*.pdf` |
| `/` | Relative to project root | `/src/**/*.ts` |
| `./` | Relative to current working directory | `./secrets/**` |
| (none) | Same as `./` | `secrets/**` |

### Meta-Categories

Some rules automatically cover multiple tools:

| Rule | Tools Covered |
|------|--------------|
| `Read` | `read_file`, `grep_search`, `glob`, `list_directory` |
| `Edit` | `edit` (StrReplaceFile), `write_file` |
| `Bash` / `Shell` | `run_shell_command` |

### Tool Name Aliases

| Alias | Canonical Tool |
|-------|---------------|
| `Bash`, `Shell` | `run_shell_command` |
| `Read`, `ReadFile` | `read_file` |
| `Edit`, `EditFile` | `edit` (StrReplaceFile) |
| `Write`, `WriteFile` | `write_file` |
| `Grep`, `SearchFiles` | `grep_search` |
| `Glob`, `FindFiles` | `glob` |
| `ListFiles` | `list_directory` |
| `Agent` | `task` (Agent tool) |
| `Skill` | `skill` |

## Configuration Examples

### Safe Developer Setup

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm run *)",
      "Read(//Users/alice/code/**)"
    ],
    "ask": [
      "Bash(git push *)",
      "Edit"
    ],
    "deny": [
      "Bash(rm -rf *)",
      "Read(.env)",
      "WriteFile(.env)"
    ]
  }
}
```

### Read-Only Explorer

```json
{
  "permissions": {
    "allow": ["Read", "Bash(ls *)", "Bash(find *)"],
    "deny": ["Edit", "WriteFile", "Bash(rm *)", "Bash(mv *)"]
  }
}
```

### CI/CD Automation (Yolo for trusted scripts)

```json
{
  "permissions": {
    "allow": [
      "Bash",
      "Edit",
      "WriteFile",
      "Read"
    ],
    "deny": [
      "Bash(curl * | bash)",
      "WriteFile(/etc/**)"
    ]
  }
}
```

## Shell Command Bypass Prevention

Permission rules for `Read`, `Edit`, and shell operations are ALSO enforced when the agent runs equivalent shell commands:

- If `Read(./.env)` is in `deny`, the agent cannot use `cat .env` either
- If `Edit(/src/**/*.ts)` is in `allow`, `sed -i` on those files is permitted
- Unknown/safe commands (e.g., `git`) are unaffected by file rules

Supported shell enforcement: `cat`, `grep`, `curl`, `wget`, `cp`, `mv`, `rm`, `chmod`, and more.

## Subagent Permission Inheritance

Subagents inherit permissions from parent with these rules:

```
Parent: yolo → Subagent: yolo (cannot restrict)
Parent: auto-edit → Subagent: auto-edit or default
Parent: default → Subagent: default or plan
Parent: plan → Subagent: plan only
```

Override in subagent config:

```yaml
---
name: cautious-reviewer
approvalMode: plan
tools:
  - read_file
  - grep_search
---

You are a code reviewer. Analyze only, do not modify.
```

## Best Practices

### Principle of Least Privilege

Start restrictive, expand as needed:

1. Begin with `plan` mode for new projects
2. Move to `default` for active development
3. Use `auto-edit` for trusted, repetitive tasks
4. Reserve `yolo` for CI/CD and automation

### Protect Sensitive Files

Always deny access to:

```json
{
  "deny": [
    "Read(.env)",
    "Read(.env.local)",
    "Read(*.pem)",
    "Read(*.key)",
    "Read(./secrets/**)",
    "Read(~/.ssh/**)",
    "Read(//etc/shadow)"
  ]
}
```

### Protect Destructive Commands

Block dangerous shell patterns:

```json
{
  "deny": [
    "Bash(rm -rf /)",
    "Bash(rm -rf /*)",
    "Bash(dd *)",
    "Bash(mkfs*)",
    "Bash(> /dev/*)",
    "Bash(curl * | bash)"
  ]
}
```

### Directory-Based Rules

Use path patterns to restrict operations by sensitivity:

```json
{
  "permissions": {
    "allow": [
      "Edit(/src/**)",
      "WriteFile(/src/**)",
      "Bash(./scripts/**)"
    ],
    "ask": [
      "Edit(/config/**)",
      "Bash(./deploy.sh)"
    ],
    "deny": [
      "Edit(/production/**)",
      "WriteFile(/production/**)"
    ]
  }
}
```

## Environment Variables

Override permissions via environment:

```bash
# Set default approval mode
export KIMI_APPROVAL_MODE=auto-edit

# Deny specific tools
export KIMI_DENY_TOOLS="rm -rf,dd,mkfs"
```

## Migration from Legacy Settings

| Legacy | New Permission Rule |
|--------|---------------------|
| `tools.allowed` | `permissions.allow` |
| `tools.exclude` | `permissions.deny` |
| `tools.core` | `permissions.allow` (allowlist) |
| `approvalMode` | `tools.approvalMode` |
