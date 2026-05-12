---
name: qwen-subagent-delegation
description: Create and delegate tasks to specialized subagents with focused system prompts, controlled tool access, and independent execution. Use when Kimi needs to (1) spawn specialized agents for testing, documentation, code review, or refactoring, (2) work on multiple tasks in parallel with context isolation, (3) restrict tool access for security or focus, or (4) automatically delegate tasks based on specialization.
---

# Qwen-Style Subagent Delegation

Delegate focused work to specialized AI subagents, each with task-specific prompts, controlled tools, and independent execution — just like Qwen Code's subagent system.

## Quick Start

To delegate to a subagent, use the `Agent` tool with a focused prompt and explicit role:

```
Agent(
  description="3-5 word task summary",
  prompt="""You are a [specialist role].

Task: [specific task description]

Constraints:
- Only use [allowed tools]
- Do not [forbidden actions]
- Return [expected output format]

[Additional context]"""
)
```

## Core Concepts

### Named Subagents (Specialized)

Create reusable, specialized agents for common workflows. Each has its own system prompt and tool configuration.

**Key properties:**
- **Fresh context** — starts without parent conversation history
- **Custom system prompt** — defines expertise and behavior
- **Controlled tools** — allowlist or blocklist specific tools
- **Blocking execution** — parent waits for completion

### Fork Subagents (Parallel)

For tasks that need current conversation context, spawn parallel agents that inherit the parent's full context.

**Key properties:**
- **Context inheritance** — gets parent's full conversation history
- **Parent system prompt** — shares system prompt for cache efficiency
- **Background execution** — parent continues immediately
- **Use for**: parallel research, multi-module investigation, background tasks

## Predefined Agent Templates

See [references/agent-templates.md](references/agent-templates.md) for complete, copy-paste-ready subagent configurations.

Quick reference of available templates:

| Agent | Purpose | Key Tools |
|-------|---------|-----------|
| `testing-expert` | Unit/integration tests | Read, Write, Shell |
| `documentation-writer` | README, API docs | Read, Write |
| `code-reviewer` | Security, performance review | Read, Grep |
| `react-specialist` | React components, hooks | Read, Write, Shell |
| `python-expert` | Python/FastAPI/Django | Read, Write, Shell |
| `explore-only` | Read-only codebase exploration | Read, Grep, Glob |
| `safe-worker` | No file modifications | Read, Grep, Glob, Shell(read-only) |

## Tool Control

### Allowlist (tools)

When specified, the subagent can ONLY use listed tools:

```yaml
# In agent config or prompt
tools:
  - ReadFile
  - Grep
  - Glob
```

### Blocklist (disallowedTools)

Remove specific tools while inheriting all others:

```yaml
# In agent config or prompt
disallowedTools:
  - WriteFile
  - StrReplaceFile
```

### Permission Modes

Control approval behavior per subagent:

| Mode | Behavior | Use Case |
|------|----------|----------|
| `plan` | Analyze only, no changes | Code review, architecture analysis |
| `default` | Interactive approval | Sensitive operations |
| `auto-edit` | Auto-approve file edits | Most subagents (recommended) |
| `yolo` | Auto-approve everything | Trusted environments only |

**Rule**: Parent's permissive modes take priority. A yolo parent cannot be restricted by a plan-mode subagent.

## Best Practices

### Single Responsibility

Each subagent should have ONE clear, focused purpose.

**Good**: `testing-expert` — writes comprehensive unit tests  
**Bad**: `general-helper` — does testing, docs, review, and deployment

### Clear Descriptions

Write descriptions that help the main AI choose the right agent:

**Good**: `Reviews code for security vulnerabilities, performance issues, and maintainability`  
**Bad**: `A helpful code reviewer`

### Specific System Prompts

Include:
1. **Expertise areas** — specific technologies and patterns
2. **Step-by-step workflow** — numbered approach for consistency
3. **Output standards** — expected format and quality criteria

### Security

- Use `tools` allowlist to limit subagent capabilities
- Use `plan` mode for agents that should never modify files
- Never include secrets in agent configurations
- Audit subagent actions through execution logs

## Automatic Delegation

The main AI proactively delegates when:
- Task description matches a subagent's specialization
- Phrases like "write tests", "review code", "update docs" are used
- Multiple independent tasks can run in parallel

To encourage delegation, mention the specialist by name or describe the task type explicitly:

- "**Have the testing-expert** create unit tests for..."
- "**Get the documentation-writer** to update the README..."
- "**Let the code-reviewer** check this for security issues..."

## Limitations

- Subagents cannot create further subagents (recursive fork prevention)
- Fork results may not auto-feed back into main conversation
- Concurrent file modifications from multiple subagents may conflict
