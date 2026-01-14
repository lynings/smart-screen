---
description: Git Commit Standards - Semantic commit format, types and conventions
alwaysApply: true
---

# Git Commit Standards

## Semantic Commit Messages

### Format

```
<type>(<scope>): <subject>

[optional body]
```

### Components

#### Type (Required)

| Type | Description |
|------|-------------|
| `feat` | New feature for the user |
| `fix` | Bug fix for the user |
| `docs` | Documentation changes only |
| `style` | Formatting (no code change) |
| `refactor` | Code restructuring (no behavior change) |
| `test` | Adding or updating tests |
| `chore` | Build, config, tooling changes |
| `perf` | Performance improvements |

#### Scope (Required)

Use feature or module name:
- `recording` - Recording feature
- `export` - Export feature
- `enhancement` - Enhancement pipeline
- `editor` - Timeline editor
- `ui` - UI components
- `core` - Core infrastructure
- `test` - Test infrastructure

#### Subject (Required)

- Use imperative mood ("add" not "added")
- Lowercase first letter
- No period at the end
- Max 50 characters

## Examples

### Feature

```
feat(recording): add region selection overlay

- Implement draggable selection handles
- Add keyboard shortcuts for precise control
- Support retina display coordinates
```

### Bug Fix

```
fix(export): resolve audio sync drift in long recordings
```

### Documentation

```
docs(readme): update installation instructions
```

### Refactor

```
refactor(recording): extract capture configuration to separate struct
```

### Test

```
test(recording): add unit tests for permission handling
```

### Chore

```
chore(deps): update ScreenCaptureKit to latest API
```

### Performance

```
perf(enhancement): optimize Metal shader for auto zoom rendering
```

## Commit Body Guidelines

When body is needed:
- Explain **what** and **why**, not how
- Wrap at 72 characters
- Separate from subject with blank line

```
feat(recording): add system audio capture support

System audio capture requires virtual audio driver (BlackHole).
This commit adds:
- Detection of available virtual audio devices
- User guidance for driver installation
- Audio routing configuration UI
```

## Best Practices

### DO ✅

- Write atomic commits (one logical change)
- Use present tense imperative
- Reference issue numbers in body if applicable
- Group related changes

### DON'T ❌

- Mix unrelated changes
- Use vague messages ("fix bug", "update code")
- End subject with period
- Exceed 50 chars in subject

## Branch Naming

### Format

```
<type>/<short-description>
```

### Examples

- `feat/recording-engine`
- `fix/export-audio-sync`
- `refactor/capture-architecture`
- `test/enhancement-pipeline`

## PR/MR Titles

Follow same convention as commits:

```
feat(recording): implement screen capture engine
```
