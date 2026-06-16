"""
Columbia GS Enrollment Analysis — Mock Data Generator + Analysis
Author: Aastha Gade | aastha.rdg@gmail.com

Generates a realistic enrollment dataset mirroring Slate CRM exports,
then produces funnel analysis, yield metrics, and demographic breakdowns.
All charts saved to /dashboard/ for the HTML report.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.ticker as mticker
from matplotlib.gridspec import GridSpec
import warnings, os

warnings.filterwarnings("ignore")
np.random.seed(42)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "dashboard")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Palette ────────────────────────────────────────────────────────────────
COLUMBIA_BLUE = "#75AADB"
NAVY          = "#1C2D4F"
LIGHT_GREY    = "#F4F6F9"
MID_GREY      = "#8A96A3"
GOLD          = "#E8B84B"
CORAL         = "#E07B5A"
GREEN         = "#4CAF82"
WHITE         = "#FFFFFF"

TERMS   = ["Fall 2022", "Spring 2023", "Fall 2023", "Spring 2024", "Fall 2024"]
PROGRAMS = ["Bachelor of Arts", "Postbaccalaureate", "American Language Program", "Science Certificate"]

# ── 1. GENERATE MOCK DATA ───────────────────────────────────────────────────
def generate_data(n=1200):
    records = []
    for i in range(n):
        term        = np.random.choice(TERMS, p=[0.28, 0.12, 0.30, 0.12, 0.18])
        program     = np.random.choice(PROGRAMS, p=[0.45, 0.25, 0.18, 0.12])
        is_first_gen     = np.random.random() < 0.32
        is_international = np.random.random() < 0.28
        is_veteran       = np.random.random() < 0.08
        is_transfer      = np.random.random() < 0.42

        # Simulate funnel with realistic drop-offs
        submitted  = np.random.random() < 0.78
        complete   = submitted and np.random.random() < 0.82
        admitted   = complete  and np.random.random() < 0.55
        # Yield varies by program
        yield_p = {"Bachelor of Arts": 0.62, "Postbaccalaureate": 0.70,
                   "American Language Program": 0.58, "Science Certificate": 0.52}
        enrolled = admitted and np.random.random() < yield_p[program]

        days_to_decision = int(np.random.normal(28, 8)) if complete else None
        scholarship = round(np.random.uniform(2000, 15000), -2) if (admitted and np.random.random() < 0.4) else 0

        records.append({
            "term": term, "program": program,
            "is_first_gen": is_first_gen, "is_international": is_international,
            "is_veteran": is_veteran, "is_transfer": is_transfer,
            "submitted": submitted, "complete": complete,
            "admitted": admitted, "enrolled": enrolled,
            "days_to_decision": days_to_decision,
            "scholarship_offered": scholarship
        })

    return pd.DataFrame(records)

df = generate_data(1200)
df.to_csv(os.path.join(os.path.dirname(__file__), "mock_enrollment_data.csv"), index=False)
print(f"✓ Generated {len(df)} applicant records")


# ── 2. FUNNEL ANALYSIS ──────────────────────────────────────────────────────
def plot_funnel():
    stages  = ["Inquired", "Submitted", "Complete", "Admitted", "Enrolled"]
    counts  = [
        len(df),
        df["submitted"].sum(),
        df["complete"].sum(),
        df["admitted"].sum(),
        df["enrolled"].sum(),
    ]
    colors  = [COLUMBIA_BLUE, "#5B96CE", "#3D7DB8", NAVY, GREEN]
    bar_w   = [c / counts[0] for c in counts]

    fig, ax = plt.subplots(figsize=(10, 5.5), facecolor=WHITE)
    ax.set_facecolor(WHITE)

    for i, (stage, count, bw, color) in enumerate(zip(stages, counts, bar_w, colors)):
        ax.barh(i, bw, color=color, height=0.55, zorder=3)
        ax.text(bw + 0.01, i, f"{count:,}  ({bw*100:.0f}%)",
                va="center", ha="left", fontsize=11, fontweight="600", color=NAVY)
        if i > 0:
            drop = counts[i-1] - count
            ax.text(-0.02, i - 0.5, f"▼ {drop:,} dropped",
                    va="center", ha="right", fontsize=8.5, color=CORAL)

    ax.set_yticks(range(len(stages)))
    ax.set_yticklabels(stages, fontsize=12, fontweight="500", color=NAVY)
    ax.set_xlim(-0.05, 1.25)
    ax.set_xlabel("Share of initial inquiry pool", fontsize=10, color=MID_GREY)
    ax.set_title("Enrollment Funnel — All Terms Combined", fontsize=14,
                 fontweight="700", color=NAVY, pad=14)
    ax.xaxis.set_major_formatter(mticker.PercentFormatter(xmax=1))
    ax.tick_params(axis="x", colors=MID_GREY, labelsize=9)
    ax.spines[:].set_visible(False)
    ax.grid(axis="x", color=LIGHT_GREY, zorder=0)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "01_funnel.png"), dpi=150, bbox_inches="tight", facecolor=WHITE)
    plt.close()
    print("✓ Saved funnel chart")


# ── 3. YIELD BY PROGRAM ─────────────────────────────────────────────────────
def plot_yield():
    yield_df = (df[df["admitted"]]
                .groupby("program")["enrolled"]
                .agg(admitted="count", enrolled="sum")
                .assign(yield_pct=lambda x: x["enrolled"] / x["admitted"] * 100)
                .sort_values("yield_pct", ascending=True))

    fig, ax = plt.subplots(figsize=(9, 4.5), facecolor=WHITE)
    ax.set_facecolor(WHITE)
    bars = ax.barh(yield_df.index, yield_df["yield_pct"],
                   color=[COLUMBIA_BLUE, NAVY, GREEN, GOLD], height=0.5, zorder=3)
    for bar, (_, row) in zip(bars, yield_df.iterrows()):
        ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height()/2,
                f"{row['yield_pct']:.1f}%  ({int(row['enrolled'])}/{int(row['admitted'])})",
                va="center", fontsize=10.5, fontweight="600", color=NAVY)

    ax.set_xlim(0, 100)
    ax.set_xlabel("Yield Rate (%)", fontsize=10, color=MID_GREY)
    ax.set_title("Yield Rate by Program (Enrolled / Admitted)", fontsize=14,
                 fontweight="700", color=NAVY, pad=14)
    ax.tick_params(axis="both", colors=MID_GREY, labelsize=9)
    ax.spines[:].set_visible(False)
    ax.grid(axis="x", color=LIGHT_GREY, zorder=0)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "02_yield_by_program.png"), dpi=150, bbox_inches="tight", facecolor=WHITE)
    plt.close()
    print("✓ Saved yield by program chart")


# ── 4. TERM-OVER-TERM ENROLLMENT TREND ──────────────────────────────────────
def plot_trend():
    trend = (df.groupby("term")[["submitted", "admitted", "enrolled"]]
               .sum()
               .reindex(TERMS))

    fig, ax = plt.subplots(figsize=(10, 5), facecolor=WHITE)
    ax.set_facecolor(WHITE)
    x = np.arange(len(TERMS))
    w = 0.26

    b1 = ax.bar(x - w, trend["submitted"], width=w, color=COLUMBIA_BLUE, label="Submitted", zorder=3)
    b2 = ax.bar(x,     trend["admitted"],  width=w, color=NAVY,          label="Admitted",  zorder=3)
    b3 = ax.bar(x + w, trend["enrolled"],  width=w, color=GREEN,         label="Enrolled",  zorder=3)

    for bars in [b1, b2, b3]:
        for bar in bars:
            h = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2, h + 3, f"{int(h)}",
                    ha="center", va="bottom", fontsize=8, color=NAVY, fontweight="500")

    ax.set_xticks(x)
    ax.set_xticklabels(TERMS, fontsize=10, color=NAVY)
    ax.set_ylabel("Applicant Count", color=MID_GREY, fontsize=10)
    ax.set_title("Term-over-Term Enrollment Trend", fontsize=14, fontweight="700", color=NAVY, pad=14)
    ax.legend(fontsize=10, framealpha=0)
    ax.spines[:].set_visible(False)
    ax.tick_params(colors=MID_GREY)
    ax.grid(axis="y", color=LIGHT_GREY, zorder=0)

    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "03_term_trend.png"), dpi=150, bbox_inches="tight", facecolor=WHITE)
    plt.close()
    print("✓ Saved term trend chart")


# ── 5. DEMOGRAPHIC BREAKDOWN (enrolled students only) ───────────────────────
def plot_demographics():
    enrolled_df = df[df["enrolled"]]
    total = len(enrolled_df)
    cats = {
        "Transfer":      enrolled_df["is_transfer"].sum(),
        "First-Gen":     enrolled_df["is_first_gen"].sum(),
        "International": enrolled_df["is_international"].sum(),
        "Veteran":       enrolled_df["is_veteran"].sum(),
    }

    fig, (ax_bar, ax_pie) = plt.subplots(1, 2, figsize=(12, 5), facecolor=WHITE)

    # Bar: raw counts
    ax_bar.set_facecolor(WHITE)
    colors_dem = [COLUMBIA_BLUE, GOLD, CORAL, GREEN]
    bars = ax_bar.bar(cats.keys(), cats.values(), color=colors_dem, width=0.5, zorder=3)
    for bar, (cat, val) in zip(bars, cats.items()):
        ax_bar.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 2,
                    f"{val}\n({val/total*100:.0f}%)",
                    ha="center", va="bottom", fontsize=10, fontweight="600", color=NAVY)
    ax_bar.set_title("Nontraditional Student Segments\n(Enrolled)", fontsize=12,
                     fontweight="700", color=NAVY)
    ax_bar.set_ylabel("Enrolled Students", color=MID_GREY, fontsize=10)
    ax_bar.spines[:].set_visible(False)
    ax_bar.tick_params(colors=NAVY, labelsize=10)
    ax_bar.grid(axis="y", color=LIGHT_GREY, zorder=0)

    # Pie: top programs for enrolled
    ax_pie.set_facecolor(WHITE)
    prog_counts = enrolled_df["program"].value_counts()
    wedge_colors = [COLUMBIA_BLUE, NAVY, GREEN, GOLD]
    wedges, texts, autotexts = ax_pie.pie(
        prog_counts.values, labels=prog_counts.index,
        autopct="%1.0f%%", colors=wedge_colors,
        startangle=140, pctdistance=0.75,
        wedgeprops={"linewidth": 1.5, "edgecolor": WHITE}
    )
    for t in texts:
        t.set_fontsize(9); t.set_color(NAVY)
    for at in autotexts:
        at.set_fontsize(9); at.set_fontweight("600"); at.set_color(WHITE)
    ax_pie.set_title("Enrolled by Program", fontsize=12, fontweight="700", color=NAVY)

    plt.suptitle("Who We're Enrolling — Demographic & Program Snapshot",
                 fontsize=13, fontweight="700", color=NAVY, y=1.02)
    plt.tight_layout()
    plt.savefig(os.path.join(OUT_DIR, "04_demographics.png"), dpi=150, bbox_inches="tight", facecolor=WHITE)
    plt.close()
    print("✓ Saved demographics chart")


# ── 6. KEY METRICS SUMMARY TABLE ────────────────────────────────────────────
def print_summary():
    total        = len(df)
    submitted    = df["submitted"].sum()
    admitted     = df["admitted"].sum()
    enrolled     = df["enrolled"].sum()
    avg_days     = df["days_to_decision"].dropna().mean()
    yield_rate   = enrolled / admitted * 100
    conv_rate    = enrolled / total * 100

    print("\n" + "="*50)
    print("  COLUMBIA GS — ENROLLMENT SUMMARY")
    print("="*50)
    print(f"  Total Inquiries:         {total:,}")
    print(f"  Applications Submitted:  {submitted:,}  ({submitted/total*100:.1f}%)")
    print(f"  Admitted:                {admitted:,}  ({admitted/total*100:.1f}%)")
    print(f"  Enrolled:                {enrolled:,}  ({enrolled/total*100:.1f}%)")
    print(f"  Yield Rate:              {yield_rate:.1f}%")
    print(f"  Avg Days to Decision:    {avg_days:.0f} days")
    print(f"  Overall Conversion:      {conv_rate:.1f}%")
    print("="*50 + "\n")

    # Save as CSV too
    summary = pd.DataFrame([{
        "Total Inquiries": total, "Submitted": submitted,
        "Admitted": admitted, "Enrolled": enrolled,
        "Yield Rate %": round(yield_rate,1),
        "Avg Days to Decision": round(avg_days,0),
        "Overall Conversion %": round(conv_rate,1)
    }])
    summary.to_csv(os.path.join(os.path.dirname(__file__), "enrollment_summary_stats.csv"), index=False)
    print("✓ Saved summary stats CSV")


# ── RUN ALL ──────────────────────────────────────────────────────────────────
plot_funnel()
plot_yield()
plot_trend()
plot_demographics()
print_summary()

print("\n✓ All outputs saved. Charts → /dashboard/  |  Data → /data/")
