# Runtime pitfalls

- **Localization:** MCM uses localization handles. Update the English and Brazilian Portuguese XML values when changing handled labels in the blueprint.
- **Lua reload:** Filesystem junctions expose source edits, but loaded Lua remains cached. Reload the VM before testing. If MCP reset fails with `Unknown message type: request, reset`, use developer-mode `Ext.Debug.Reset(true, false)` and verify the new server generation.
- **Test results:** Console evaluations can return `context_generation_changed` after DribbleSpec finishes. Check the newest Runtime Log before deciding whether the run completed; require a nonzero test count. Use tag filters or single-word `--name` filters; quoted multiword filters can select zero tests.
- **Engine doubles:** Keep engine-call doubles in the offline Lua tests. Runtime DribbleSpec tests use real engine queries and stub mod-owned methods.
