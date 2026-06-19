# Roadmap: from a single skill to a corpus-scale RAG-backed AI tool

One-line description: the 5-phase plan for evolving `profile-development-rubric` from a local Claude Code skill into MITRE SAF's full profile-development AI toolkit.

Linked from [SKILL.md](../SKILL.md) — "Where this is going" section.

## Why this roadmap exists

The skill captures *methodology*: how a human (or an LLM) decides what "done" means for a single InSpec control. That methodology is the foundation of a much larger system — the SAF Profile-Dev Toolkit — that adds live data lookups, corpus-scale retrieval, and a bidirectional learning loop. The phases below describe how the toolkit grows around the methodology layer over time.

Recording the phases here, attached to the skill itself, means each iteration builds on the prior one rather than spawning parallel uncoordinated efforts.

## The 5 Phases

### Phase 0 — Skill alone *(STATUS: current)*

**Goal:** methodology codified in `SKILL.md`, usable by Claude Code on a single profile at a time.

**Deliverables:**
- `SKILL.md` + `references/` in the skill directory.
- Six SAF outcomes, five phases, decision table, N/A vs N/R vs pass-when-empty rule.
- Worked example, good/bad patterns, drop-file patterns, templating-drift cluster docs.

**Validation:**
- AL2023 v1.3.0 ships.
- PR `fix/update-for-release` on `mitre/amazon-linux-2023-stig-baseline` lands.
- ~40 controls swept in the current session using the rubric.

**To advance to Phase 1:** at least one profile shipped end-to-end using the skill; cards `95g`, `ao0`, `dtf`, `oji` closable.

### Phase 1 — Cross-vendor validation *(STATUS: next)*

**Goal:** prove the rubric generalizes beyond the RHEL-family OS profile that birthed it. The skill was distilled from RHEL9 and AL2023 work; it must work for Windows, databases, and applications too.

**Deliverables:**
- Cold-start tests of the skill on one control each from:
  - Windows Server 2019/2022 (`registry_key`, `security_policy`)
  - MS SQL Server 2022 (`mssql_session`)
  - Apache Tomcat 9 (XML parsing)
  - Canonical Ubuntu 22 (`apt`, `package`)
- Per-OS sections (~50 lines each) added to the skill or split into a new `references/per-vendor-resources.md`.

**Validation:** card `b33` (subagent cold-start) but with cross-vendor controls. If the subagent produces good controls without further context, the skill is general. If it gets stuck on Linux-specific assumptions, those become Phase 1 fixes.

**To advance to Phase 2:** subagents successfully review 1 control each from Windows + DB + container/app stacks.

### Phase 2 — Publication as org-wide artifact *(STATUS: future)*

**Goal:** become a MITRE-org artifact usable by every engineer who touches an InSpec profile.

**Deliverables:**
- Upload skill via Anthropic Skills API (`POST /v1/skills`, beta header `skills-2025-10-02`) to MITRE's Anthropic workspace.
- Versioned releases — every `bd remember` insight folded into a version bump.
- Plugin packaging: `mitre-saf-profile-dev` plugin discoverable via Claude Code's plugin install.

**Validation:** an engineer on a different team uses the skill on a profile we haven't touched and produces a clean PR.

**To advance to Phase 3:** at least one external-team profile derivation completed using the skill.

### Phase 3 — MCP server for live lookups *(STATUS: deferred)*

**Goal:** replace manual grep across `saf-training/`, STIG XCCDF, and existing-profile bodies with typed MCP tool calls.

**Deliverables:** an MCP server exposing tools such as:
- `get_stig_check(stig_id)` — return the canonical check/fix text for a STIG ID.
- `cci_to_nist_800_53(cci)` — round-trip CCI ↔ NIST 800-53 Rev 5 mapping.
- `find_existing_pattern(query, vendor)` — search the existing profile corpus for analogous controls.
- `lookup_inspec_resource(name)` — fetch the typed-resource doc page on demand.

Bundled into the `mitre-saf-profile-dev` plugin from Phase 2.

**Validation:** a control review using MCP queries instead of `grep` completes ~3-5× faster.

**Why MCP, not just inline tools:** the skill body stays small (methodology only); MCP handles live data and grows independently. The methodology layer should not bloat as factual lookups expand.

**To advance to Phase 4:** MCP server endpoint stable enough for production use.

### Phase 4 — RAG over the full corpus *(STATUS: deferred — the "real AI tool")*

**Goal:** vector-DB-backed retrieval over the full SAF/STIG corpus so the assistant can answer "show me an example of how X is solved across all profiles" instantly.

**Corpus scope:**
- 3 saf-training courses (~8,000 lines markdown).
- DISA STIG library (hundreds of MB XCCDF XML).
- ~100+ MITRE InSpec profile bodies (gigabytes of Ruby).
- Heimdall data format docs.
- Past PR review comments from this repo and predecessor repos.

**Stack guidance (subject to Phase-3 learnings):**
- Local-first per the `shinpr/mcp-local-rag` pattern; Ollama for embeddings; no upstream API calls for the embedding step.
- Qdrant or `sqlite-vss` as the vector store.

**Validation:**
- Per-control review time drops another 3-5× vs Phase 3 baseline.
- Rare-pattern lookups (e.g. "how does the Windows STIG handle `auditpol`") return relevant results without manual archeology.

**Why this is the "real AI tool" the user asked about:** methodology + corpus together is what makes the assistant feel like it actually knows STIGs at the scale of MITRE's whole catalog. Phases 0-3 are foundational; Phase 4 is the qualitative jump.

**To advance to Phase 5:** corpus ingested, RAG retrievals consistently relevant on test queries from each vendor family.

### Phase 5 — Bidirectional learning loop *(STATUS: deferred — continuous)*

**Goal:** closed loop. Every per-control review writes back what was learned; the system gets smarter automatically.

**Mechanics:**
- Every session ending a control review writes `bd remember` notes when a NEW pattern emerges. Today's templating-drift, drop-file, and guard-clause findings are exemplars.
- Periodic skill version bumps fold those notes into the methodology layer.
- The vector DB re-ingests merged PRs (committed fixes become training material).
- Eventually: automated review of new PRs flags patterns the methodology already knows about; surfaces only novel issues to a human.

**Validation:** skill version N+1 demonstrably covers patterns we didn't have words for in version N. Year-over-year per-derivation cost drops without quality regressions.

**To advance:** this phase doesn't "end" — it is the steady-state operational mode.

## How phases compose

Phases are additive, not strictly sequential. Phase 1 doesn't replace Phase 0; Phase 4 doesn't replace Phase 2. The skill body keeps shrinking proportionally as more knowledge moves out to MCP and RAG, but the methodology stays in the skill — factual lookups move outward.

A useful mental model: the skill is the *grammar*, MCP is the *dictionary*, RAG is the *literary corpus*, and Phase 5 is the editor who keeps all three in sync. You need the grammar before the dictionary helps, and the dictionary before the literary corpus is more than noise.

## Tracking

Work is tracked in the project's issue tracker. Phase 0 is complete; Phases 1-5 are future work.

## Status checklist

| Phase | Status | Blocking |
|---|---|---|
| 0 — Skill alone | In progress | AL2023 v1.3.0 ship (`ao0`, `dtf`, `oji`, `dws` cards) |
| 1 — Cross-vendor validation | Next | Phase 0 ship |
| 2 — Publication | Future | Phase 1 + Anthropic Skills API beta stability |
| 3 — MCP server | Deferred | Phase 2 + bandwidth |
| 4 — RAG corpus | Deferred | Phase 3 |
| 5 — Bidirectional | Continuous | Threads through every phase |
