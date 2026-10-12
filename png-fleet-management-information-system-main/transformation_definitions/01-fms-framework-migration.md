# fms-framework-migration-execution

## Description
PHASE 1 of 4 — Migrate FMS from ASP.NET MVC 5 (.NET Framework) to ASP.NET Core MVC on .NET 8 (LTS), eliminating all `System.Web` dependencies. This phase runs FIRST — every later phase (auth, DB cleanup, cloud) operates on the new ASP.NET Core code produced here.

> All counts, object ids, and file paths come from the CAST Imaging assessment of application **FMS** (delivery `Onboarding-202609031657`). Application name for all CAST MCP calls: **FMS**.

## Entry Criteria
1. CAST Imaging MCP server configured and responding (application: **FMS**).
2. Repo accessible at: `d:/PoC_ProjectCode/FMS_Code/png-fleet-management-information-system-main/png-fleet-management-information-system-main`.
3. .NET 8 SDK installed (`dotnet --version` → 8.x).
4. .NET Upgrade Assistant available (`dotnet tool install -g upgrade-assistant`).
5. Clean git working tree.

## Source → Target
- Framework: ASP.NET MVC 5 / EF6 / OWIN / System.Web → ASP.NET Core MVC 8 / EF Core 8 / generic Host + built-in DI
- Target framework moniker: `net8.0` for all projects (FMS.Web, FMS.Data, FMS.Model, FMS.Common, FMS.Service, FMS.Report)

## Implementation Steps

### 1A. System.Web.HttpContext / HttpContext.Current — 18 objects (rule 1202393)
Replace `System.Web.HttpContext` / `HttpContext.Current` with `Microsoft.AspNetCore.Http.HttpContext` via injected `IHttpContextAccessor`. Convert the four custom MVC action filters to ASP.NET Core `IAuthorizationFilter`/`IAsyncActionFilter`.
Objects: `BaseController.OnActionExecuting` (183583) + class (186632); `UserInterfaceAuthorizationAttribute` (174089) +`.AuthorizeCore` (174248) +`.HandleUnauthorizedRequest` (175745) + lambda (179600); `UserActionAuthorizationAttribute` (176987) +`.AuthorizeCore` (184613) +`.HandleUnauthorizedRequest` (178597) + lambda (178636); `AuditAttribute` (186103) +`.OnActionExecuted` (176600); `NoDirectAccessAttribute` (186643) +`.OnActionExecuting` (181446); `ReportsController` (183119) + ctor (176487); `SecurityController` (186779) +`.AuthenticationManager` (185761).
Reference: Appendix A.3 of the master TD.

### 1B. System.Web file-upload APIs — 16 objects (rule 1202392)
Replace `HttpPostedFileBase`/`HttpPostedFile` with `IFormFile`; route persisted writes through an `IFileStorage` abstraction (so Phase 4-cloud can swap in S3). Replace the in-`Session` `List<HttpPostedFileBase>` buffer.
Objects (controllers): `VehicleManagementController.File_Add` (177597) `.UpdateFiles` (178487) + lambdas (178866/183370/177447); `VehicleDisposalController.File_Add` (175424) `.UpdateFiles` (186397) + lambdas (177162/176924/185626); `VehicleIncidentManagementController.File_Add` (185708) `.UpdateFiles` (180933) + lambdas (183272/182166/185691); `OrganisationManagementController.UpdateCompany` (173674).
Reference: Appendix A.4 of the master TD.

### 1C. Razor views — 136 views
- Pure Razor — 65 views (rule 1202420): port as-is.
- Razor + JS + AJAX — 70 views (rule 1202418): port + re-point jQuery AJAX to new ASP.NET Core routes.
- Hybrid Razor + JS (no AJAX) — 1 view (rule 1202419): `FMS.Web/Views/Security/CenterSecurity.cshtml`.
Update `_ViewStart`/`_Layout`, replace `System.Web.Optimization` bundling, anti-forgery tokens.

### 1D. Project/build conversion
- Convert each `.csproj` to SDK-style, `net8.0`.
- Replace `packages.config` + `web.config` with `appsettings.json` + PackageReferences.
- EF6 → EF Core 8 in `FMS.Data` (`FMSEntities.cs`, `Configuration/`, `Migrations/`, `Repositories/`, `Infrastructure/`); verify 49 entities map to 70 tables.
- Replace OWIN/Autofac bootstrap with ASP.NET Core `Program.cs` + built-in DI.
- Fix the SQL-in-loop / EF `ToList()`-in-`foreach` efficiency flaws here while rewriting the data layer (structural-flaws: 1019406 ×1, 1025056 ×1, 1101116 ×6).

## Dependencies
Remove: `Microsoft.AspNet.Mvc`, `Microsoft.AspNet.WebApi.*`, `Microsoft.Owin.*`, `Autofac` (OWIN), `EntityFramework` (EF6), `System.Web.*`, `Microsoft.AspNet.Web.Optimization`.
Add: `Microsoft.AspNetCore.*` (MVC), `Microsoft.EntityFrameworkCore.SqlServer` 8.x, `Microsoft.EntityFrameworkCore.Design` 8.x. Upgrade `AutoMapper` to a .NET 8-compatible version.

## CAST Imaging MCP Usage During Execution
Application name for all calls: **FMS**.
- Before editing: `object_details` focus="code"/"inward"/"outward" on the target id; `architectural_graph` to confirm layer.
- During: `transactions_using_object` on every modified object; `data_graphs_involving_object` for data-access changes.
- After: `object_details` focus="inward" to confirm no caller missed; `advisors` focus="violations" for rules 1202393 / 1202392 / 1202418 / 1202419 / 1202420 to confirm counts dropped.

## Validation / Exit Criteria
1. `dotnet build FMS.sln -c Release` passes (all projects `net8.0`).
2. `dotnet test` passes.
3. App starts under Kestrel.
4. MCP deltas: rule 1202393 18→0, rule 1202392 16→0.
5. All 16 transaction profiles / 241 controller actions still resolve (verify via `transactions`).
6. No business-logic or data-model regressions.
