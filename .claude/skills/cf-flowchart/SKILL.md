---
name: cf-flowchart
category: visual
description: When the user asks to create a decision tree, build a flowchart, map a process with conditions, or visualize branching logic — activate this skill for flowchart and decision tree generation
---

# Flowchart Decision Builder

Generates decision trees and flowcharts from textual input to simplify complex decision-making processes.

## Activation

- User says "flowchart this", "decision tree for", "map this process"
- User has conditional logic or multi-path process to visualize
- User needs if/then branching mapped out

## Process

### 1. Identify Steps and Decisions
- Extract sequential steps (rectangles)
- Identify decision points (diamonds) with yes/no or multi-path outcomes

### 2. Map Conditional Paths
- Connect each decision to its outcomes
- Trace all paths to terminal states

### 3. Structure Layout
- Top-to-bottom or left-to-right flow
- Minimize crossing connections
- Label all edges

## Output

- Node list (type: process/decision/terminal, label)
- Connection list (source → target, condition label)
- Layout direction suggestion
- Mermaid or text-based diagram syntax if requested
