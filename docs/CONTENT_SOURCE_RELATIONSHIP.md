# Content Source: ice-cream-book

This document describes how `cloud-platform-demo` consumes content from its companion repository, [`PitziLabs/ice-cream-book`](https://github.com/PitziLabs/ice-cream-book), to build and serve the website at **icecreamtofightover.com**.

## Architecture Overview

```
PitziLabs/ice-cream-book          PitziLabs/cloud-platform-demo
────────────────────────          ─────────────────────────

recipes/*.md                      app/ice_cream_site/
  (28 recipe Markdown files)        │
         │                          ├── sync_recipes.py ◄── reads recipes
         │                          ├── src/
         │    RECIPE_SOURCE         │   ├── content/recipes/  ◄── writes here
         └──────────────────────────┤   ├── pages/
                                    │   └── layouts/
                                    ├── astro.config.mjs
                                    └── Dockerfile
                                            │
                                            ▼
                                    modules/ecr/        → container registry
                                    modules/ecs/        → Fargate service
                                    modules/alb/        → load balancer
                                    modules/dns/        → icecreamtofightover.com
```

## The Bridge: sync_recipes.py

The file `app/ice_cream_site/sync_recipes.py` is the only integration point between the two repos. It:

1. **Locates recipes** via the `RECIPE_SOURCE` environment variable (CI/CD) or falls back to `../ice-cream-book/recipes/` (local dev)
2. **Parses each recipe** — extracts title, subtitle, difficulty tier, total time, and recipe number from the Markdown structure
3. **Generates YAML frontmatter** — wraps the extracted metadata in Astro-compatible frontmatter
4. **Writes content files** to `src/content/recipes/`, where Astro picks them up as a content collection

### Parsed Fields

| Source Pattern | Frontmatter Key | Type |
|---------------|----------------|------|
| Filename `##_name.md` | `recipeNumber`, `recipeSlug` | int, string |
| First `# ` heading | `title` | string |
| First `*italic*` line | `subtitle` | string |
| `**Difficulty:**` line | `tier`, `tierOrder`, `tierColor`, `difficultyText` | string, int, string, string |
| `**Total Time:**` line | `totalTime` | string |

### Difficulty Tier Mapping

The script maps difficulty labels to display properties:

| Tier Name | Order | Color |
|-----------|-------|-------|
| CHILL | 1 | `#7ecfb3` |
| LEGIT | 2 | `#f2c94c` |
| THE REAL DEAL | 3 | `#f2994a` |
| A FUCKING ORDEAL | 4 | `#eb5757` |

## How Content Flows Through the Stack

### Local Development

Expects both repos cloned as siblings:

```
~/projects/
├── ice-cream-book/
│   └── recipes/*.md
└── cloud-platform-demo/
    └── app/ice_cream_site/
        └── sync_recipes.py   # reads ../ice-cream-book/recipes/
```

Run the sync, then build:

```bash
cd app/ice_cream_site
python sync_recipes.py
npm run build
```

### CI/CD Pipeline

In the GitHub Actions workflow, the pipeline:

1. Checks out `ice-cream-book` (or fetches its recipe files)
2. Sets `RECIPE_SOURCE` to point at the checkout location
3. Runs `sync_recipes.py` to generate Astro content
4. Runs `npm run build` to produce static HTML in `dist/`
5. Builds the Docker image (`app/Dockerfile` copies `dist/` into nginx)
6. Pushes to ECR, deploys to ECS Fargate

### Serving Layer

The Dockerfile is minimal — nginx serves the pre-built static files:

- Port 8080 (ALB forwards HTTPS :443 here)
- `/health` endpoint for ALB health checks
- Clean URLs (Astro generates `/recipes/01_coconut_pandan/index.html`, nginx serves it at `/recipes/01_coconut_pandan`)
- 1-year cache on static assets (CSS, JS, images)

## What Content Changes Mean for This Repo

| Change in ice-cream-book | Impact Here |
|--------------------------|-------------|
| Edit recipe text | None — picked up automatically on next build |
| Add a new recipe `.md` | None — `sync_recipes.py` globs `*.md` automatically |
| Remove a recipe | The URL disappears on next deploy; no redirect handling exists yet |
| Rename a recipe file | URL slug changes; old URL returns 404 |
| Change recipe format conventions | **Requires updating `sync_recipes.py`** to match new patterns |

## What This Repo Does NOT Consume

The `ice-cream-book` repo also contains content that is **not** used by the website:

- `front_matter/` — Book introduction, philosophy, custard fundamentals (book-only)
- `back_matter/` — Book closing section (book-only)
- `compile_book.py` / `compile_book.sh` — Compiles all sections into a single Markdown document for the print/digital book
- `STYLE_GUIDE.md` — Editorial guidelines for recipe writing
- `Ice_Cream_to_Fight_Over_COMPLETE.md` — The compiled full book

Only `recipes/*.md` crosses the boundary into this repo.

## Dependencies and Coupling

The coupling between the two repos is intentionally thin:

- **Single integration point**: `sync_recipes.py` is the only file that knows about `ice-cream-book`
- **Convention-based**: Parsing relies on Markdown formatting conventions, not a formal schema or API
- **One-directional**: Content flows from `ice-cream-book` → `cloud-platform-demo`, never the reverse
- **No git submodule**: The repos are independent; content is synced at build time, not linked at the git level
