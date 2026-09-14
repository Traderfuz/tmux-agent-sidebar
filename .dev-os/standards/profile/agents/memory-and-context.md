<!-- source: profile:general -->
<!-- EXTRACTED — do not edit directly. Edit source at profiles/general/standards/agents/memory-and-context.md and re-run profile-sync. -->
# Memory and Context Standards

## Overview

This standard defines how to architect memory systems and manage context windows for AI agents. Memory and context management is the primary determinant of agent performance at scale — not model capability. By 2025, frontier models are sufficiently capable for most production tasks; the bottleneck is the quality, relevance, and freshness of the information placed in front of them. Getting memory architecture wrong produces context rot, retrieval failures, and agents that degrade over long sessions regardless of the model used.

## Scope

**Covers:** Memory architecture selection, context window management strategies, retrieval design, memory namespacing, and pruning heuristics for AI agents.

**Does NOT cover:** Tool design for memory tool implementations — see `tool-design.md`. Agent loop structure and observation formatting — see `agent-loop-design.md`.

## Principles

**Context engineering is the discipline.** By 2025, model intelligence is rarely the bottleneck; context quality is. Choosing the right information to place in front of the model at the right moment produces more reliable outputs than scaling to a larger model. "Claude is already smart enough — intelligence is not the bottleneck, context is."

**Smallest set of high-signal tokens.** The guiding principle for every context management decision is: what is the minimum set of tokens that maximizes the probability of the desired outcome? Every token that does not materially contribute to the next correct step is a token that dilutes signal, consumes budget, or crowds out a more relevant piece of information.

**Explicit memory type selection.** Choose the memory architecture intentionally for each class of information. Mixing episodic and semantic storage without clear ownership, or allowing in-context memory to grow unboundedly, produces context rot — a gradual degradation where the context window fills with stale, redundant, or irrelevant content that competes with current instructions.

**Retrieval precision over recall.** Retrieving too much context is as harmful as retrieving too little. A broad semantic neighborhood retrieval that returns 50 loosely related documents pollutes working memory as effectively as no retrieval at all. Prefer fewer, highly relevant tokens over large retrieval sets that include the correct document somewhere in the middle.

## Rules

### R1 — Context Rot: Why Context Management Is Non-Negotiable

Context rot is the accumulation of low-signal, stale, or irrelevant tokens in the context window. It is not a hypothetical concern — it is the dominant failure mode for agents in long-running sessions.

Four mechanisms drive context rot:

- **Attention cost.** Transformer attention has O(n²) pairwise relationship cost. As context length grows, recall accuracy for early tokens decreases — the model's effective attention is diluted across a longer sequence.
- **Recency bias.** Long contexts cause the model to over-weight recent tokens and under-weight early instructions. A system prompt placed at position 0 in a 180k-token context competes against 180k tokens of recency pressure.
- **Context pollution.** One irrelevant document can crowd out a critical instruction. The model does not know which tokens are load-bearing; it distributes attention across all of them.
- **The 200k ceiling is not a target.** The 200k token context window is a hard upper bound, not a design goal. Effective working range — the range in which recall accuracy is high and attention is not diluted — is substantially smaller. Design for effective range, not maximum capacity.

Context management is not an optimization — it is a correctness requirement.

### R2 — The 4 Memory Types

Every piece of information an agent needs must be assigned to exactly one of four memory types. Leaving assignment implicit is the primary cause of context rot and retrieval misses.

**1. In-Context Memory (Working Memory)**

The current messages array — everything in the active context window at inference time. Fastest access; zero retrieval latency; bounded by the context window.

- Managed via: messages array lifecycle, system prompt content, tool result inclusion
- Failure mode: unbounded growth — old tool results accumulate and clog working memory with resolved subtask outputs
- Rule: prune tool results more than N turns old; keep only the final result of each tool call chain, not intermediate outputs

**2. Episodic Memory**

Timestamped records of past events — prior session summaries, interaction history, sequences of actions taken. Answers "what happened."

- Stored in: vector database with `created_at` timestamps; indexed by session ID and time range
- Retrieved by: `(user_id, session_id)` tuple + time range query, OR semantic similarity to current query when recalling past behavior
- Use when: the agent needs to remember what happened in a prior session, what the user previously decided, or what steps were already taken in an interrupted workflow

