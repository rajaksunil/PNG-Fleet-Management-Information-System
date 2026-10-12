# fms-cloud-readiness-execution

## Description
PHASE 4 of 4 — Make the modernized FMS (.NET 8, ASP.NET Core) runnable as a Linux container on AWS ECS/Fargate — single instance (PoC). Runs LAST because containerization and config/state externalization operate on the final code state.

> CAST application name for all MCP calls: **FMS**. The CAST cloud-detection-patterns scan was NOT configured for this onboarding, so there is no CAST-counted blocker list; the work below is driven by the known .NET-Framework→Core blockers and standard AWS containerization needs, not fabricated counts. Re-scan FMS with the cloud nature enabled before go-live and fold any findings in here.

## Entry Criteria
1. Phases 1–3 completed and validated.
2. CAST Imaging MCP server configured and responding (application: **FMS**).
3. Docker installed; AWS account/ECR access available (user-driven).

## Source → Target
- On-prem/IIS (Windows, System.Web) → Linux container on AWS ECS/Fargate, single task/replica, SQL Server on AWS RDS.

## Implementation Steps

### 4A. Containerization artifacts (create)
- `Dockerfile` — multi-stage: `mcr.microsoft.com/dotnet/sdk:8.0` build → `mcr.microsoft.com/dotnet/aspnet:8.0` runtime (Linux).
- `.dockerignore`.
- Health endpoint `/health` via `AddHealthChecks()` wired in `Program.cs`.

### 4B. Config / state externalization (PoC-level)
- Move SQL connection string + secrets to environment variables / AWS SSM Parameter Store — no hardcoded connection strings in `appsettings.json`/`web.config`.
- File uploads: wire the `IFileStorage` seam from Phase 1 (1B) to an S3-backed implementation (`AWSSDK.S3`), OR document local-disk as acceptable for single-instance PoC. Align with the existing `upload_reports_to_s3.py` bucket intent.
- The upload buffer that Phase 1 moved out of `HttpPostedFileBase`: for multi-instance this must leave in-process `Session`; for this single-instance PoC `HttpContext.Session` is acceptable — add a `// TODO: distributed cache for multi-instance` marker.
- SignalR `FMS.Web/Hubs/ComsHub.cs`: single-instance only — add `// TODO: Redis backplane for multi-instance` marker. No backplane this phase (per PoC decision).

### 4C. Infrastructure artifacts
- ECS/Fargate task definition (1 task, 1 replica).
- RDS for SQL Server connection parameters surfaced via environment variables.

## Files in Scope
- New: `Dockerfile`, `.dockerignore`, health-check wiring in `Program.cs`, ECS task definition.
- `FMS.Web/Hubs/ComsHub.cs` (annotate).
- Data-access code performing local file I/O (behind `IFileStorage`).

## Dependencies
Add (only if S3 storage implemented): `AWSSDK.S3`, `AWSSDK.Extensions.NETCore.Setup` (optional, SSM/config).

## CAST Imaging MCP Usage During Execution
Application name: **FMS**.
- `architectural_graph` (component level) to confirm structural integrity post-migration before containerizing.
- `transactions` to confirm all endpoints survived the full 4-phase transformation (baseline: 16 transaction profiles).
- `quality_insights` (all natures) + `packages` for a final quality/dependency snapshot vs the assessment baseline.
- `object_details` focus="code" on `ComsHub` and any file-I/O object before annotating/wrapping.

## Validation / Exit Criteria
1. `docker build` produces a Linux image; container starts.
2. `/health` returns healthy.
3. App connects to SQL Server via environment-variable connection string.
4. Full smoke test: login, vehicle CRUD, file upload, reports, SignalR notification all work in-container.
5. No endpoints lost vs baseline (verify via `transactions`).

## Post-PoC follow-ups (not in scope)
- Re-scan FMS in CAST with CVE + cloud-detection-patterns enabled; fold CVE findings into an auth/dependency pass and cloud blockers into a hardening pass.
- Multi-instance: SignalR Redis backplane + distributed session/cache (ElastiCache) + S3 file storage.
