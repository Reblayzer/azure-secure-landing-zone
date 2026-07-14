# Handoff: continuing the Azure Secure Landing Zone

Continuation notes for picking this up in a fresh session (e.g. on the laptop). The full design lives in `PROJECT_BRAINSTORM.md`; this file is the "where we are and what's next".

## Why this project exists
Tailored portfolio project for the **MFT Energy / IT Infrastructure Engineer - Azure** application (Aarhus, DK). Passed initial screening; the hiring process is paused for summer and resumes **early August 2026**. Goal: have a public, complete, honestly-scoped Azure IaC repo to point to when it resumes. Repo is public: https://github.com/Reblayzer/azure-secure-landing-zone

## State (2026-07-14)
- **Networking module: DONE and validating.** `terraform validate` is green, CI passes (`.github/workflows/terraform.yml` runs `fmt -check` + `validate`, no credentials).
  - Hub VNet + `AzureFirewallSubnet` (Azure Firewall + default-deny egress policy, HTTPS-only allow rule) + `GatewaySubnet` (route-based VPN gateway).
  - Spokes driven by the `spokes` map variable: each gets a workload subnet, an NSG denying inbound from `Internet`, and a route table forcing `0.0.0.0/0` through the firewall private IP.
  - Bidirectional hub<->spoke peering.
- **Identity module: NOT STARTED.**
- **Endpoint module: NOT STARTED.**
- Portfolio card updated with the repo link (`~/dev/portfolio/content/projects/_cards.ts`). Promote it to a flagship `content/projects/azure-secure-landing-zone.mdx` case study once identity + endpoint are done.

## Environment setup (do this first on a new machine)
- **Terraform** is required. On this WSL box it was installed to `~/.local/bin` (v1.15.8) and added to PATH via `.bashrc`. A fresh laptop likely needs it installed too: download the linux_amd64 zip from releases.hashicorp.com into `~/.local/bin`, or use your package manager.
- **Azure CLI (`az`)** is NOT installed. Needed only for `terraform plan`/`apply` against a real subscription, not for `validate`.
- Providers: `azurerm ~> 4.0`, `azuread ~> 3.0` (see `versions.tf`). `terraform init` pulls them.

## Next steps (in order)
1. **identity module** (`modules/identity/`), straightforward with `azuread` + `azurerm`:
   - `azuread_group` for security groups (e.g. net-admins, app-owners).
   - `azurerm_role_assignment` scoped to the hub/spokes resource groups (principal = group object id).
   - `azuread_conditional_access_policy`: require MFA; block legacy authentication (two policies).
   - Wire it into root `main.tf` as `module "identity"`. Run `terraform init && terraform validate`.
2. **endpoint module** (`modules/endpoint/`), Intune, has a real gotcha:
   - Intune is NOT in `azurerm`/`azuread`. Use the community `deploymenttheory/microsoft365` provider (has `microsoft365_graph_beta_device_management_*` resources) OR `azapi` against the Graph beta API.
   - Fetch the provider docs before writing so the resource schemas validate first time.
   - Deliver a device compliance policy + one configuration profile baseline.
   - Intune genuinely needs a real tenant to `plan`/`apply` (a free/trial Azure subscription). `validate` still works offline once the provider is pinned.
3. **After both modules validate:** update the README roadmap checkboxes, consider a remote state backend (Azure Storage) + dev/prod split, then promote the portfolio card to a flagship MDX case study.
4. **When MFT Energy resumes (August):** add the repo link to the re-engagement (the portal Q1 answer already drafted, or interview talking points).

## Commands
```bash
export PATH="$HOME/.local/bin:$PATH"   # if terraform is in ~/.local/bin
terraform init -backend=false
terraform fmt -check -recursive
terraform validate

# against a real subscription:
az login
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init && terraform plan
```

## Integrity guardrails (keep these true)
- Describe behaviour and stack only. No invented metrics, no "deployed in production" claims. CI is validate/plan, not a live deployment.
- The repo link goes on the CV / portal / letter only because the repo now exists and is public. Keep the README's "in progress" honest until identity + endpoint actually land.
