# Real-World Evaluation Guide

This repository now includes an offline evaluation runner for real-world data:

- Script: `/home/runner/work/SurakshamAI1/SurakshamAI1/tools/evaluate_real_world.py`
- Dataset template: `/home/runner/work/SurakshamAI1/SurakshamAI1/data/real_world_eval_template.csv`

## 1) Prepare dataset

Use a CSV with at least:

- `raw_text`
- `ground_truth` (`scam` or `legitimate`)

Recommended metadata columns for fairness slicing:

- `language`, `region`, `message_source_type`, `writing_style`

Routing columns:

- `flow`: `analyze` or `report` (defaults to `analyze`)
- `type`: for `/analyze` (`sms` or `call_transcript`)
- `report_type`: for `/report` (`sms`, `call_transcript`, `whatsapp`, `other`)

## 2) Freeze thresholds for comparable runs

Run with frozen thresholds matching current defaults:

- `--overlay-threshold 50`
- `--block-threshold 80`

## 3) Replay data through API

```bash
python /home/runner/work/SurakshamAI1/SurakshamAI1/tools/evaluate_real_world.py \
  --base-url http://127.0.0.1:8000 \
  --api-key <YOUR_API_KEY> \
  --input-csv /home/runner/work/SurakshamAI1/SurakshamAI1/data/real_world_eval_template.csv \
  --output-dir /home/runner/work/SurakshamAI1/SurakshamAI1/evaluation_output \
  --overlay-threshold 50 \
  --block-threshold 80 \
  --threshold-grid 40,50,60,70,80,90
```

## 4) Optional feedback loop bootstrap

To update `/alerts/feedback` during replay from ground truth labels:

```bash
python /home/runner/work/SurakshamAI1/SurakshamAI1/tools/evaluate_real_world.py \
  --base-url http://127.0.0.1:8000 \
  --api-key <YOUR_API_KEY> \
  --input-csv /home/runner/work/SurakshamAI1/SurakshamAI1/data/real_world_eval_template.csv \
  --output-dir /home/runner/work/SurakshamAI1/SurakshamAI1/evaluation_output \
  --apply-feedback
```

When `ground_truth=scam`, feedback is sent as `confirmed_scam`; otherwise `false_positive`.

## 5) Outputs

- `evaluation_results.jsonl`: per-sample inference, latency, errors
- `evaluation_summary.json`:
  - precision / recall / F1
  - false-positive / false-negative rate
  - action distribution
  - score bands around frozen thresholds
  - threshold sensitivity
  - fairness slices by language/region/source/writing style

## 6) Shadow mode + phased rollout (operational)

- Run model in scoring-only mode first (no enforcement changes).
- Compare decisions with outcomes and feedback rates.
- Promote gradually by user/device percentage with rollback guardrails.
- Re-run this offline benchmark regularly (for example monthly) and compare metrics before threshold changes.
