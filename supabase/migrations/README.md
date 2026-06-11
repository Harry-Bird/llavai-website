# supabase/migrations — what's here and what isn't

The live project (`bwgaolpmarlnwbcrklzc`) has 11 applied migrations in
`supabase_migrations.schema_migrations`:

| version | name | in this dir? |
|---|---|---|
| 20260609081621 | harden_security_definer_functions | no — applied via dashboard/MCP |
| 20260609155330 | supabase_first_profile_fields_and_trigger | no — applied via dashboard/MCP |
| 20260609162210 | feed_search_clients_view | no — applied via dashboard/MCP |
| 20260609180037 | backend_rebuild_phase0_schema | no — applied via dashboard/MCP |
| 20260609180954 | feed_search_clients_add_prefs | no — applied via dashboard/MCP |
| 20260609191414 | teaser_listings_view | no — applied via dashboard/MCP |
| 20260609193052 | viewings_self_manage_policies | no — applied via dashboard/MCP |
| 20260609194023 | get_call_client_rpc | no — applied via dashboard/MCP |
| 20260609203025 | get_call_client_add_tier | no — applied via dashboard/MCP |
| 20260609210151 | w2_call_attempts_post_call_columns | no — applied via dashboard/MCP |
| 20260610231217 | business_hours_call_queue | **yes** (file in this dir) |

The earlier migrations were applied straight to production via the Supabase
dashboard SQL editor / MCP `apply_migration` and their individual SQL bodies
were never committed, so they can't be reconstructed file-by-file — only their
**cumulative result** is recoverable. That cumulative result is the canonical
snapshot in **`../schema.sql`** (regenerated from the live DB on 2026-06-11);
treat it as the source of truth for "what does production look like".

Going forward:
- every new migration gets a file here, named `<version>_<name>.sql` with the
  version matching `schema_migrations` exactly;
- candidate migrations awaiting review live in `../proposed/` and move here
  once applied;
- after a batch of migrations, regenerate `../schema.sql` from live so the
  snapshot never drifts again (audit finding M6).