**3. Semantic Memory**

Generalized facts, extracted patterns, domain knowledge, and learned truths — not tied to any specific event. Answers "what is true."

- Stored in: vector embeddings in a vector database, indexed by content and domain tag
- Retrieved by: semantic similarity search against the current query or task description
- Use when: the agent needs domain knowledge beyond the training cutoff, product-specific facts, or extracted patterns from past interactions

**4. Procedural Memory**

Skills, decision rules, and learned behaviors — the "how to do X" layer. Answers "how to act."

- Stored in: system prompt instructions, fine-tuned model weights, DAG/workflow definitions
- Managed via: system prompt engineering for runtime rules; fine-tuning for deeply embedded behaviors
- Use when: the agent needs to apply a consistent skill, follow a fixed process, or maintain a behavioral constraint across many independent sessions

Every information item in an agent's design must be explicitly placed into one of these four types. "We'll just put it in context" is not a valid assignment.

### R3 — The 4 Context Management Strategies

Context management is active work — it does not happen automatically. Select the appropriate strategy (or combination) for each agent's session lifecycle.

**Strategy 1: Just-In-Time (JIT) Loading**

Maintain references (file paths, document IDs, URLs, database keys) in context. Fetch full content only when a specific step requires it, using tools. Never pre-load all documents into context at session start.

- OFF: loading 500 documents into context at session initialization
- ON: maintaining a reference index in context; fetching individual documents via `glob`, `read_file`, or `db_query` tools only when the current reasoning step requires their content

```typescript
// OFF-STANDARD: Pre-loading all files into context at session start
const allFiles = await Promise.all(filePaths.map(readFile));
const context = allFiles.join('\n\n'); // Massive context bloat before a single step runs

// ON-STANDARD: JIT loading — maintain references; fetch only what this step needs
const fileIndex = await agent.tools.glob({ pattern: '**/*.ts', cwd: 'src/api' });
// fileIndex contains paths only — no content yet
// Agent fetches individual files via read_file tool only when it needs to reason about them
```

```python
# OFF-STANDARD: Pre-loading all documents
all_docs = [read_file(p) for p in file_paths]
context = "\n\n".join(all_docs)  # Context bloat before first step

# ON-STANDARD: JIT loading — fetch on demand
file_index = agent.tools.glob(pattern="**/*.py", cwd="src/")
# Agent calls read_file(path) only when a specific file is needed for the current step
```

**Strategy 2: Compaction**

Summarize context when it approaches the working memory limit. Preserve decisions and unresolved issues; discard completed tool outputs and intermediate reasoning steps.

- Trigger condition: context exceeds 70% of the model's effective working range, or before any tool operation expected to return large output
- Preserve: key decisions made, current plan state, open questions and blockers
- Discard: successful tool call outputs after their result is incorporated; intermediate planning steps that led to a confirmed decision

```typescript
// ON-STANDARD: Compact before context limit is reached
const COMPACTION_THRESHOLD = Math.floor(MAX_CONTEXT_TOKENS * 0.7);

if (estimateTokens(messages) > COMPACTION_THRESHOLD) {
  const summary = await llm.complete({
    prompt: `Summarize this conversation.
Preserve: key decisions made, current plan state, open questions.
Discard: completed tool outputs, resolved intermediate steps.

${formatMessages(messages)}`,
  });
  messages = [
    systemMessage,
    { role: 'user', content: `Previous context summary:\n${summary}\n\nContinue from here.` },
  ];
}
```

**Strategy 3: Structured Note-Taking**

The agent maintains an external notes file (JSON or markdown) outside the context window. It reads notes at the start of each step and writes updates after each significant finding or decision. State persists across context resets and session breaks without occupying working memory between steps.

```typescript
// ON-STANDARD: External notes file maintained via tools — state outside context window
const notes = JSON.parse(await agent.tools.read_file({ path: 'agent-notes.json' }));

// ... agent reasoning step ...

await agent.tools.write_file({
  path: 'agent-notes.json',
  content: JSON.stringify({
    decisions: [...notes.decisions, newDecision],
    progress: { ...notes.progress, currentPhase: 'validation' },
    openQuestions: notes.openQuestions.filter(q => q.id !== resolvedId),
  }),
});
```

