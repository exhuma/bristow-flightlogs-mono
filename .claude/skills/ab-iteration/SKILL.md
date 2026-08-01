---
name: ab-iteration
description: Converge on a design decision by interviewing the user first, then running rounds of two complete, concrete artifacts that differ on exactly one axis, stopping after each round for a pick. Use this whenever the user needs to settle a design question rather than implement a settled one — a UI layout, an API or endpoint shape, a service architecture, or the structure of a function or module. Trigger on phrasings like "help me figure out how X should look", "what's the right shape for this endpoint", "I can't decide between these approaches", "brainstorm a design for", "let's converge on", or any request to explore options before committing. Prefer this strongly over proposing a single design and asking for feedback on it.
---

# A-B Iteration

Converge on a design choice through a short interview, then a loop of concrete A-B rounds.

The loop works because of three properties. Preserve all three — they're what makes it fast:

1. Each round hands over a **complete, concrete artifact**, not a description of one.
2. The two variants differ on **exactly one real axis**.
3. Reacting is **cheap** — the user picks A or B and owes you no critique.

The medium is just what the artifact happens to look like. The loop itself doesn't change.

---

## Step 1 — Establish the medium

Decide which applies: **UI**, **API shape**, **architecture**, or **code**.

Infer it from what the user said if it's obvious. If it isn't — or if the question
plausibly spans two, e.g. an endpoint change that's really an architecture decision —
ask, stating which way you lean and why. One short question, not a menu.

---

## Step 2 — Interview before proposing anything

You need the five things below before you can generate variants that differ on a *real*
axis rather than an arbitrary one. Arbitrary axes are what make this loop degenerate into
noise, so don't guess at these.

| What you need | How to get it |
|---|---|
| **The thing being designed or changed** | Usually stated. e.g. an extended desktop layout for X; the card list reshaped to accommodate Y; the endpoint for listing a user's collectibles; how the ingest service talks to the pricing cache. |
| **Current state** | **Read it yourself.** You have filesystem access — find the component, the route handler, the module, the schema. Ask the user only for what isn't in the repo (a screenshot of the rendered page, a production payload, a diagram that lives elsewhere). Skip only if genuinely greenfield. |
| **What's driving this** | The constraints, affordances, or pain points. This is the input that makes the axes real. Ask if it isn't stated. |
| **A grounding example of the domain complexity** | Ask for one real, gnarly instance of the data or interaction — not the abstract rule. Concrete beats general here every time. |
| **Scope fence** | What to explicitly ignore for this session. Propose one from what you've read and let the user correct it. |

Running the interview:

- Ask **conceptual questions about the design space**, not just form-filling. If something
  about the problem is genuinely unresolved, that's worth a question too.
- Ask in **small batches** — roughly three at a time, never a wall.
- Prefer stating an inference for confirmation over asking cold: *"Reading the component,
  I'm assuming the scope is the list view and not the detail page — correct me if not."*
- Never ask about anything the user already told you or you can read from the repo.
- Stop interviewing once you can make **real** choices. That's the bar — not "every row of
  the table is filled in."

Variants build **on** the current state. They don't reinvent it from scratch; drifting
away from what already exists makes the pick harder, not easier.

---

## Step 3 — Build the artifact for this medium

| Medium | Artifact per variant | Rationale cap |
|---|---|---|
| **UI** | Standalone static HTML/CSS, rendered to a screenshot. No interactivity. | ≤15 words — the visual speaks for itself. |
| **API shape** | URL plus payload/schema in a fenced code block. No screenshot. | Short phrase; not a hard word cap. |
| **Architecture** | A structural diagram — boxes and arrows, or a fenced Mermaid block — showing the actual difference. | Short phrase. |
| **Code** | A **full snippet per variant. Never a diff.** | Short phrase naming the structural choice, e.g. "class-based state vs. functional". |

**UI** — write each variant to its own file in a scratch directory outside the working
tree (or a gitignored one), e.g. `/tmp/ab-iteration/round-1-a.html`, then screenshot it
with Playwright or headless Chrome and show the images. If no browser tooling is
available, say so up front and agree a fallback rather than silently degrading to a prose
description of the design — that breaks property 1 and the loop stops working.

**API shape** — trade-offs like pagination, caching, and versioning often aren't visible
in the shape itself. Those need to be *said*, not shown; that's why the cap is looser here.

**Architecture** — best suited to topology decisions: service boundaries, sync vs. async
flow. If the deciding factor can't appear in a diagram — consistency model, storage
engine, retry semantics — say so explicitly and argue it in text. Don't force a diagram
onto a trade-off that isn't structural.

**Code** — a diff anchors to the old structure and biases toward minimal edit distance;
a full snippet shows the design actually being chosen. Hold the scope fence hard: one
function or small module, not a multi-file refactor. Don't edit any real files during the
loop — variants are proposals, and writing one in makes switching to the other expensive.

---

## Step 4 — Run A-B rounds

Each round tests **exactly one axis of difference**. The variants must be clearly,
meaningfully different — not two shades of the same idea. Treat it as a binary search over
a large space: every round should cut that space down, not nudge it.

Label each variant with a rationale, capped per the table above:

`**A — <short label>**: <the one design bet this variant is testing>`

No paragraphs, no pros-and-cons lists. Just enough to know what's being chosen between
before looking at the artifact.

Use this exact structure per round:

```
### Round N: <axis being tested>

**A — <label>**: <rationale>
[artifact]

**B — <label>**: <rationale>
[artifact]

Which do you prefer?
```

Then **stop and end the turn.** Do not produce Round N+1, do not propose the next axis, do
not speculate about which the user will pick, do not start implementing the winner. This
is the single most important behaviour in the skill: the loop only stays cheap for the user
if each turn asks for exactly one decision.

Each new round builds on the winning variant and varies one clear axis. Repeat until it
converges or the user calls it.

---

## Step 5 — Close out

Summarise the final design plus the axis decisions that produced it — one line each, in
the order they were made. That record of *why* the design looks the way it does is the
expensive part to reconstruct later.

For the **code** medium, state plainly that the winner is an approach, not a verified
implementation: picking a variant narrows the design, it doesn't replace running the thing.

Then ask whether to implement it. Don't start unprompted — converging on a design and
committing to it are separate decisions.

---

## Failure modes

- Skipping the interview and jumping straight to variants.
- Variants that differ on more than one axis, or so little that the pick is arbitrary.
- Describing an artifact instead of producing one.
- Continuing past a round without waiting for the pick.
- Diffs instead of full snippets, for code.
- Quietly widening the scope fence as rounds go on.
- Asking the user to paste in current state you could have read from the repo yourself.
