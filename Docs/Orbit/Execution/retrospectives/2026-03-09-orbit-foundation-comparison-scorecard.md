# Orbit Retrospective Comparison Scorecard

- Date: 2026-03-09
- Objective: Compare roundtable and fan-out retrospective methods for the first
  Orbit foundation checkpoint.
- Evidence Packet:
  - `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-evidence-packet.md`
- Scorer:
  - `Samwise`

## Methods Compared

1. Roundtable:
   - `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-roundtable.md`
2. Fan-Out:
   - `Docs/Orbit/Execution/retrospectives/2026-03-09-orbit-foundation-fan-out.md`

## Metric Scores

Use `1-5`.

Weights from `Orbit-Retrospective-Methodology-Comparison.md`:

- Orbit Specificity: `14`
- Persona Fidelity: `14`
- Evidence Quality: `14`
- Finding Quality: `14`
- Actionability: `10`
- Product Sensitivity: `10`
- Process Sensitivity: `10`
- Disagreement Handling: `5`
- Synthesis Burden: `4`
- Turnaround Time: `5`

| Metric | Weight | Roundtable | Fan-Out | Notes |
| --- | --- | --- | --- | --- |
| Orbit Specificity | 14 | 5 | 5 | Both methods stayed tightly anchored to Orbit's command-center goal, the first checkpoint boundary, and the persona-memory experiment. |
| Persona Fidelity | 14 | 4 | 5 | Roundtable kept roles distinct, but later turns were shaped by earlier ones. Fan-out preserved the cleanest one-persona-per-pass separation. |
| Evidence Quality | 14 | 5 | 5 | Both methods cited the same frozen packet, planning docs, and review findings instead of drifting into generic process commentary. |
| Finding Quality | 14 | 5 | 4 | Roundtable sharpened causal language and separated proof from product readiness more clearly. Fan-out found the same issues, but with more duplication and less refinement. |
| Actionability | 10 | 5 | 4 | Both produced real actions. Roundtable tied them more cleanly to checkpoints, owners, and acceptance language. |
| Product Sensitivity | 10 | 5 | 4 | Roundtable was better at clarifying the UI/design failures as product bugs, not just polish debt. |
| Process Sensitivity | 10 | 5 | 5 | Both methods clearly caught the real process failure: the coding checkpoint succeeded, but the multiagent experiment did not really run as intended. |
| Disagreement Handling | 5 | 5 | 3 | Roundtable exposed and resolved important nuances live. Fan-out surfaced uncertainty, but resolution happened only in synthesis. |
| Synthesis Burden | 4 | 4 | 3 | Roundtable still needed synthesis, but the live clarification reduced cleanup. Fan-out required more deduplication and post-hoc reconciliation. |
| Turnaround Time | 5 | 3 | 5 | Fan-out was materially faster. Roundtable's quality gains came with real wall-clock cost. |

## Minimum Viability Gates

- Roundtable Persona Fidelity >= 4: `pass`
- Roundtable Evidence Quality >= 4: `pass`
- Fan-Out Persona Fidelity >= 4: `pass`
- Fan-Out Evidence Quality >= 4: `pass`

## Weighted Result

- Roundtable: `94.4 / 100`
- Fan-Out: `89.6 / 100`

Calculation:

- weighted result = `sum(weight * score / 5)`

## Quick Read

1. Better product findings: `Roundtable`
2. Better process findings: `Tie`
3. Better persona fidelity: `Fan-Out`
4. More trustworthy default: `Hybrid, with Roundtable as the stronger single-method fallback`
