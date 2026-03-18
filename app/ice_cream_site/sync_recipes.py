#!/usr/bin/env python3
"""
Convert ice_cream_book recipe markdown files into Astro-compatible
content files with YAML frontmatter.

Reads from: ../ice_cream_book/recipes/*.md
Writes to:  src/content/recipes/*.md

Parses the inline metadata (title, subtitle, difficulty, tier, time)
from the existing markdown format and generates proper YAML frontmatter
that Astro's content collections can consume.
"""

import re
import os
import sys
from pathlib import Path

REPO_RECIPES = Path(__file__).parent.parent / "ice_cream_book" / "recipes"
OUTPUT_DIR = Path(__file__).parent / "src" / "content" / "recipes"

TIER_MAP = {
    "CHILL": {"order": 1, "color": "#7ecfb3", "label": "CHILL"},
    "LEGIT": {"order": 2, "color": "#f2c94c", "label": "LEGIT"},
    "THE REAL DEAL": {"order": 3, "color": "#f2994a", "label": "THE REAL DEAL"},
    "A FUCKING ORDEAL": {"order": 4, "color": "#eb5757", "label": "A FUCKING ORDEAL"},
}


def parse_recipe(filepath):
    """Parse a recipe markdown file and extract metadata + body."""
    text = filepath.read_text(encoding="utf-8")
    lines = text.split("\n")

    metadata = {
        "title": "",
        "subtitle": "",
        "tier": "",
        "tier_order": 0,
        "tier_color": "",
        "difficulty_text": "",
        "total_time": "",
        "recipeSlug": filepath.stem,
        "recipe_number": 0,
    }

    # Extract recipe number from filename (e.g., 01_coconut_pandan.md -> 1)
    num_match = re.match(r"(\d+)_", filepath.name)
    if num_match:
        metadata["recipe_number"] = int(num_match.group(1))

    # Parse title: first H1
    for line in lines:
        if line.startswith("# "):
            metadata["title"] = line[2:].strip()
            break

    # Parse subtitle: first italic line
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("*") and stripped.endswith("*") and not stripped.startswith("**"):
            metadata["subtitle"] = stripped.strip("*").strip()
            break

    # Parse difficulty line
    for line in lines:
        if line.startswith("**Difficulty:**"):
            diff_text = line.replace("**Difficulty:**", "").strip()
            # Extract tier name
            for tier_name in TIER_MAP:
                if diff_text.upper().startswith(tier_name):
                    metadata["tier"] = tier_name
                    metadata["tier_order"] = TIER_MAP[tier_name]["order"]
                    metadata["tier_color"] = TIER_MAP[tier_name]["color"]
                    break
            # Get the full difficulty description (after " - ")
            dash_idx = diff_text.find(" - ")
            if dash_idx >= 0:
                metadata["difficulty_text"] = diff_text[dash_idx + 3:].strip()
            break

    # Parse total time
    for line in lines:
        if line.startswith("**Total Time:**"):
            metadata["total_time"] = line.replace("**Total Time:**", "").strip()
            break

    # Build the body: everything after the Total Time line
    # We skip title, subtitle, difficulty, time — those go in frontmatter
    body_started = False
    body_lines = []
    skip_next_blank = False

    for i, line in enumerate(lines):
        if line.startswith("**Total Time:**"):
            body_started = True
            skip_next_blank = True
            continue
        if body_started:
            if skip_next_blank and line.strip() == "":
                skip_next_blank = False
                continue
            skip_next_blank = False
            body_lines.append(line)

    body = "\n".join(body_lines).strip()

    # Remove trailing --- separator if present
    if body.endswith("---"):
        body = body[:-3].rstrip()

    return metadata, body


def generate_frontmatter(metadata):
    """Generate YAML frontmatter string."""
    # Escape any quotes in strings
    def esc(s):
        return s.replace('"', '\\"')

    return f"""---
title: "{esc(metadata['title'])}"
subtitle: "{esc(metadata['subtitle'])}"
tier: "{esc(metadata['tier'])}"
tierOrder: {metadata['tier_order']}
tierColor: "{metadata['tier_color']}"
difficultyText: "{esc(metadata['difficulty_text'])}"
totalTime: "{esc(metadata['total_time'])}"
recipeSlug: "{metadata['slug']}"
recipeNumber: {metadata['recipe_number']}
---"""


def main():
    if not REPO_RECIPES.exists():
        print(f"Error: Recipe directory not found at {REPO_RECIPES}")
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    recipe_files = sorted(REPO_RECIPES.glob("*.md"))
    print(f"Found {len(recipe_files)} recipe files")

    for filepath in recipe_files:
        metadata, body = parse_recipe(filepath)
        frontmatter = generate_frontmatter(metadata)
        output = f"{frontmatter}\n\n{body}\n"

        out_path = OUTPUT_DIR / filepath.name
        out_path.write_text(output, encoding="utf-8")
        print(f"  ✓ {filepath.name} → {metadata['title']} [{metadata['tier']}]")

    print(f"\nDone! {len(recipe_files)} recipes written to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
