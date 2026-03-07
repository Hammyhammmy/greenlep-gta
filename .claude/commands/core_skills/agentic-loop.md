# Agentic Loop — Portable Reference

A reusable pattern for building AI agents that iterate toward a complete
answer rather than making a single pass. Works with any domain, any LLM
backend, any retrieval source.

---

## The Core Idea

Most "AI-powered" apps are single-pass pipelines:

```
input → retrieve → LLM → output
```

An agentic loop adds a decision step at the end of each pass: **should we
stop, or search for something else?**

```
input → retrieve → LLM → [is the answer complete?]
           ↑                         |
           └──── no: search for X ───┘
                 yes: synthesize → output
```

The LLM never controls execution. It only answers two language questions:

| Decision | Question asked to LLM | Valid replies |
|----------|----------------------|---------------|
| **Reformulate** | "This search returned nothing — rephrase it" | new query string, or `SAME` |
| **Gap detect** | "Do these findings fully answer the question?" | `COMPLETE`, or a follow-up query |

Python controls all the mechanics: when to loop, when to stop, how to
combine results, how to deduplicate. The LLM only does what it's good at —
understanding language.

---

## Why This Works With Small Models

A 1–3B parameter model cannot reliably decide *how* to run a pipeline.
But it can reliably answer "is this relevant?" or "what's missing here?"
because those are simple language comprehension tasks, not planning tasks.

The key constraint: **the LLM's output must always be a short, bounded
string** — a score, a yes/no, or a short query. Never freeform JSON,
never tool calls, never multi-step reasoning. Keep the response surface
small and the model stays reliable.

---

## The Loop in Pseudocode

```python
MAX_ITERATIONS = 3          # hard guard — never infinite
RELEVANCE_THRESHOLD = 7.0   # 0–10; only clearly relevant results pass

def run(user_query):
    all_findings = []
    searches_done = set()
    current_query = user_query

    for i in range(MAX_ITERATIONS):

        # 1. Retrieve candidates (semantic search, SQL, API, file scan — anything)
        candidates = retrieve(current_query)

        # 2. Pre-filter: cheap keyword/rule check before calling LLM
        #    Reject anything with zero overlap on distinctive query terms.
        candidates = [c for c in candidates if passes_prefilter(current_query, c)]

        # 3. Score relevance with LLM (or heuristic if no LLM)
        relevant = [c for c in candidates if llm_score(current_query, c) >= THRESHOLD]

        # 4. Recovery: if almost nothing found on first pass, try rephrasing
        if i == 0 and len(relevant) < 2:
            new_query = llm_reformulate(user_query, current_query, candidates)
            if new_query:
                current_query = new_query
                continue

        # 5. Extract / process the relevant results
        findings = extract(current_query, relevant)
        all_findings.extend(deduplicate(findings, already_seen=all_findings))
        searches_done.add(current_query)

        # 6. Agent decision: is the answer complete?
        gap = llm_detect_gap(user_query, all_findings)
        if gap is None or gap in searches_done:
            break                          # done
        current_query = gap                # loop: search the gap

    return synthesize(user_query, all_findings)
```

---

## The Four LLM Calls

Each call has a strict, bounded reply format. Never ask for freeform prose.

### 1. Relevance score
```
Is this result relevant to the query? Score 0–10.
Reply with ONLY a single integer. No explanation.

Query: {query}
Result: {heading + content[:500]}

Score:
```

### 2. Query reformulation
```
The query "{failed_query}" returned almost nothing.
Original question: {original_query}
Top results found (likely off-topic): {headings}

Rewrite the query using different terminology (5–8 words).
Reply with ONLY the new query. If the query cannot be improved, reply: SAME
```

### 3. Gap detection
```
Question: {query}
Findings so far:
{bullet list of heading + 150-char summary per finding}

Does the above fully answer the question?
If YES: reply COMPLETE
If NO: reply with a short follow-up search query (5 words max)
```

### 4. Synthesis
```
Clinical/business question: {query}

Findings:
{source + recommendation for each finding}

Synthesize a clear, concise answer with citations.
```

---

## Pre-Filter (Before the LLM Call)

Always run a cheap filter before calling the LLM. If the result has zero
overlap with the distinctive terms in the query, it cannot be relevant —
reject it without spending an LLM call.

