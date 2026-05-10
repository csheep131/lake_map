# Context File Examples

Complete examples of hierarchical context files for different project types.

## Table of Contents

1. [Flutter/Dart Project](#flutterdart-project)
2. [Python/FastAPI Project](#pythonfastapi-project)
3. [React/TypeScript Project](#reacttypescript-project)
4. [Full-Stack Application](#full-stack-application)
5. [Testing Directory](#testing-directory)

---

## Flutter/Dart Project

### Project Root: `CONTEXT.md`

```markdown
# Project: Lake Map

## General Instructions
- Follow existing code style in the codebase
- Use `flutter_lints` rules (defined in `analysis_options.yaml`)
- Prefer `const` constructors where possible
- Use `final` for variables that don't change

## Architecture
- Uses Clean Architecture with layers: Presentation, Domain, Data
- BLoC pattern for state management
- Dependency injection via `get_it`

## Code Style
- 2 spaces indentation
- Trailing commas for better diffs
- Named parameters for clarity
- Avoid `dynamic` type — use proper generics

## Error Handling
- Use `Result` type from `dartz` for operations that can fail
- Never use bare `try/catch` without specific exception types
- Log errors through the `Logger` service, never `print()`

## Dependencies
- Check `pubspec.yaml` before adding new packages
- Prefer well-maintained packages with >100 GitHub stars
- State reason for new dependency in PR description
```

### API Layer: `lib/api/CONTEXT.md`

```markdown
# API Layer Context

## API Client
- Use `Dio` instance from `lib/core/dio_client.dart`
- All requests must include `Authorization` header via interceptor
- Base URL configured in `.env` file, accessed via `EnvConfig`

## Response Handling
- Parse JSON using `json_serializable` generated models
- Handle 401 by emitting `AuthSessionExpired` event to BLoC
- Retry failed requests with exponential backoff (max 3 retries)

## Endpoint Organization
- One file per domain in `lib/api/endpoints/`
- Class name suffix: `*Endpoints`
- Method naming: `get*`, `create*`, `update*`, `delete*`
```

---

## Python/FastAPI Project

### Project Root: `CONTEXT.md`

```markdown
# Project: API Service

## General Instructions
- Python 3.11+ required
- Use `async/await` for all I/O operations
- Follow PEP 8 style guidelines
- Use `ruff` for linting and formatting

## Type Hints
- All function parameters must have type hints
- All function return types must be annotated
- Use `from __future__ import annotations` for forward references

## Error Handling
- Use custom exception classes in `app/exceptions/`
- HTTP exceptions: use `HTTPException` with appropriate status codes
- Business logic errors: raise domain-specific exceptions

## Database
- SQLAlchemy 2.0 style (ORM and Core)
- Use async session: `AsyncSession`
- Migrations via Alembic
- Always use parameterized queries

## Testing
- pytest for all tests
- Fixtures in `conftest.py`
- Mock external services, never hit real APIs in tests
- Target 80%+ coverage
```

### Models Directory: `app/models/CONTEXT.md`

```markdown
# Models Context

## SQLAlchemy Models
- All models inherit from `Base` in `app/db/base.py`
- Use `Mapped[]` type annotations for columns
- Include `__tablename__` explicitly
- Add `created_at` and `updated_at` timestamps via mixins

## Relationships
- Use `lazy="selectin"` for collections to avoid N+1
- Define relationships on both sides when applicable
- Use type hints with `Mapped[List["OtherModel"]]`

## Example:
```python
class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True)
    items: Mapped[List["Item"]] = relationship(back_populates="owner", lazy="selectin")
```
```

---

## React/TypeScript Project

### Project Root: `CONTEXT.md`

```markdown
# Project: Web Dashboard

## General Instructions
- TypeScript strict mode enabled
- React 18+ with functional components only
- Tailwind CSS for styling
- React Query for server state management

## Component Structure
- One component per file
- Co-locate tests: `Component.tsx` + `Component.test.tsx`
- Use named exports, avoid default exports
- Props interface named `*Props`

## Hooks
- Custom hooks in `hooks/` directory
- Hook naming: `use*`
- Return tuples for stateful hooks: `[state, setState]`

## State Management
- Local state: `useState`, `useReducer`
- Server state: React Query
- Global state: Zustand (only when truly global)

## API Calls
- All API calls go through `lib/api/client.ts`
- Use generated types from OpenAPI spec
- Handle loading and error states consistently
```

### Component Directory: `src/components/CONTEXT.md`

```markdown
# Components Context

## Component Template
```tsx
import { FC } from 'react';

interface ExampleProps {
  title: string;
  onAction: () => void;
}

export const Example: FC<ExampleProps> = ({ title, onAction }) => {
  return (
    <div className="p-4">
      <h2 className="text-lg font-bold">{title}</h2>
    </div>
  );
};
```

## Styling Rules
- Use Tailwind utility classes exclusively
- No inline styles except for dynamic values
- Extract repeated patterns to `classNames` utility
- Responsive: mobile-first approach

## Accessibility
- All interactive elements must be keyboard accessible
- Use semantic HTML elements
- Include `aria-label` for icon-only buttons
- Test with keyboard navigation
```

---

## Full-Stack Application

### Project Root: `CONTEXT.md`

```markdown
# Project: Full-Stack App

## Monorepo Structure
- `apps/web`: React frontend
- `apps/api`: FastAPI backend
- `packages/shared`: Shared types and utilities
- `packages/ui`: Shared UI component library

## Development Workflow
- `pnpm` for package management
- Turborepo for task orchestration
- Changesets for versioning
- Docker Compose for local services

## Communication
- API contracts defined in OpenAPI spec
- Generate TypeScript types from spec
- Never bypass the API — all data flows through endpoints

## Environment
- `.env.local` for local overrides (gitignored)
- `.env.example` with all required variables
- Never commit secrets
```

---

## Testing Directory

### `test/CONTEXT.md`

```markdown
# Testing Context

## Test Organization
- Mirror source structure: `test/unit/*` mirrors `src/*`
- Integration tests: `test/integration/`
- E2E tests: `test/e2e/`

## Naming Conventions
- Test files: `*.test.ts` or `*.spec.ts`
- Describe blocks: use function/class name
- Test names: should describe behavior, not implementation

## Mocking
- Mock external dependencies
- Use factory functions for test data
- Reset mocks between tests

## Coverage
- Unit tests: 80% minimum
- Integration tests: cover critical paths
- E2E tests: cover user journeys
```
