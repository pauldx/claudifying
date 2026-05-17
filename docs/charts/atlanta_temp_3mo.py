"""
Sample charts: Atlanta (KATL) daily temperatures, Feb–Apr 2026.

Data is SYNTHETIC — generated from NOAA climate normals for ATL, plus
seasonally appropriate day-to-day jitter. Not live weather.

Outputs:
  docs/charts/atlanta_temp_3mo_line.png    Daily high / low / avg
  docs/charts/atlanta_temp_3mo_bars.png    Monthly avg high vs low
  docs/charts/atlanta_temp_3mo_data.csv    Underlying sample data
"""

from __future__ import annotations

import csv
import math
import random
from datetime import date, timedelta
from pathlib import Path

import matplotlib.pyplot as plt

OUT = Path(__file__).resolve().parent

# Atlanta climate normals (°F), source: NOAA NWS ATL.
NORMALS = {
    2: {"high": 58.5, "low": 39.4},  # February
    3: {"high": 66.2, "low": 45.7},  # March
    4: {"high": 73.8, "low": 52.6},  # April
}

random.seed(2026_05_16)  # deterministic

start = date(2026, 2, 1)
end = date(2026, 4, 30)

rows: list[dict[str, float | str]] = []
day = start
while day <= end:
    norm = NORMALS[day.month]
    # Smooth seasonal warming across the month (cosine bias).
    frac = (day.day - 1) / 27.0
    bias = math.sin(frac * math.pi / 2) * 2.5  # up to +2.5°F by month end
    hi = norm["high"] + bias + random.gauss(0, 4.5)
    lo = norm["low"] + bias + random.gauss(0, 3.8)
    if lo > hi - 5:
        lo = hi - 5 - random.random() * 3
    rows.append(
        {
            "date": day.isoformat(),
            "high_f": round(hi, 1),
            "low_f": round(lo, 1),
            "avg_f": round((hi + lo) / 2, 1),
        }
    )
    day += timedelta(days=1)

# CSV (data sidecar for transparency)
csv_path = OUT / "atlanta_temp_3mo_data.csv"
with csv_path.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=["date", "high_f", "low_f", "avg_f"])
    writer.writeheader()
    writer.writerows(rows)  # type: ignore[arg-type]

# ── Chart 1: line chart, daily high / low / avg ────────────────────────────
dates = [date.fromisoformat(str(r["date"])) for r in rows]
highs = [r["high_f"] for r in rows]
lows = [r["low_f"] for r in rows]
avgs = [r["avg_f"] for r in rows]

fig, ax = plt.subplots(figsize=(12, 5.5))
ax.fill_between(dates, lows, highs, alpha=0.18, color="#3b82f6", label="daily range")
ax.plot(dates, highs, color="#ef4444", lw=1.4, label="daily high")
ax.plot(dates, lows, color="#3b82f6", lw=1.4, label="daily low")
ax.plot(dates, avgs, color="#111827", lw=1.0, ls="--", label="daily avg")

ax.set_title(
    "Atlanta (KATL) — daily temperature, Feb–Apr 2026 (sample data)",
    fontsize=13,
    pad=12,
)
ax.set_ylabel("°F")
ax.set_xlabel("date")
ax.grid(True, alpha=0.25, linestyle=":")
ax.legend(loc="lower right", framealpha=0.9, ncols=4, fontsize=9)
fig.autofmt_xdate()
fig.tight_layout()
fig.savefig(OUT / "atlanta_temp_3mo_line.png", dpi=140)
plt.close(fig)

# ── Chart 2: grouped bars, monthly average high vs low ─────────────────────
monthly: dict[int, dict[str, list[float]]] = {2: {"hi": [], "lo": []}, 3: {"hi": [], "lo": []}, 4: {"hi": [], "lo": []}}
for r, d in zip(rows, dates):
    monthly[d.month]["hi"].append(float(r["high_f"]))
    monthly[d.month]["lo"].append(float(r["low_f"]))

labels = ["Feb 2026", "Mar 2026", "Apr 2026"]
avg_hi = [round(sum(monthly[m]["hi"]) / len(monthly[m]["hi"]), 1) for m in (2, 3, 4)]
avg_lo = [round(sum(monthly[m]["lo"]) / len(monthly[m]["lo"]), 1) for m in (2, 3, 4)]

x = range(len(labels))
width = 0.36

fig, ax = plt.subplots(figsize=(8, 5))
b1 = ax.bar([i - width / 2 for i in x], avg_hi, width, color="#ef4444", label="avg high")
b2 = ax.bar([i + width / 2 for i in x], avg_lo, width, color="#3b82f6", label="avg low")

for bar in (*b1, *b2):
    ax.annotate(
        f"{bar.get_height():.1f}°F",
        xy=(bar.get_x() + bar.get_width() / 2, bar.get_height()),
        xytext=(0, 4),
        textcoords="offset points",
        ha="center",
        fontsize=9,
    )

ax.set_xticks(list(x))
ax.set_xticklabels(labels)
ax.set_ylabel("°F")
ax.set_title("Atlanta — monthly average high vs low (sample data)", fontsize=13, pad=12)
ax.grid(True, axis="y", alpha=0.25, linestyle=":")
ax.legend(loc="lower right")
fig.tight_layout()
fig.savefig(OUT / "atlanta_temp_3mo_bars.png", dpi=140)
plt.close(fig)

print("wrote:")
print(f"  {OUT / 'atlanta_temp_3mo_line.png'}")
print(f"  {OUT / 'atlanta_temp_3mo_bars.png'}")
print(f"  {csv_path}")
print()
print("monthly averages (°F):")
for label, hi, lo in zip(labels, avg_hi, avg_lo):
    print(f"  {label}: high {hi:5.1f}   low {lo:5.1f}   range {hi - lo:4.1f}")
