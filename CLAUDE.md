# CLAUDE.md

## How to work with me

When you identify a performance issue, architectural decision, or infrastructure change:

1. Name the system design concept at play (e.g. "this is a read-write tradeoff", "this is replication lag", "this is an N+1 caused by scatter-gather across associations")
2. Explain WHY the current code creates the problem at the database/system level - what's actually happening on disk, in memory, or across the network
3. Show the fix
4. Explain what tradeoff the fix introduces

Don't just add an index — tell me what the query planner is doing without it and what changes with it. Don't just add a cache — tell me what consistency guarantee I'm giving up.

Treat every code change as a teaching moment about the system underneath.
