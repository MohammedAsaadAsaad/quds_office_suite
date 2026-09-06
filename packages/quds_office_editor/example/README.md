# Quds Office Studio

Host example for `quds_office_editor`: a bilingual Word / Excel / PowerPoint workspace
with ribbons, sample documents, and the custom RenderBox canvases.

## Run

```bash
cd packages/quds_office_editor/example
flutter run
```

## What to try

### Word
- **Home** — select a range, then bold / italic / underline / strike / superscript /
  subscript / color / highlight / grow-shrink. Alignment, lists, indent.
- **Insert** — heading, paragraph, quote, page break, tables 2×2 / 3×3 / 4×4,
  picture, column / bar / pie / line charts, process / cycle / hierarchy diagrams.
- **Layout** — RTL/LTR, line spacing, A4 / Letter.
- **Review** — select all / word / paragraph, undo / redo.
- **View** — rulers and zoom. Double-click a word, triple-click a paragraph,
  drag across a table. `Ctrl+Z` / `Ctrl+Y`.

### Excel
- Three sample sheets: Budget (SUM / AVERAGE / MAX), Roster (COUNTA), Catalog.
- **Home** — F2 edit, clear selection, select row / column, insert column / pie chart
  from the selected cells.
- **Formulas** — SUM, AVERAGE, MIN, MAX, COUNT, COUNTA, IF (uses the current
  selection, or the cells to the left of the focus).
- **Data** — insert / delete sheets; column / pie / line charts. Formula bar above
  the grid. Freeze header row.

### PowerPoint
- Five-slide tour of the suite tools.
- **Home** — new / duplicate / delete slide, nudge, bring forward / send back.
- **Insert** — card, title, accent, picture, column / pie charts, process diagram.
- **Design** — cycle fill, center on slide, set shape text.
- Drag a card: snap guides appear only when edges align.

### File
New blank document, open / save OOXML, reload the in-memory sample.
Switch Edit · Select · View from File or Settings.

Chrome (ribbons, panes, formula bar) is Material. The page, grid, and stage
are custom `RenderBox` editors — not `TextField` / `ListView`.
