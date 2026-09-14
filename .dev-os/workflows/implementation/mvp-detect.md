# MVP Detection Workflow

Analyzes a specification to identify the minimum viable product (MVP) scope - the core tasks that deliver the primary user value.

## When to Use

This workflow is invoked during `create-tasks` to add priority labels (P1/P2/P3) to tasks.


Do not use when the spec has fewer than 10 tasks — MVP detection overhead is not worth it for small specs. Do not use when the user has already specified which tasks are P1 manually.
## MVP Philosophy

The MVP (Minimum Viable Product) is the smallest set of features that:
1. Delivers core user value
2. Is functional and deployable
3. Can be validated with real users
4. Provides foundation for future iterations

## Detection Process

### Step 1: Read and Analyze the Spec

Read the specification to understand:

```bash
# Read the spec
cat product/specs/[this-spec]/spec.md

# Read requirements if available
cat product/specs/[this-spec]/planning/requirements.md
```

**Key information to extract:**
- Primary user goal: What problem does this solve?
- Core user journey: What's the minimum path to value?
- Success criteria: What defines "done" for the MVP?

### Step 2: Identify Core User Journey

Map the minimum path from user action to user value:

**Example: User Authentication Spec**

**Core Journey (MVP/P1):**
1. User visits site → Sees login form
2. User enters credentials → System authenticates
3. Authentication succeeds → User logged in, redirected

**Not in MVP (P2/P3):**
- Password reset flow
- "Remember me" functionality
- Email verification
- OAuth providers
- Two-factor authentication

### Step 3: Dependency Analysis

Identify blocking dependencies:

```
Database Models → API Endpoints → UI Components
     ↓                ↓              ↓
   [MUST]           [MUST]         [MUST]
```

**Rules:**
1. If B depends on A, and B is P1, then A must be P1
2. If A has no dependents and isn't in core journey, it's P2 or P3
3. UI cannot be P1 if backend isn't P1 (unless mock data)

### Step 4: Task Priority Labeling

Assign priorities to each task:

| Priority | Label | Description | Percentage |
|----------|-------|-------------|------------|
| **P1** | MVP | Core user journey, blocking dependencies | ~40% |
| **P2** | Important | Enhances core value, commonly needed | ~35% |
| **P3** | Nice-to-have | Polish, edge cases, "nice to have" | ~25% |

**Default threshold:** 40% of tasks should be P1 (configurable)

### Step 5: Task Group Priority

Each task group can also have an overall priority:

```markdown
#### Task Group 1: Data Models and Migrations
**Dependencies:** None
**Priority:** P1 (MVP)
**MVP Tasks:** 3 of 5 tasks are P1
```

**Task group MVP criteria:**
- If ANY task in group is P1 and blocking, group is P1
- If group has no P1 tasks but is important, group is P2
- If group is purely polish/enhancement, group is P3

### Step 6: Generate Priority Report

Create a priority summary:

```markdown
# MVP Priority Analysis

**Spec:** [spec-name]
**Date:** [ISO 8601 date]

## Summary

- **Total Tasks:** [X]
- **P1 (MVP):** [X] tasks ([X]%)
- **P2 (Important):** [X] tasks ([X]%)
- **P3 (Nice-to-have):** [X] tasks ([X]%)

## Core User Journey (MVP)

[Describe the minimum path to user value]

## Task Breakdown by Priority

### P1 Tasks (MVP - Ship First)

- [Task 1]
- [Task 2]
- ...

### P2 Tasks (Important - Ship Second)

- [Task 1]
- [Task 2]
- ...

### P3 Tasks (Nice-to-have - Ship Last)

- [Task 1]
- [Task 2]
- ...
```

## MVP Detection Heuristics

### Backend Features

| Feature | P1 (MVP) | P2 | P3 |
|---------|----------|-----|-----|
| Core data models | ✅ | | |
| Basic CRUD operations | ✅ | | |
| Authentication | ✅ | | |
| Authorization | ✅ | | |
| Input validation | ✅ | | |
| Error handling | ✅ | | |
| Advanced queries | | ✅ | |
| Caching | | | ✅ |
| Rate limiting | | | ✅ |
| Pagination | | ✅ | |
| Soft delete | | | ✅ |
| Audit logging | | | ✅ |
| Background jobs | | ✅ | |
| Webhooks | | | ✅ |

### Frontend Features

| Feature | P1 (MVP) | P2 | P3 |
|---------|----------|-----|-----|
| Core UI components | ✅ | | |
| Basic forms | ✅ | | |
| Navigation | ✅ | | |
| Mobile responsive | ✅ | | |
| Loading states | ✅ | | |
| Error messages | ✅ | | |
| Success feedback | ✅ | | |
| Animations | | | ✅ |
| Dark mode | | | ✅ |
| Accessibility (a11y) | ✅ | | |
| SEO basics | ✅ | | |
| Advanced SEO | | | ✅ |
| Analytics | | | ✅ |
| A/B testing | | | ✅ |

### Documentation

| Feature | P1 (MVP) | P2 | P3 |
|---------|----------|-----|-----|
| API documentation | ✅ | | |
| User guide | | ✅ | |
| Admin guide | | | ✅ |
| Contributing guide | | | ✅ |

## Examples

### Example 1: Blog Platform

**Spec:** Blog platform with posts, comments, tags, search, analytics

**P1 (MVP) Tasks:**
- Post model (title, content, author, date)
- Create post API
- List posts API
- Post detail page
- Simple admin form to create posts
- Basic styling

**Core Journey:** Write post → View post → (MVP complete!)

**P2 Tasks:**
- Comment system
- Tag system
- Rich text editor
- Post scheduling

**P3 Tasks:**
- Search functionality
- Analytics dashboard
- Social sharing
- Email subscriptions

### Example 2: E-commerce Checkout

**Spec:** Shopping cart, checkout flow, payment processing, order history

**P1 (MVP) Tasks:**
- Product catalog
- Add to cart
- Cart page
- Guest checkout
- Payment integration
- Order confirmation
- Order history page

**Core Journey:** Browse → Add to cart → Checkout → Pay → (MVP complete!)

**P2 Tasks:**
- User accounts
- Saved addresses
- Order tracking
- Email notifications

**P3 Tasks:**
- Wishlist
- Product recommendations
- Reviews and ratings
- Coupon codes

## Configuration

```yaml
mvp_mode_enabled: true           # Enable priority labeling
mvp_auto_detect: true            # AI auto-detects MVP tasks
mvp_default_threshold: 0.4       # Max 40% should be P1
mvp_require_merge: true          # Require MVP merge before continuing
```

## Notes

- Priority labels are added as comments in tasks.md
- P1/P2/P3 format is compatible with markdown (treated as comments by most renderers)
- Thresholds are guidelines, not hard rules
- User can manually adjust priorities after auto-detection
- MVP mode is optional - users can implement all tasks at once

## Display

MVP detection result:

```
MVP Detection complete
  P1 tasks (must-ship): [N]
  P2 tasks (post-MVP):  [N]
  P3 tasks (optional):  [N]
  Mode: [MVP / Full]
```
