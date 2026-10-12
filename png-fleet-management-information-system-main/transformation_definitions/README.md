# FMS Modernization — Phased Transformation Definitions

The combined TD (`../FMS_Phase2_Transformation_Definition.md`) is split into 4 standalone TDs for phased AWS Transform Custom execution. Run them in order; validate each before starting the next.

| # | TD file | Name (for `atx -n`) | What it does |
|---|---------|---------------------|--------------|
| 1 | `01-fms-framework-migration.md` | `fms-framework-migration-execution` | ASP.NET MVC 5 / .NET Framework → ASP.NET Core / .NET 8; EF6 → EF Core 8; remove System.Web |
| 2 | `02-fms-authentication.md` | `fms-authentication-execution` | OWIN/Forms/Membership → ASP.NET Core Identity |
| 3 | `03-fms-database-cleanup.md` | `fms-database-cleanup-execution` | Remove 67 dead procs + 3 dead tables; flag T-SQL compat findings |
| 4 | `04-fms-cloud-readiness.md` | `fms-cloud-readiness-execution` | Containerize for AWS ECS/Fargate (single instance) |

## Execution order & rationale
1. **Framework first** — all later changes operate on the new ASP.NET Core code.
2. **Auth second** — Identity wires into the Phase 1 pipeline + filters.
3. **DB cleanup third** — legacy `aspnet_*` procs removable only after auth moves off Membership.
4. **Cloud last** — containerization needs the final code state.

## Execution — two paths

### A) Local (WSL, with CAST MCP) — original path
Requires WSL2 on Windows. Helper: `run-phase1.sh` (installs toolchain + runs a DRY RUN).
Run inside WSL; start each phase with a dry run (no `-x`) to preview.
```bash
atx custom def exec \
  -n "fms-framework-migration-execution" \
  -p "/mnt/d/PoC_ProjectCode/FMS_Code/png-fleet-management-information-system-main/png-fleet-management-information-system-main" \
  -x -t \
  --mcp-config ./mcp.json
```
Repeat for `fms-authentication-execution`, `fms-database-cleanup-execution`, `fms-cloud-readiness-execution`.

### B) Remote (AWS Transform) — WSL-free path
Use when local WSL2 is unavailable (e.g. hypervisor blocked by corporate policy). The
transformation runs in AWS against the GitHub repo URL — no local hypervisor needed.
See `run-phase1-remote.md` for the full procedure, IAM policy, and the CAST-MCP
reachability constraint (AWS can't reach a laptop `localhost`/internal CAST host, so remote
typically runs WITHOUT `--mcp-config` and is verified from the IDE afterward).

CAST Imaging MCP is used for live caller checks, blast-radius analysis, and violation-delta
verification. In the local path it stays connected during the run; in the remote path those
checks move to a post-run verification step performed from this IDE.
