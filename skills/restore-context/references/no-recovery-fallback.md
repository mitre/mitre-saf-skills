# Restoring Without a Recovery File

This is the normal path for new developers or new machines. Recovery files are local convenience — the shared board has everything needed.

1. Sync the shared board: `bd dolt pull`
2. Load shared decisions: `bd memories`
3. Read the board: `bd ready`, `bd show <epic-id>`
4. Read card notes on in-progress tasks — the handoff mechanism for other devs
5. Read CLAUDE.md for project overview
6. Check git log for recent activity
7. Check for local archive: `ls -t .beads/archive/recovery-context-*.md 2>/dev/null | head -1`
8. If still unclear, ask the user what epic/goal to focus on