**Strategy 4: Sub-Agent Isolation**

Delegate specialized subtasks to sub-agents with dedicated, isolated context windows. The sub-agent receives only the information relevant to its subtask. It returns a distilled summary (1–2k tokens maximum) — not its full tool call trace or conversation history. The orchestrating agent's context window receives only the summary.

```typescript
// ON-STANDARD: Sub-agent returns distilled summary, not full trace
const subAgentResult = await runSubAgent({
  task: 'Audit the authentication module for security issues',
  context: authModuleFiles, // isolated, scoped context
  outputConstraint: 'Return a structured summary under 1500 tokens: findings, severity, recommended fixes.',
});

// orchestrator receives summary only — not the sub-agent's full reasoning history
messages.push({ role: 'tool', content: subAgentResult.summary });
```

### R4 — Hybrid Retrieval Rule

Pure semantic vector search misses exact keyword matches — specific function names, error codes, variable names, and unique identifiers fall outside the dense vector neighborhood when their surrounding context is not semantically similar to the query. Pure keyword (BM25) search misses semantic similarity — paraphrased queries that mean the same thing but use different words produce no results.

**MUST use hybrid retrieval:** BM25 keyword search combined with vector semantic search, fused using Reciprocal Rank Fusion (RRF, k=60).

RRF formula: `score(d) = Σ 1/(k + rank_i(d))` where k=60 is the RRF constant, and the sum is taken over all ranked lists that include document d.

k=60 is the established default from Cormack et al. (2009). It down-weights rank differences at the top of each list, preventing a single retriever that ranks a document first from dominating the fused score.

```python
# ON-STANDARD: Hybrid retrieval with RRF fusion
from langchain.retrievers import BM25Retriever, EnsembleRetriever

bm25_retriever = BM25Retriever.from_documents(docs)
bm25_retriever.k = 10

vector_retriever = vector_store.as_retriever(
    search_type="similarity",
    search_kwargs={"k": 10},
)

# EnsembleRetriever uses RRF internally when combine_documents is set to rrf
hybrid_retriever = EnsembleRetriever(
    retrievers=[bm25_retriever, vector_retriever],
    weights=[0.4, 0.6],  # Tune based on query type distribution in production
)

results = hybrid_retriever.invoke("authentication middleware error handling")
# Returns fused results: exact keyword matches AND semantically similar documents
```

```typescript
// ON-STANDARD: Hybrid retrieval in TypeScript
import { EnsembleRetriever } from 'langchain/retrievers/ensemble';

const hybridRetriever = new EnsembleRetriever({
  retrievers: [bm25Retriever, vectorRetriever],
  weights: [0.4, 0.6],
});

const results = await hybridRetriever.invoke('authentication middleware error handling');
```

### R5 — Memory Namespacing

Memory stored without namespacing is shared global state. One user's episodic memory contaminates another user's retrieval results; one session's intermediate state bleeds into the next session's context.

**MUST namespace all memory by at minimum `user_id`.** For agents serving multiple independent sessions per user, namespace by `(user_id, session_id)` tuple.

```typescript
// OFF-STANDARD: Flat global memory store
await memoryStore.add({ content: userPreferences, embedding: embed(userPreferences) });

// ON-STANDARD: Namespaced by (user_id, session_id)
await memoryStore.add({
  namespace: { userId: user.id, sessionId: session.id },
  content: userPreferences,
  embedding: embed(userPreferences),
  createdAt: new Date().toISOString(),
});

// Retrieval is scoped to the same namespace — no cross-user leakage
const memories = await memoryStore.search({
  namespace: { userId: user.id, sessionId: session.id },
  query: currentQuery,
  topK: 5,
});
```

For OpenAI Sessions: per-session state is auto-namespaced by the Sessions API. Use `SQLiteSession` for single-instance persistence; use `RedisSession` for distributed or multi-process agents.

### R6 — Pruning Heuristic

Memories that are never retrieved are noise. Trust in a memory degrades when it is contradicted by newer information or corrected by the user. Both conditions — staleness and contradicted trust — justify archiving.

