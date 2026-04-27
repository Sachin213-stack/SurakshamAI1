#!/usr/bin/env python3
import argparse
import csv
import json
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

POSITIVE_LABELS = {"scam", "fraud", "phishing", "vishing", "smishing", "1", "true", "positive"}
NEGATIVE_LABELS = {"legitimate", "ham", "safe", "0", "false", "negative", "normal"}
MAX_ERROR_TEXT_CHARS = 300


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Replay labeled real-world data against Sentinel API and compute metrics.")
    parser.add_argument("--base-url", default="http://127.0.0.1:8000", help="Backend base URL")
    parser.add_argument("--api-key", required=True, help="API key for X-API-Key header")
    parser.add_argument("--api-key-header", default="X-API-Key", help="API key header name")
    parser.add_argument("--input-csv", required=True, help="Path to labeled dataset CSV")
    parser.add_argument("--output-dir", default="evaluation_output", help="Output directory for reports")
    parser.add_argument("--timeout", type=float, default=20.0, help="HTTP timeout seconds")
    parser.add_argument("--rps", type=float, default=0.0, help="Replay rate in requests per second (0 = no throttling)")
    parser.add_argument("--max-rows", type=int, default=0, help="Max rows to process (0 = all)")
    parser.add_argument("--overlay-threshold", type=int, default=50, help="Frozen overlay threshold")
    parser.add_argument("--block-threshold", type=int, default=80, help="Frozen block threshold")
    parser.add_argument(
        "--threshold-grid",
        default="40,50,60,70,80,90",
        help="Comma-separated score thresholds for sensitivity analysis",
    )
    parser.add_argument(
        "--apply-feedback",
        action="store_true",
        help="Call /alerts/feedback using ground truth labels to bootstrap continuous improvement loop",
    )
    return parser.parse_args()


def normalize_truth(value: str) -> bool:
    v = (value or "").strip().lower()
    if v in POSITIVE_LABELS:
        return True
    if v in NEGATIVE_LABELS:
        return False
    raise ValueError(f"Unsupported ground_truth label: {value!r}")


def divide_or_zero(num: float, den: float) -> float:
    return round(num / den, 6) if den else 0.0


def compute_metrics(rows: list[dict[str, Any]], positive_fn) -> dict[str, Any]:
    tp = fp = fn = tn = 0
    for row in rows:
        if row.get("error"):
            continue
        gt = row["ground_truth_scam"]
        pred = positive_fn(row)
        if gt and pred:
            tp += 1
        elif not gt and pred:
            fp += 1
        elif gt and not pred:
            fn += 1
        else:
            tn += 1

    total = tp + fp + fn + tn
    precision = divide_or_zero(tp, tp + fp)
    recall = divide_or_zero(tp, tp + fn)
    f1 = divide_or_zero(2 * precision * recall, precision + recall)

    return {
        "samples": total,
        "tp": tp,
        "fp": fp,
        "fn": fn,
        "tn": tn,
        "precision": precision,
        "recall": recall,
        "f1": f1,
        "false_positive_rate": divide_or_zero(fp, fp + tn),
        "false_negative_rate": divide_or_zero(fn, fn + tp),
        "accuracy": divide_or_zero(tp + tn, total),
    }


def get_slice_metrics(rows: list[dict[str, Any]], field: str) -> dict[str, Any]:
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        value = (row.get(field) or "").strip()
        if value:
            groups[value].append(row)

    out = {}
    for key, group_rows in sorted(groups.items(), key=lambda x: len(x[1]), reverse=True):
        out[key] = compute_metrics(group_rows, lambda r: r.get("action") != "IGNORE")
    return out


def metrics_at_threshold(rows: list[dict[str, Any]], threshold: int) -> dict[str, Any]:
    return compute_metrics(rows, lambda r: float(r.get("score", 0)) >= threshold)


