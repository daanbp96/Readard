---
description: Review the current diff for spoiler-safety regressions
argument-hint: [git-range, defaults to HEAD~1..HEAD]
---

Spawn the `spoiler-safety-reviewer` subagent against the diff range `$ARGUMENTS` (or `HEAD~1..HEAD` if no argument was given). Pass the range explicitly in the agent prompt so it knows what to inspect. Relay the agent's verdict and findings verbatim — do not paraphrase or add commentary.
