# AGENTS.md — Es Cekek

> This file is the entry point for every AI coding agent (Cline, Roo Code, Codex, Gemini CLI, Cursor, Copilot, …).

## MANDATORY WORKFLOW — do not skip

1. **Read [`context.md`](context.md) FIRST.** It contains the architecture, the autoload order, the
   implementer decisions, the tuning parameters, the Godot gotchas and the list of known bugs.
2. **Read [`todo.md`](todo.md) SECOND.** It contains the ordered task list, the acceptance criteria
   and the current in-flight task. Only ONE task may be `🔄 In Progress` at a time.
3. **Do the work** on the top pending / in-progress task.
4. **Update BOTH files before you finish.** This is mandatory — it is what stops development from
   going in circles:

   - [`todo.md`](todo.md)
     - tick the boxes you completed (`[x]`), drop what you abandon (`[~]`) with a reason
     - move the task you worked on to `🔄 In Progress` if it is not finished
     - add a row to **Session Log** (what changed + the test result)
     - keep the **Known Issues** list in sync
   - [`context.md`](context.md)
     - update **Task Progress** table
     - update **Test Status** with the real pass/fail count
     - update **Known Issues / Risks** (especially anything left half-done)
     - move the last change to the top of **Recent Changes**

5. **Run the tests** and report the real result. Never claim green without running:
   ```
   scripts\run_tests.cmd
   ```
   The suite must be run as a **scene** (`res://tests/runtime_test.tscn`) — never with
   `godot --script`, which breaks autoload resolution.

## Rules

- **Never** delete a task from `todo.md` to make the list look clean.
- **Never** change the 5 Implementer Decisions or the tuning parameters without saying so
  explicitly in `todo.md` and `context.md`.
- If the project is left in a broken/half-done state, **write it in both files** — a future agent
  must be able to see the breakage without re-discovering it.
- Comments in code are written in **Indonesian**; identifiers stay in English.
- Touch targets are **≥ 48dp**. Typed arrays are mandatory for GDScript API boundaries
  (`Array.map()` returns an untyped array and will not pass an `Array[Tool]` parameter).
