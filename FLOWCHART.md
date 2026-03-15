# Ralph Flowchart — Interactive Workflow Visualization

An interactive, step-by-step flowchart that explains how [Ralph](README.md) works. Built with React, TypeScript, and [@xyflow/react](https://reactflow.dev/) (formerly React Flow).

**[View the live flowchart](https://snarktank.github.io/ralph/)**

> The source code for this app has been removed from the repository. This document preserves the full architectural documentation for reference.

## What It Does

This app renders Ralph's 10-step autonomous agent loop as a node-and-edge diagram. Instead of reading a wall of text, users click **Previous / Next** to reveal each step one at a time, with fade-in animations and contextual annotations that appear at key moments.

### The 10 Steps

| #  | Node Label           | Description                  | Phase    | Color  |
|----|----------------------|------------------------------|----------|--------|
| 1  | You write a PRD      | Define what you want to build | Setup    | Blue   |
| 2  | Convert to prd.json  | Break into small user stories | Setup    | Blue   |
| 3  | Run ralph.sh         | Starts the autonomous loop    | Setup    | Blue   |
| 4  | AI picks a story     | Finds next `passes: false`    | Loop     | Gray   |
| 5  | Implements it        | Writes code, runs tests       | Loop     | Gray   |
| 6  | Commits changes      | If tests pass                 | Loop     | Gray   |
| 7  | Updates prd.json     | Sets `passes: true`           | Loop     | Gray   |
| 8  | Logs to progress.txt | Saves learnings               | Loop     | Gray   |
| 9  | More stories?        | Decision point                | Decision | Yellow |
| 10 | Done!                | All stories complete           | Done     | Green  |

### Annotation Notes

Two contextual notes appear alongside specific steps:

- **Step 2** — A sample `prd.json` snippet showing the user story format (`id`, `title`, `acceptanceCriteria`, `passes`).
- **Step 8** — A note explaining that the agent also updates `AGENTS.md` with patterns discovered during the iteration, so future iterations learn from previous ones.

## Tech Stack

| Tool                                                        | Version | Purpose                        |
|-------------------------------------------------------------|---------|--------------------------------|
| [React](https://react.dev/)                                 | 19.2    | UI framework                   |
| [TypeScript](https://www.typescriptlang.org/)               | 5.9     | Type safety                    |
| [Vite](https://vite.dev/)                                   | 7.2     | Dev server and bundler         |
| [@xyflow/react](https://reactflow.dev/)                     | 12.10   | Interactive flow diagrams      |
| [ESLint](https://eslint.org/)                               | 9.x     | Linting                        |

## Project Structure

The original source was organized as:

```
flowchart/
├── index.html              # HTML entry point (title: "How Ralph Works")
├── package.json            # Dependencies and scripts
├── vite.config.ts          # Vite config (base: /ralph/ for deployment)
├── tsconfig.json           # TypeScript project references
├── tsconfig.app.json       # App-level TS config (DOM, React JSX)
├── tsconfig.node.json      # Node-level TS config (Vite config file)
├── eslint.config.js        # ESLint configuration
├── public/
│   └── vite.svg            # Favicon
└── src/
    ├── main.tsx            # React entry point (StrictMode, createRoot)
    ├── App.tsx             # Main flowchart component (~380 lines)
    ├── App.css             # All component styles
    ├── index.css           # Global styles (font smoothing, reset)
    └── assets/
        └── react.svg       # React logo asset
```

## Architecture

Everything lived in a single component (`App.tsx`). Here's how it was structured:

### Data Model

Steps, positions, edges, and notes were all defined as plain arrays/objects at the module level:

- **`allSteps`** — Array of 10 step objects with `id`, `label`, `description`, and `phase` (setup | loop | decision | done).
- **`positions`** — Maps each node ID to `{ x, y }` coordinates. Setup steps run vertically on the left; loop steps form a circular path; the exit node sits at the bottom center.
- **`edgeConnections`** — Defines source/target pairs with specific handle positions (`top`, `bottom`, `left`, `right`). The loop-back edge (step 9 → 4, labeled "Yes") and exit edge (step 9 → 10, labeled "No") make the decision point work.
- **`notes`** — Annotation nodes that appear at a specific `appearsWithStep` threshold.
- **`phaseColors`** — Maps each phase to a `{ bg, border }` color pair.

### Custom Node Types

Two custom node types registered via `nodeTypes`:

- **`CustomNode`** — Renders a rounded box with a title and optional description. Has 8 handles (top, bottom, left, right, each as both source and target) to support flexible edge routing. Background and border color are driven by the step's phase.
- **`NoteNode`** — Renders a dashed-border box with monospace `<pre>` text. Used for contextual annotations (prd.json example, AGENTS.md note).

### State and Interaction

- **`visibleCount`** (useState) — Controls how many steps are currently revealed (starts at 1).
- **`nodePositions`** (useRef) — Tracks node positions across drags so that stepping forward/backward preserves any manual repositioning.
- **`handleNext` / `handlePrev`** — Increment/decrement `visibleCount`, then rebuild nodes and edges. Nodes beyond the visible count get `opacity: 0` with a `0.5s ease-in-out` CSS transition. Edges only appear when both their source and target nodes are visible.
- **`handleReset`** — Returns to step 1 and restores all nodes to their original positions.
- **Drag support** — Nodes are draggable; position changes are captured via `onNodesChange` so they persist across step transitions.
- **Edge reconnection** — Edges can be reconnected to different handles via `onReconnect`.
- **New connections** — Users can draw new edges between nodes via `onConnect`.

### Layout

The page is a full-viewport flex column:

```
┌─────────────────────────────────────────────┐
│               Header                        │  "How Ralph Works" + subtitle
├─────────────────────────────────────────────┤
│                                             │
│            ReactFlow Canvas                 │  Zoomable, pannable, with dot grid
│            (flex: 1)                        │  background and zoom controls
│                                             │
├─────────────────────────────────────────────┤
│  [Previous]  Step 3 of 10  [Next]  [Reset]  │
├─────────────────────────────────────────────┤
│         "Click Next to reveal"              │
└─────────────────────────────────────────────┘
```

### Styling

- **Nodes** — 240x70px, 8px border-radius, 2px solid border, phase-colored background.
- **Note nodes** — Dashed border, monospace font (SF Mono / Monaco / Fira Code), max-width 360px.
- **Handles** — 10x10px circles with gray fill, darken on hover.
- **Buttons** — 2px bordered, invert to dark on hover, disabled at 30% opacity.
- **Controls overlay** — Minimal box-shadow, thin border.
- **Font stack** — System fonts (`-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto`).

## Deployment

The Vite config used `base: '/ralph/'`, meaning the built assets are served from a `/ralph/` path prefix. The live version is hosted on GitHub Pages at [snarktank.github.io/ralph/](https://snarktank.github.io/ralph/).
