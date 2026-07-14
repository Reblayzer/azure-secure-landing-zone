# Tailored project: Azure Secure Landing Zone

**For:** MFT Energy, IT Infrastructure Engineer - Azure (Aarhus)
**Decided with user:** 2026-06-23

## One-line pitch
A reproducible, secure Azure landing zone defined entirely as Infrastructure as Code: hub-and-spoke networking with Azure Firewall and a VNet Gateway, Entra ID identity and access baseline, and an Intune endpoint baseline, all validated in CI without live spend.

## Posting technologies it demonstrates
- Microsoft Azure (the whole thing)
- Azure Firewall (hub egress filtering)
- Virtual Networks (hub + spokes, peering)
- Virtual Network Gateways (VPN gateway in the hub)
- Microsoft Entra ID (groups, RBAC role assignments, Conditional Access)
- Microsoft Intune (device compliance + configuration profiles)
- Endpoint management (the Intune module)
- Cloud networking, identity, security (the design itself)
- Infrastructure as Code (Terraform)
- CI/CD (GitHub Actions: fmt, validate, plan)
- Troubleshooting (documented runbook for common failures)

## Architecture sketch
```
                       Entra ID (azuread provider)
                       - security groups (net-admins, app-owners)
                       - RBAC role assignments scoped per resource group
                       - Conditional Access baseline (MFA, block legacy auth)

  Intune (Graph / azuread)                 Hub VNet (10.0.0.0/16)
  - device compliance policy               +-- AzureFirewallSubnet -> Azure Firewall
  - configuration profile baseline         +-- GatewaySubnet      -> VNet Gateway (VPN)
                                           +-- route table: 0.0.0.0/0 -> firewall
                                                       |
                                              VNet peering (both ways)
                                                       |
                       Spoke VNet (10.1.0.0/16)   Spoke VNet (10.2.0.0/16)
                       +-- workload subnet + NSG  +-- workload subnet + NSG
                       (egress forced through hub firewall via UDR)
```

## v1 scope
**In:**
- `networking/` module: hub VNet, AzureFirewallSubnet + Azure Firewall + policy, GatewaySubnet + VNet Gateway, two spoke VNets, bidirectional peering, route tables forcing 0.0.0.0/0 through the firewall, NSGs per spoke subnet.
- `identity/` module: Entra ID security groups, RBAC role assignments scoped to resource groups, a Conditional Access baseline (require MFA, block legacy authentication).
- `endpoint/` module: an Intune device compliance policy and one configuration profile baseline.
- `environments/` with a dev tfvars; remote state config documented.
- GitHub Actions workflow: `terraform fmt -check`, `terraform validate`, `terraform plan` on PR (plan-only, no apply, so it costs nothing to run).
- README: architecture diagram, the design decisions (why force-tunnel egress through the firewall, why Conditional Access baseline), and a short troubleshooting runbook (peering not propagating routes, gateway provisioning time, firewall rule ordering).

**Out (v1):**
- No `terraform apply` against a paid subscription. CI is validate + plan only; if Alex spins up a free/trial subscription he can apply the cheaper modules, but the project does not claim a live deployment.
- No multi-region / DR.
- No private DNS zones, Bastion, or App Gateway (could be v2).

## Build plan
1. Repo scaffold, providers (`azurerm`, `azuread`), backend config, root module wiring.
2. `networking/` module: hub + spokes + peering + NSGs (validate as you go).
3. Add Azure Firewall + firewall policy + route tables (force-tunnel egress).
4. Add VNet Gateway (note the long provisioning time in the runbook).
5. `identity/` module: Entra groups, RBAC assignments, Conditional Access baseline.
6. `endpoint/` module: Intune compliance + configuration profile.
7. GitHub Actions: fmt + validate + plan workflow.
8. README: architecture, design rationale, troubleshooting runbook. Diagram (mermaid or PNG).
9. Make repo public, add the link to the CV.

## Integrity notes
- On the CV/letter this is described in finished/present tense as what it does and the stack it uses. NO "deployed in production", NO live-subscription or uptime claims (CI is plan/validate only).
- Entra ID, Intune, Azure Firewall, VNet Gateway are project evidence, NOT Schneider production experience. Keep that line clean everywhere.
- Repo link added to the CV only once the repo exists and is public.
