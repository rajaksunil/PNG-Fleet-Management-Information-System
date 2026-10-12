# fms-database-cleanup-execution

## Description
PHASE 3 of 4 — Apply CAST Database Migration advisor (id 1202139) findings for SQL Server retained on AWS RDS: remove dead stored procedures/tables (safe cleanup) and review T-SQL compatibility findings (flagged, not executed, since SQL Server is retained). Runs AFTER Phase 2 because the legacy `aspnet_*` membership procedures become removable only once auth moves to ASP.NET Core Identity.

> CAST application name for all MCP calls: **FMS**. Source: assessment delivery `Onboarding-202609031657`.

## Entry Criteria
1. Phase 2 (fms-authentication) completed — legacy Membership auth replaced by ASP.NET Core Identity.
2. CAST Imaging MCP server configured and responding (application: **FMS**).
3. A backup/snapshot of the SQL Server database exists (dead-code removal is destructive to the schema).

## Implementation Steps

### 3A. Remove unused stored procedures — 67 procs (rule 1202372)
Dominated by legacy `aspnet_*` membership/personalization procs (`aspnet_Membership_*`, `aspnet_Roles_*`, `aspnet_PersonalizationPerUser_*`, `aspnet_Profile_*`) and `sp_tr_*` session-state procs — all obsolete after Phase 2.
BEFORE removing the app-specific procs in this list — `USP_VehicleScheduleServiceDueNotice`, `USP_LicenseExpiryNotice`, `USP_SafetyStickyExpiry`, `USP_VehicleRegistryExpiry`, `USP_ThirdPartyIncuranceExpiry`, `USP_Update_Vehicle_BOS` — confirm zero callers via `object_details` focus="inward"; they look like scheduled jobs that may be invoked externally (SQL Agent) and must NOT be dropped if so.

### 3B. Remove unused tables — 3 tables (rule 1202370)
`MstContactDetail24012019` (dated import snapshot), `UserRole` (ids 166540 / 366). Confirm zero references before dropping.

### 3C. T-SQL compatibility findings — FLAGGED ONLY (no change for SQL Server on RDS)
- NVARCHAR usage — 78 occurrences (rule 1106124).
- GETDATE() usage — 6 occurrences (rule 1106138): `USP_VehicleScheduleServiceDueNotice`, `USP_LicenseExpiryNotice`, `USP_SafetyStickyExpiry`, `USP_VehicleRegistryExpiry`, `USP_ThirdPartyIncuranceExpiry`, `FMS.Data/load2019VehicleRegistryInsertCursor.sql`.
- CONVERT scalar function — 7 occurrences (rule 1106132).
These only require rewrites if migrating OFF SQL Server (e.g. to Aurora/PostgreSQL) — out of scope for this PoC. Document them for a future migration.

## Files in Scope
- `FMS.Data/*.sql` scripts, EF Core migrations, data-access/repository code
- New migration script(s) for proc & table removal

## CAST Imaging MCP Usage During Execution
Application name: **FMS**.
- Before dropping any proc/table: `object_details` focus="inward" to confirm zero callers (critical for the 6 `USP_*` app procs).
- `application_database_explorer` to confirm table/column references before removal.
- After: `advisors` focus="violations" for rules 1202372 and 1202370 to confirm removals registered.

## Validation / Exit Criteria
1. Database builds/migrates cleanly after removals.
2. Every removed proc/table confirmed zero-caller via MCP before the drop.
3. App (post-Phase-2) still builds and runs against the cleaned schema.
4. T-SQL compatibility findings documented for future off-SQL-Server migration.
