# Phase 1 — Remote Execution (AWS Transform Custom)

Use this path when local WSL2 is unavailable (e.g. hypervisor blocked by corporate policy).
Remote execution runs the transformation in AWS, so **no local WSL/hypervisor is required**.

- **TD:** `fms-framework-migration-execution` (`01-fms-framework-migration.md`)
- **Repo (remote):** `https://github.com/rajaksunil/PNG-Fleet-Management-Information-System.git` (branch `main`)

---

## Prerequisites (per phase2-execution.md, Remote Execution)

1. **Repository accessible from AWS** — GitHub URL above. The branch to transform must be
   pushed and current. The `transformation_definitions/` folder is currently UNTRACKED locally;
   commit + push it (or publish the TD, step 2) so the run can see the TD.
2. **IAM role with `AWSTransformCustomExecuteTransformations` policy** (remote execution).
   (Local mode uses `AWSTransformCustomFullAccess`; remote uses the Execute policy.)
3. **ATX CLI** on whatever machine issues the command (the CLI only *submits* the remote job;
   the transformation itself runs in AWS, not locally). If this host also has no WSL, submit
   from the **AWS Transform web application** instead — see "Web app" below.

---

## CAST Imaging MCP — important constraint for remote runs

The CAST MCP endpoint in use is `http://localhost:8282/mcp`, backed by the internal host
`INDCS0603.atrapa.deloitte.com`. An AWS execution environment **cannot reach a laptop loopback
or an internal corporate host** without a network path (VPN/VPC/tunnel). Two options:

- **A. Remote WITHOUT `--mcp-config` (recommended here).** The TD contains all the static
  context (object IDs, file paths, fix strategies) needed to execute. Live verification is
  skipped DURING the run; re-verify AFTER from the IDE (see "Post-run verification").
- **B. Remote WITH `--mcp-config`.** Only if your network team exposes CAST to the AWS
  environment. Then point the url in `mcp.json` at that reachable endpoint.

---

## Option 1 — Submit via ATX CLI (remote, without MCP)

```bash
# Publish the TD to AWS Transform so the remote job can resolve it by name
atx custom def publish -n "fms-framework-migration-execution"

# Execute against the Git URL (remote). Note -p takes the repo URL, not a local path.
atx custom def exec \
  -n "fms-framework-migration-execution" \
  -p "https://github.com/rajaksunil/PNG-Fleet-Management-Information-System.git" \
  -x -t
```

(Add `--mcp-config ./mcp.json` ONLY if CAST is reachable from AWS — Option B above.)

## Option 2 — AWS Transform web application (no local CLI/WSL at all)

Per phase2-execution.md, for centralised monitoring / when you can't run the CLI locally:
1. Open the AWS Transform web application in the AWS console.
2. Connect the GitHub repo (source provider: GitHub).
3. Select / import the `fms-framework-migration-execution` transformation definition.
4. Start the transformation; monitor progress in the web UI.
5. The result is delivered as a PR/branch on the repo for review.

---

## Post-run verification (from this IDE, using the local CAST MCP)

The remote run (without MCP) can't self-verify, so confirm the deltas here afterward — same
checks we used to validate the baseline:

- `advisors` focus="violations", advisor 1202388, rule **1202393** → expect **18 → 0**
- `advisors` focus="violations", advisor 1202388, rule **1202392** → expect **16 → 0**
- `transactions` → all 16 transaction profiles / 241 controller actions still resolve
- Pull the resulting branch/PR locally and run: `dotnet build FMS.sln -c Release`, `dotnet test`

---

## Safety notes

- Remote execution rewrites code on a branch/PR in the remote repo — review the PR before merge.
- Keep `main` protected; let AWS Transform deliver changes on a separate branch.
- Do not commit real CAST API keys. `mcp.json` uses `${input:imaging-key}`; the real URL is
  `http://localhost:8282/mcp` (local only — not usable from AWS).
