# Performance tuning notes (capstone)

Use this file to record tuning experiments as short, evidence-based reports.

## Why this matters
Performance work only counts when you can prove:
- there was a real problem (baseline evidence)
- your change improved it (result evidence)
- you understand risks/regressions (what could get worse later)

This doc is your “paper trail” for PR reviews and for your portfolio.

## Workflow (recommended)
1. Define the goal (latency, CPU, logical reads, concurrency).
2. Capture baseline evidence (actual plan + IO/time).
3. Form a hypothesis (what operator/strategy is expensive and why).
4. Make one change at a time (index, rewrite, statistics, predicate).
5. Capture result evidence (same inputs; actual plan + IO/time).
6. Note risks and monitoring (parameter sensitivity, data growth, skew).

## Evidence checklist
- Same inputs for baseline and result (same filters, same data window).
- Include `SET STATISTICS IO, TIME` output.
- Include the actual execution plan (not estimated).
- Explain the plan change in one sentence (e.g., “hash join → nested loops due to new index”).

Suggested format per experiment:
- Symptom:
- Hypothesis:
- Baseline evidence (actual plan + IO/time):
- Change made:
- Result evidence (actual plan + IO/time):
- Risks/regressions to watch:

## Common anti-patterns
- No baseline (“it feels faster”).
- Multiple changes at once (can’t attribute the win).
- Adding wide/duplicate indexes without workload justification.
- Tuning for one parameter value and regressing others (parameter sensitivity).

Tip: you can also use [templates/tuning_report_template.md](../templates/tuning_report_template.md).

