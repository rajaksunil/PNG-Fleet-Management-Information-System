# fms-authentication-execution

## Description
PHASE 2 of 4 — Replace legacy OWIN / Forms / ASP.NET Membership authentication with ASP.NET Core Identity (cookie-based). Runs AFTER Phase 1 (framework migration) because Identity wires into the ASP.NET Core request pipeline and the custom action filters created in Phase 1.

> CAST application name for all MCP calls: **FMS**. Source: assessment delivery `Onboarding-202609031657`.

## Entry Criteria
1. Phase 1 (fms-framework-migration) completed and validated — code is ASP.NET Core / .NET 8.
2. CAST Imaging MCP server configured and responding (application: **FMS**).
3. SQL Server instance reachable (holds the `User`/`Role`/`Claim`/`ExternalLogin`/`UserRole` tables).

## Source → Target
- OWIN `IAuthenticationManager` + `Microsoft.AspNet.Identity` + Forms/Membership → ASP.NET Core Identity (`SignInManager`/`UserManager`) + cookie authentication middleware.

## Implementation Steps

### 2A. Legacy auth objects — 7 objects (rule 1202391)
- `FMS.Web.Startup` (185019) + `.ConfigureAuth` (175911) → fold auth setup into `Program.cs` (`AddAuthentication().AddCookie()` + `AddIdentityCore`/`AddRoles`/`AddSignInManager`). Reference: Appendix A.1.
- `SecurityController` (186779) + ctor (177510): move OWIN `DpapiDataProtectionProvider`/`DataProtectorTokenProvider` + lockout config to `IdentityOptions` in `Program.cs`.
- `SecurityController.SignInAsync` (174171) → `SignInManager.SignInAsync`. Reference: Appendix A.2.
- `SecurityController.LogOff` (174664) → `SignInManager.SignOutAsync`.
- `SecurityController.AuthenticationManager` (185761) → delete (OWIN `IAuthenticationManager` has no ASP.NET Core equivalent).

### 2B. Identity store mapping
Map the application's existing tables `User`, `Role`, `UserRole`, `Claim`, `ExternalLogin` to ASP.NET Core Identity via a custom `ApplicationUser : IdentityUser<Guid>` / `ApplicationRole : IdentityRole<Guid>` and `AddEntityFrameworkStores<FmsDbContext>()`. The legacy `aspnet_*` membership schema is NOT used by Identity and is cleaned up in Phase 3 (DB).

### 2C. Align action filters with Identity
The custom authorization filters touched in Phase 1 (1A) should use ASP.NET Core claims/policies and injected `UserManager`/`IHttpContextAccessor` rather than the old role lookup.

## Files in Scope
- `FMS.Web/Program.cs` (auth setup; folds in former `Startup.Auth.cs`)
- `FMS.Web/Controllers/SecurityController.cs`
- `FMS.Web/CustomActionFilters/*Authorization*.cs` (also modified in Phase 1)
- `FMS.Web/Views/Security/Login.cshtml`, `_LoginPartial.cshtml`, `Register.cshtml`, `ResetPassword*.cshtml`, `ForgotPassword*.cshtml`
- New: `ApplicationUser`/`ApplicationRole` + Identity EF configuration

## Dependencies
Remove: `Microsoft.AspNet.Identity.*`, `Microsoft.Owin.Security.*`.
Add: `Microsoft.AspNetCore.Identity.EntityFrameworkCore` 8.x.

## CAST Imaging MCP Usage During Execution
Application name: **FMS**.
- Before editing `SignInAsync`/`LogOff`: `object_details` focus="inward" (confirm the two Login-flow call sites + the password-reset call site).
- Before editing `BaseController`/filters: `object_details` focus="inward" (shared base — high blast radius).
- After: `advisors` focus="violations" for rule 1202391 — confirm 7 → 0.

## Validation / Exit Criteria
1. `dotnet build` + `dotnet test` pass.
2. Login / logout / password-reset flows work end-to-end against ASP.NET Core Identity.
3. Authorization filters enforce the same access as before (spot-check a restricted interface).
4. MCP delta: rule 1202391 7 → 0.