**Archive** (do not delete) memories meeting both conditions:
- Not retrieved in the past 90 days AND
- Trust score below 0.5 (trust degrades on contradiction or user correction)

**Never delete memories outright.** Archive with an `archived_at` timestamp for audit trail and rollback capability. The distinction matters: deletion destroys information that may be needed for debugging retrieval failures or understanding why the agent believed something at a point in time.

```typescript
// ON-STANDARD: Archive stale/low-trust memories — never hard delete
const staleMemories = await memoryStore.query({
  lastRetrievedBefore: daysAgo(90),
  trustScoreLessThan: 0.5,
  archived: false,
});

for (const memory of staleMemories) {
  await memoryStore.update(memory.id, {
    archived: true,
    archivedAt: new Date().toISOString(),
    archiveReason: 'stale_low_trust',
  });
}
```

## Anti-patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Pre-loading all documents into context at session start | Massive upfront token cost; context rot begins immediately; recent tokens dominate over early instructions placed at position 0 | JIT loading: maintain references, fetch individual documents with tools only when a specific step requires their content |
| Using only vector semantic search for retrieval | Exact matches — function names, error codes, specific IDs — are missed when the vector neighborhood does not include them; pure semantic search cannot recover an exact identifier it never learned to embed | Hybrid retrieval: BM25 keyword + vector semantic search fused with Reciprocal Rank Fusion (RRF, k=60) |
| Storing all user and session memory in a single shared namespace | Memory from one user contaminates another user's retrieval results; session-specific context bleeds across sessions producing incorrect personalization | Namespace memory by `(user_id, session_id)` tuple; never use a flat global store for multi-user or multi-session agents |
| Keeping all tool results in context indefinitely | Old tool outputs accumulate across turns; context fills with resolved subtask results that have no bearing on remaining work; recency bias causes the model to ignore early instructions | Prune tool results after their output has been incorporated into decisions; retain only the current step's relevant results |
| Passing full agent conversation traces to sub-agents | Sub-agents receive irrelevant history that crowds their working memory; parent agent context balloons with the sub-agent's full trace on return | Summarize completed work to 1–2k tokens; pass summary plus current subtask to sub-agent; parent receives only the distilled result |

## Deviation Guidance

MAY skip hybrid retrieval for prototype or low-volume agents (fewer than 1,000 documents) where BM25 keyword search alone is sufficient and the latency and infrastructure cost of embedding generation plus vector search is not justified by the use case. MUST upgrade to hybrid retrieval when document count exceeds 1,000 or when exact-match retrieval failures are observed in production.

MAY use a single memory namespace for internal-only agents where all users share the same identity context, there is no multi-tenancy requirement, and cross-contamination between sessions is not a risk. MUST use namespaced memory for any agent that handles data from multiple independent users or from multiple independent sessions for the same user.

## Compliance Test

1. Is each memory type (in-context, episodic, semantic, procedural) explicitly mapped to a storage mechanism and retrieval strategy — not left as an implicit "we'll just put it in context"? (Y/N)
2. Is JIT loading used for documents — fetched on demand via tools rather than pre-loaded into context at session start? (Y/N)
3. Is a compaction or pruning strategy defined with an explicit trigger condition — either a context percentage threshold or a turn count limit? (Y/N)
4. Is retrieval implemented as hybrid (BM25 keyword + vector semantic search) — not pure keyword or pure semantic alone? (Y/N)
5. Is memory namespaced by at least `user_id` to prevent cross-user contamination? (Y/N)

## References

- LangChain memory taxonomy — in-context, episodic, semantic, and procedural memory types; `EnsembleRetriever` with RRF fusion
- Anthropic, "Effective Context Engineering" — AWS re:Invent 2025 — context quality as the primary agent performance lever
- OpenAI Sessions API documentation — `SQLiteSession`, `RedisSession`, compaction session, per-session namespacing
- Robertson & Zaragoza (2009), "The Probabilistic Relevance Framework: BM25 and Beyond" — BM25 algorithm and scoring
- Cormack, Clarke & Buettcher (2009), "Reciprocal Rank Fusion outperforms Condorcet and individual Rank Learning Methods" — RRF formula and k=60 constant derivation
