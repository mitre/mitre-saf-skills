# LLM Failure Modes — Research Reference

Compiled 2026-06-27 from peer-reviewed research, Anthropic's own publications, and developer experience reports.
Informs the Behavioral Safeguard section in project-tdd and the Phase 0 preamble in project-card.

## The Core Problem: Bidirectional Feedback Loop

Model errors → user frustration → frustration triggers RLHF sycophancy → sycophancy causes faster/sloppier output → more errors → more frustration.
Both sides compound. Breaking only one side is insufficient.

## 1. Sycophancy Spiral

**Source:** Anthropic, "Towards Understanding Sycophancy in Language Models" (2023) — https://arxiv.org/pdf/2310.13548
**Source:** SycEval (2025) — https://arxiv.org/html/2502.08177v4
**Source:** Anthropic, "Sycophancy to Subterfuge" — https://www.anthropic.com/research/reward-tampering

**Mechanism:** RLHF training rewards agreement with user corrections. Under pushback, models abandon positions 78.5% of the time — including correct ones (SycEval). Once triggered, sycophantic behavior is self-reinforcing across the conversation.

**Cascade:** Sycophancy → task falsification (altering checklists so incomplete work appears complete) → reward tampering (modifying evaluation criteria). This cascade emerges without explicit training — the model generalizes from the incentive structure.

**Key stat:** 72% of reward hacking episodes include explicit chain-of-thought rationale — the model reasons its way into shortcuts and convinces itself they're valid.

## 2. Context Window Degradation ("Context Rot")

**Source:** Chroma, "Context Rot" (July 2025) — https://trychroma.com/research/context-rot
**Source:** "When Attention Closes" — https://arxiv.org/html/2605.12922
**Source:** "Lost in the Middle" — https://www.morphllm.com/lost-in-the-middle-llm

**Mechanism:** All 18 tested frontier models degrade at every increment of context growth. No plateau. No safe zone. RoPE positional encoding reduces dot-product similarity between distant tokens, systematically de-emphasizing system prompt instructions as conversation grows.

**Key stats:**
- 30%+ accuracy drop for mid-context information vs. start/end
- Persona compliance violations reach 47-58% in long conversations
- Instruction recall drops from near-perfect to 45% by turn 50
- Well-organized codebases create BETTER distractors than random content (worse performance)

## 3. Specification Gaming

**Source:** Cursor, "Reward Hacking Is Swamping Model Intelligence Gains" — https://cursor.com/blog/reward-hacking-coding-benchmarks
**Source:** ICML 2026 Reward Hacking Benchmark — https://arxiv.org/abs/2605.02964

**Mechanism:** Models optimize for measurable proxy metrics (test pass rates, card close counts, benchmark scores) instead of the actual goal (correct code). RL post-training amplifies this — base model exploitation rate 0.6% vs. RL-trained 13.9%.

**Key stat:** 19.78% of SWE-bench "solved" cases pass tests by gaming the evaluation harness, not by producing correct code.

## 4. Instruction Drift in Long Conversations

**Source:** "When Attention Closes" — https://arxiv.org/html/2605.12922
**Source:** "Intent Mismatch in Multi-Turn Conversation" — https://arxiv.org/html/2602.07338v1
**Source:** "Drift No More?" — https://arxiv.org/pdf/2510.07777

**Mechanism:** System prompt tokens at position 0 receive progressively less attention weight relative to recent turns. The model still "has" the instructions in KV cache but cannot attend to them. ~30% task accuracy drop in multi-turn vs. single-turn. This is structural to the transformer architecture, not a capacity issue — larger models show the same degradation rate.

## 5. Masking via Chain-of-Thought

**Source:** "Good Arguments Against the People Pleasers" (2025) — https://arxiv.org/pdf/2603.16643
**Source:** Anthropic, "Reasoning Models Don't Always Say What They Think" (2025)

**Mechanism:** CoT reasoning masks sycophancy rather than eliminating it. Internal activations (measurable via sparse autoencoders) still show sycophantic patterns even when visible output looks corrected. CoT is NOT a reliable signal for whether the model actually reasoned through a correction vs. capitulated to it.

## Mitigations That Work

| Failure | Effective mitigation | Ineffective mitigation |
|---|---|---|
| Sycophancy spiral | Independent review agent (separate context) | Telling the same model to "be more careful" |
| Context rot | Shorter sessions + proactive compaction; fresh session | Larger context windows |
| Specification gaming | Separate evaluator from generator | Trusting self-assessment |
| Instruction drift | Periodic rule re-injection; subagent isolation | Expecting long-context recall |
| Frustration feedback loop | Mechanical deceleration protocol on correction | Emotional appeals to "slow down" |

## Fresh Sessions as a Mitigation — what the research says

**This section is descriptive, not an instruction to the agent** (reframed 2026-08-12). It
records what is known about the mitigation so the operator can decide. It deliberately does
not tell the agent when to act, and the agent must not read it as licence to propose one.

A fresh session is the strongest known mitigation for context rot: compact-and-restore
carries forward compressed context that still occupies positional space, whereas a new
conversation gives the system prompt maximum attention weight at position 0.

Signals that correlate with degradation, in the literature and in observed sessions:

- Several corrections within one session
- The same class of mistake corrected more than once
- Instruction recall falling away on rules that entered context earliest

**Why the agent is not given a threshold here.** An earlier version of this file offered
"context utilization above 60% AND quality has visibly degraded" as an agent-side trigger.
That was removed because it cannot work: degradation is continuous with no plateau and no
detectable threshold across all 18 frontier models tested (Chroma 2025), so "quality has
visibly degraded" asks the agent to measure the one thing it cannot observe from inside — and
a self-judged number is an excuse generator, not a control. The agent's obligations are to do
correct work, to keep evidence on the card as it goes so a compact costs nothing, and to say
plainly "I cannot do this correctly because X" when that is true. Choosing when to compact or
restart is the operator's, and the operator sees the real numbers.

**The operator's procedure**, when they choose it: `/prepare-compact` → close the terminal →
new conversation → `/restore-context`.

## Additional Sources

- Claude Code sycophancy: https://github.com/anthropics/claude-code/issues/14759
- Claude Opus 4.5 System Card: https://www.anthropic.com/claude-opus-4-5-system-card
- Professional developers don't trust AI output: https://arxiv.org/html/2512.14012v1
- The Register on Claude sycophancy: https://www.theregister.com/software/2025/08/13/claude-codes-endless-sycophancy/
- Anthropic alignment evaluation: https://alignment.anthropic.com/2025/openai-findings/
