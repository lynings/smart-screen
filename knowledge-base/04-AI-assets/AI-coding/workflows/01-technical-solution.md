---
description: Technical Solution - Design and document technical approach before implementation
---

# Technical Solution

## Overview

Design the technical approach for a feature before implementation. Produce a solution document that is **reviewable** and **actionable**.

## Workflow

```
Understand requirements → Analyze domain impact → Design solution → Document decisions → Review
```

## Prerequisites

- Feature specification (from L3)
- Domain model understanding (from L2)
- Technology constraints (from L4/rules)

## Inputs

| Input | Required | Source | If Missing |
|-------|----------|--------|------------|
| Feature spec | Yes | `03-specifications/` | Ask for requirements |
| Acceptance criteria | Yes | Feature spec | Clarify with stakeholder |
| UI/UX design | No | Figma/Sketch | Mark UI decisions as TBD |
| Technical constraints | No | Existing code | Document assumptions |

## Steps

### Step 1: Understand Requirements

- Extract core use cases from feature spec
- Identify acceptance criteria
- List out-of-scope items explicitly
- Note NFRs (performance, security, etc.)

### Step 2: Analyze Domain Impact

- Which domain entities are affected?
- New entities or modifications needed?
- Business rules to enforce?
- Integration points with other features?

### Step 3: Design Solution

#### Architecture Decisions

```markdown
## Architecture

### Components
- List new/modified components
- Define responsibilities

### Data Flow
- Input → Processing → Output
- Error handling paths

### Dependencies
- Internal: other features/modules
- External: system APIs, frameworks
```

#### API Design (if applicable)

```markdown
## API Design

### Internal APIs
- Protocol definitions
- Method signatures
- Error types

### System Integration
- ScreenCaptureKit usage
- AVFoundation integration
- Metal pipeline (if needed)
```

### Step 4: Document Decisions

Record key decisions with rationale:

```markdown
## Decisions

### D1: Use ScreenCaptureKit over CGDisplayStream
**Context**: Need screen capture API
**Decision**: ScreenCaptureKit
**Rationale**: 
- Hardware accelerated
- Lower CPU usage
- Better permission handling
**Trade-offs**: Requires macOS 12.3+
```

### Step 5: Identify Risks

```markdown
## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Permission denied at runtime | High | Graceful degradation, clear user guidance |
| Memory pressure on long recordings | Medium | Ring buffer, periodic flush |
```

## Outputs

| Output | Required | Notes |
|--------|----------|-------|
| Technical solution doc | Yes | Markdown, stored in `03-specifications/<feature>/` |
| Architecture diagram | Recommended | Mermaid or ASCII |
| API contracts | If applicable | Protocol definitions |
| Risk assessment | Yes | With mitigations |

## Output Template

```markdown
# Technical Solution: <Feature Name>

## Overview
[One paragraph summary]

## Requirements Reference
- Feature Spec: [link]
- Acceptance Criteria: AC1, AC2, ...

## Architecture

### Components
[Component list with responsibilities]

### Data Flow
[Diagram or description]

## Detailed Design

### [Component 1]
[Design details]

### [Component 2]
[Design details]

## API Design
[Protocol definitions, method signatures]

## Decisions
[Key decisions with rationale]

## Risks
[Risk table with mitigations]

## Out of Scope
[Explicit exclusions]
```

## Validation Checklist

- [ ] All acceptance criteria addressed
- [ ] Architecture follows layered design
- [ ] Dependencies are clearly identified
- [ ] Key decisions documented with rationale
- [ ] Risks identified with mitigations
- [ ] Out-of-scope items listed
- [ ] Solution is reviewable by team