```python
GENERIC_WORDS = {'with', 'from', 'have', 'will', 'this', 'that',
                 'after', 'stage', 'therapy', 'treatment', 'management',
                 'patient', 'clinical', 'guideline', 'option', 'should', ...}

def passes_prefilter(query, result):
    # Extract words >= 4 chars that aren't generic
    distinctive = {w for w in re.findall(r'\b[a-z]{4,}\b', query.lower())}
                  - GENERIC_WORDS
    if not distinctive:
        return True   # can't filter a generic query — let LLM decide
    text = result.heading + " " + result.content
    return any(w in text.lower() for w in distinctive)
```

This eliminates the most common RAG failure mode: semantically similar but
topically wrong results (e.g., "prostate cancer" sections surfacing for a
"testicular cancer" query).

---

## Local vs Cloud LLM Selection

Not all steps need the same model. Route by task complexity.

| Step | Task | Use local? | Use cloud? |
|------|------|-----------|-----------|
| Pre-filter | Keyword overlap | No LLM needed | — |
| Relevance score | "Is this relevant? 0–10" | ✅ Local (qwen/llama) | If quality poor |
| Reformulation | "Rephrase this query" | ✅ Local | — |
| Gap detection | "What's missing?" | ✅ Local | If quality poor |
| Extraction | "What does this section recommend?" | ✅ Local | If complex docs |
| Synthesis | Multi-source, multi-hop answer | ⚠️ Local may struggle | ✅ Cloud preferred |

**Rule of thumb**: try local first. If the output quality is wrong (wrong
disease returned, synthesis hallucinating), the fix is usually the
pre-filter or a stricter threshold — not necessarily a bigger model.
Escalate to cloud only when local quality is genuinely insufficient after
those fixes.

```python
# Route based on task complexity
def llm_call(prompt, task="routine"):
    if task == "synthesis" and vertex_available():
        return vertex_llm.generate(prompt, max_tokens=600)
    return local_llm.generate(prompt, max_tokens=200)
```

### Local (Ollama)
- Free, instant, no data leaves the machine
- Good for: scoring, classification, short extraction, reformulation
- Models: `qwen2.5:1.5b` (fastest), `llama3.1:8b` (better quality)
- Fails at: long-context synthesis, subtle cross-document reasoning

### Cloud (Vertex AI / Gemini 2.5 Flash)
- Better reasoning, long context, reliable structured output
- Good for: final synthesis, complex extraction, ambiguous queries
- Constraint: data residency — use `northamerica-northeast1` for PIPEDA/PHIPA
- Cost: use sparingly, only for the steps that need it

---

## Guard Rails

Always include these. Without them the loop can spiral.

```python
MAX_ITERATIONS = 3          # never more than this many searches
searches_done = set()       # never repeat a search query
MIN_RESULTS_FOR_GAP = 1     # don't run gap detection on empty results
```

On the LLM response side, always take only the first line of the response
and check for degenerate output:

```python
response = llm.generate(prompt, max_tokens=20).strip()
follow_up = response.split("\n")[0].strip()
if not follow_up or follow_up.upper() == "COMPLETE":
    return None
```

---

## What Makes This "Agentic" vs Just RAG

| | RAG | Agentic loop |
|-|-----|-------------|
| Passes | 1 | 1–N (up to MAX_ITERATIONS) |
| LLM decides | Nothing — just generates | What to search for next |
| On poor results | Returns what it has | Reformulates and retries |
| On partial answer | Returns partial | Identifies gap, searches again |
| Control flow | Fixed pipeline | Dynamic, but bounded |

The agent is not autonomous in the sense of calling arbitrary tools or
writing code. It drives a bounded retrieval loop where the LLM acts as
a navigator — deciding direction — while Python acts as the engine —
executing the moves.

---

## Applying to Other Domains

The pattern is domain-agnostic. Swap the retrieval source:

| Domain | Retrieve from | LLM tasks |
|--------|--------------|-----------|
| Clinical guidelines | PDF index (semantic search) | relevance, gap, synthesis |
| Legal documents | Case law DB | relevance, gap, synthesis |
| Customer support | Ticket/KB vector DB | relevance, gap, synthesis |
| Code search | AST + embeddings | relevance, gap, synthesis |
| Financial reports | SEC filings index | relevance, gap, synthesis |

The loop logic, the four prompt patterns, the pre-filter, and the
local/cloud routing decision are identical in every case.
