## Task Type Library

Select the task type that matches the work. Name the type in each task header.

### TDD Task (standard)

The default task structure for any implementation with a testable behaviour. Every task follows this five-step pattern.

```
Task N: [Component Name]
Files: Create: path/to/file.ts — Test: tests/path/to/file.test.ts

- [ ] Write failing test
- [ ] Run to verify it fails (expected: FAIL — "fn is not defined")
- [ ] Write minimal implementation
- [ ] Run to verify it passes (expected: PASS)
- [ ] Commit: feat: add [specific feature]
```

**Use when:** Any implementation task with a clear behaviour to test. This is the default for all new code.

---

### Walking Skeleton Task

The first task in any plan involving new architecture or integration paths. One thin slice through all layers — enough to prove connectivity, not business logic.

```
Task 1: Walking Skeleton
- Create the minimal handler/service/repo chain
- Wire up the route to return a hardcoded response
- Write one end-to-end test that the path exists
- Confirm the system starts and the test passes
- Commit
```

**Use when:** New architecture, new integration path, or any plan where layers haven't connected before. Always the first task.

---

### Integration Task

Connects two existing subsystems. No new logic — pure wiring. Tests verify data flows through the boundary correctly, not that business logic is correct.

```
Task N: Wire [ServiceA] → [ServiceB]
- Write integration test: serviceA.method() calls serviceB
- Implement the adapter call inside serviceA
- Mock serviceB in unit tests; use a real stub in this test
- Confirm both test layers pass
- Commit
```

**Use when:** Both sides are already implemented independently and need to be connected.

---

### Refactor Task

Structural improvement with no behaviour change. Tests written before the refactor must pass unchanged after it. No new functionality added.

```
Task N: [Refactor description]
- Confirm all existing tests pass before starting
- Make structural change (move methods, rename, split file, extract interface)
- Update imports
- Confirm same tests still pass (no new tests needed)
- Commit
```

**Use when:** A file has grown unwieldy or a structural split is explicitly part of the spec.

---

### Migration Task

Replaces one implementation with another without breaking callers. Parallel-run both, verify equivalence, then remove the old one.

```
Task N: Replace [OldImpl] with [NewImpl]
- Write equivalence test: both return same result for same input
- Add new implementation alongside existing one
- Run both in shadow mode, verify equivalence
- Switch all callers to new implementation
- Delete old implementation
- Confirm all tests pass
- Commit
```

**Use when:** The plan replaces an existing implementation and callers must not break during the transition.