def main() -> int:
    args = parse_args()
    try:
        import httpx  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Missing dependency: httpx. Install dependencies before running (for example: pip install -r requirements.txt or pip install httpx)."
        ) from exc

    input_path = Path(args.input_csv)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if args.overlay_threshold >= args.block_threshold:
        raise ValueError(
            f"overlay-threshold ({args.overlay_threshold}) must be less than block-threshold ({args.block_threshold})"
        )

    threshold_grid = [int(x.strip()) for x in args.threshold_grid.split(",") if x.strip()]
    headers = {args.api_key_header: args.api_key}

    rows: list[dict[str, Any]] = []
    action_counter: Counter[str] = Counter()
    errors = 0
    feedback_ok = 0
    feedback_fail = 0

    with input_path.open("r", encoding="utf-8", newline="") as f, httpx.Client(timeout=args.timeout) as client:
        reader = csv.DictReader(f)

        required_cols = {"raw_text", "ground_truth"}
        missing = required_cols - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing required CSV columns: {sorted(missing)}")

        for idx, row in enumerate(reader, start=1):
            if args.max_rows and idx > args.max_rows:
                break

            started = time.perf_counter()
            result: dict[str, Any] = {
                "row_index": idx,
                "id": row.get("id") or str(idx),
                "raw_text": row.get("raw_text", ""),
                "source_number": row.get("source_number") or None,
                "device_id": row.get("device_id") or None,
                "language": row.get("language") or "",
                "region": row.get("region") or "",
                "message_source_type": row.get("message_source_type") or "",
                "writing_style": row.get("writing_style") or "",
                "flow": (row.get("flow") or "analyze").strip().lower(),
                "ground_truth": row.get("ground_truth", ""),
            }

            try:
                result["ground_truth_scam"] = normalize_truth(result["ground_truth"])
            except ValueError as exc:
                result["error"] = f"Invalid ground_truth label: {exc}"
                result["latency_ms"] = round((time.perf_counter() - started) * 1000, 3)
                rows.append(result)
                errors += 1
                continue

            if result["flow"] == "report":
                endpoint = "/report"
                payload = {
                    "raw_text": result["raw_text"],
                    "source_number": result["source_number"],
                    "report_type": (row.get("report_type") or row.get("type") or "sms"),
                    "device_id": result["device_id"],
                    "user_note": row.get("user_note") or None,
                }
            else:
                endpoint = "/analyze"
                payload = {
                    "type": (row.get("type") or "sms"),
                    "raw_text": result["raw_text"],
                    "source_number": result["source_number"],
                    "device_id": result["device_id"],
                }

            try:
                response = client.post(f"{args.base_url.rstrip('/')}{endpoint}", headers=headers, json=payload)
                result["http_status"] = response.status_code
                if response.status_code >= 400:
                    result["error"] = f"HTTP {response.status_code}: {response.text[:MAX_ERROR_TEXT_CHARS]}"
                else:
                    body = response.json()
                    result["alert_id"] = body.get("id")
                    result["score"] = body.get("score")
                    result["action"] = body.get("action")
                    result["reasoning"] = body.get("reasoning")
                    action_counter[result["action"]] += 1

                    if args.apply_feedback and result.get("alert_id"):
                        feedback_payload = {
                            "alert_id": result["alert_id"],
                            "feedback": "confirmed_scam" if result["ground_truth_scam"] else "false_positive",
                            "device_id": result["device_id"],
                        }
                        fb = client.post(
                            f"{args.base_url.rstrip('/')}/alerts/feedback",
                            headers=headers,
                            json=feedback_payload,
                        )
                        if fb.status_code < 400:
                            feedback_ok += 1
                        else:
                            feedback_fail += 1

            except Exception as exc:
                result["error"] = f"Request error: {exc}"

            result["latency_ms"] = round((time.perf_counter() - started) * 1000, 3)
            rows.append(result)

            if result.get("error"):
                errors += 1

            if args.rps and args.rps > 0:
                time.sleep(1.0 / args.rps)

    def has_valid_score(row: dict[str, Any]) -> bool:
        score = row.get("score")
        return not row.get("error") and isinstance(score, (int, float))

    analyzed_rows = [r for r in rows if has_valid_score(r)]

    overall_metrics = compute_metrics(analyzed_rows, lambda r: r.get("action") != "IGNORE")
    threshold_sensitivity = {str(t): metrics_at_threshold(analyzed_rows, t) for t in threshold_grid}

    score_bands = {
        f"0-{args.overlay_threshold - 1}": sum(
            1 for r in analyzed_rows if 0 <= float(r.get("score", 0)) < args.overlay_threshold
        ),
        f"{args.overlay_threshold}-{args.block_threshold - 1}": sum(
            1 for r in analyzed_rows if args.overlay_threshold <= float(r.get("score", 0)) < args.block_threshold
        ),
        f"{args.block_threshold}-100": sum(1 for r in analyzed_rows if float(r.get("score", 0)) >= args.block_threshold),
    }

    summary = {
        "run_config": {
            "base_url": args.base_url,
            "input_csv": str(input_path),
            "output_dir": str(output_dir),
            "overlay_threshold": args.overlay_threshold,
            "block_threshold": args.block_threshold,
            "threshold_grid": threshold_grid,
            "apply_feedback": args.apply_feedback,
            "frozen_thresholds": True,
        },
        "totals": {
            "input_rows": len(rows),
            "successful_inferences": len(analyzed_rows),
            "errors": errors,
            "feedback_updates_ok": feedback_ok,
            "feedback_updates_failed": feedback_fail,
        },
        "overall_metrics": overall_metrics,
        "action_distribution": dict(action_counter),
        "score_bands": score_bands,
        "threshold_sensitivity": threshold_sensitivity,
        "fairness_slices": {
            "language": get_slice_metrics(analyzed_rows, "language"),
            "region": get_slice_metrics(analyzed_rows, "region"),
            "message_source_type": get_slice_metrics(analyzed_rows, "message_source_type"),
            "writing_style": get_slice_metrics(analyzed_rows, "writing_style"),
        },
    }

    with (output_dir / "evaluation_results.jsonl").open("w", encoding="utf-8") as out:
        for row in rows:
            out.write(json.dumps(row, ensure_ascii=False) + "\n")

    with (output_dir / "evaluation_summary.json").open("w", encoding="utf-8") as out:
        json.dump(summary, out, ensure_ascii=False, indent=2)

    print("Evaluation complete")
    print(json.dumps(summary["totals"], indent=2))
    print(json.dumps(summary["overall_metrics"], indent=2))
    print(f"Reports written to: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
