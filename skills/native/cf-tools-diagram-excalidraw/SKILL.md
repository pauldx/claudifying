---
name: cf-tools-diagram-excalidraw
category: visual
description: When the user asks to create a diagram, visualize a workflow, map out a system, or generate Excalidraw-compatible diagram instructions — activate this skill for structured diagram generation
---

# Excalidraw Diagram Generator

Transforms textual concepts, workflows, or architectures into clear diagram instructions suitable for Excalidraw or other visual tools.

## Activation

- User says "diagram this", "visualize this workflow", "draw this system"
- User needs architecture map, process flow, or concept visualization
- User mentions Excalidraw specifically

## Process

### 1. Identify Elements
- Extract main concepts, actors, systems, or steps
- Determine relationships and hierarchy

### 2. Create Nodes
- Define node labels, shapes (rectangle, circle, diamond for decisions)
- Group related nodes

### 3. Connect
- Map connections with directional arrows
- Label edges where meaning isn't obvious

### 4. Layout
- Suggest left-to-right or top-to-bottom flow
- Minimize crossing lines

## Output

- Diagram title
- Node list with shapes and labels
- Connection list (source → target, label)
- Layout suggestion (direction, grouping)
- Optional: Excalidraw JSON if requested
