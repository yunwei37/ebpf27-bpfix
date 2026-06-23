#!/usr/bin/env python3
from pathlib import Path

import matplotlib.pyplot as plt


OUTPUT = Path(__file__).resolve().parents[1] / "figures" / "sec-5-bpfix-test.pdf"

MODELS = [
    {
        "title": "Qwen3.6 27B",
        "label": "Qwen3.6",
        "color": "#4C78A8",
        "one_shot": {"raw": 29.3, "bpfix": 50.7},
        "retry": {"raw": 40.0, "bpfix": 58.7},
    },
    {
        "title": "GLM 5.2",
        "label": "GLM 5.2",
        "color": "#F58518",
        "one_shot": {"raw": 37.3, "bpfix": 50.7},
        "retry": {"raw": 62.7, "bpfix": 69.3},
    },
    {
        "title": "Qwen2.5 3B",
        "label": "Qwen2.5",
        "color": "#54A24B",
        "one_shot": {"raw": 0.0, "bpfix": 10.7},
        "retry": {"raw": None, "bpfix": None},
    },
]


def annotate(ax, bar, value, rank):
    height = bar.get_height()
    y = (height + 1.2 if height > 0 else 1.2) + rank * 2.1
    ha = "center"
    x = bar.get_x() + bar.get_width() / 2
    if rank == 0:
        ha = "right"
        x -= 0.01
    elif rank == 1:
        ha = "left"
        x += 0.01
    ax.text(
        x,
        y,
        f"{value:.1f}",
        ha=ha,
        va="bottom",
        fontsize=6,
    )


def draw_grouped(ax):
    groups = [
        ("Raw\n1 try", "one_shot", "raw"),
        ("BPFix\n1 try", "one_shot", "bpfix"),
        ("Raw\nretry", "retry", "raw"),
        ("BPFix\nretry", "retry", "bpfix"),
    ]
    width = 0.20
    offsets = [-width, 0, width]
    x = list(range(len(groups)))

    for model_idx, model in enumerate(MODELS):
        for group_idx, (_, attempt_key, prompt_key) in enumerate(groups):
            value = model[attempt_key][prompt_key]
            if value is None:
                continue
            bars = ax.bar(
                x[group_idx] + offsets[model_idx],
                value,
                width,
                color=model["color"],
                edgecolor="#222222",
                linewidth=0.55,
                label=model["label"] if group_idx == 0 else None,
            )
            annotate(ax, bars[0], value, model_idx)

    for group_idx in [2, 3]:
        ax.text(
            x[group_idx] + offsets[2],
            5,
            "n/r",
            ha="center",
            va="bottom",
            fontsize=6,
            color="#555555",
        )

    ax.set_xticks(x)
    ax.set_xticklabels([group[0] for group in groups], fontsize=7)
    ax.set_ylim(0, 80)
    ax.set_yticks([0, 25, 50, 75])
    ax.tick_params(axis="y", labelsize=7)
    ax.grid(axis="y", color="#e6e6e6", linewidth=0.6)
    ax.set_axisbelow(True)
    for spine in ["top", "right"]:
        ax.spines[spine].set_visible(False)
    ax.set_ylabel("Repair success (%)", fontsize=7)


def main():
    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "pdf.fonttype": 42,
            "ps.fonttype": 42,
        }
    )
    fig, ax = plt.subplots(figsize=(3.45, 2.35))
    draw_grouped(ax)

    handles, labels = ax.get_legend_handles_labels()
    fig.legend(
        handles,
        labels,
        loc="lower center",
        ncol=3,
        frameon=False,
        fontsize=6.5,
        bbox_to_anchor=(0.5, -0.02),
    )
    fig.tight_layout(rect=(0, 0.12, 1, 1))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUTPUT, format="pdf", bbox_inches="tight")


if __name__ == "__main__":
    main()
