# Azure Secure Landing Zone

A reproducible, secure Azure landing zone defined as Infrastructure as Code with Terraform. It stands up a hub-and-spoke network where every spoke's outbound traffic is force-tunnelled through a central Azure Firewall, with a VPN gateway in the hub for hybrid connectivity.

The whole configuration is validated in CI with no cloud credentials, so the pipeline stays green without touching a subscription. Applying it needs a real Azure subscription.

> Status: networking layer complete and validating. Identity (Microsoft Entra ID) and endpoint (Microsoft Intune) modules are in progress, see [Roadmap](#roadmap).

## Architecture

```
                          +------------------------------+
                          |          Hub VNet            |
                          |          10.0.0.0/16         |
                          |                              |
   on-prem / VPN <------> |  GatewaySubnet   -> VPN GW   |
                          |  AzureFirewallSubnet -> Azure Firewall
                          |                        (+ policy)
                          +---------------+--------------+
                                          |
                        VNet peering (both directions)
                          +---------------+--------------+
                          |                              |
            +-------------v------------+   +-------------v------------+
            |     app spoke VNet       |   |     data spoke VNet      |
            |     10.1.0.0/16          |   |     10.2.0.0/16          |
            |  workload subnet + NSG   |   |  workload subnet + NSG   |
            |  UDR: 0.0.0.0/0 -> FW    |   |  UDR: 0.0.0.0/0 -> FW    |
            +--------------------------+   +--------------------------+
```

Key design decisions:

- **Forced tunnelling.** Each spoke workload subnet has a route table with a single default route (`0.0.0.0/0`) whose next hop is the firewall's private IP (`VirtualAppliance`). No spoke can reach the internet directly; everything is inspected by the firewall first.
- **Default-deny egress.** The firewall policy allows only outbound HTTPS from the spoke ranges and denies the rest by default. Widen it deliberately, per workload.
- **No inbound from the internet.** Each spoke NSG denies inbound traffic from the `Internet` service tag at the lowest priority, on top of Azure's default rules.
- **Hub-and-spoke, not mesh.** Spokes peer only with the hub, never with each other, so lateral movement has to pass through the firewall too.

## Layout

```
.
├── versions.tf            # Terraform + provider version constraints
├── providers.tf           # azurerm + azuread providers
├── variables.tf           # root inputs (prefix, location, hub CIDR, spokes map)
├── main.tf                # resource groups + module wiring
├── outputs.tf
├── terraform.tfvars.example
├── modules/
│   ├── networking/        # hub, firewall, gateway, spokes, peering, routing, NSGs
│   ├── identity/          # (in progress) Entra ID groups, RBAC, Conditional Access
│   └── endpoint/          # (in progress) Intune compliance + configuration profiles
└── .github/workflows/terraform.yml
```

Spokes are driven by the `spokes` map variable, so adding another spoke is a few lines of tfvars, not new resource blocks.

## Usage

Validate (no credentials needed, this is what CI runs):

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Plan or apply against a real subscription:

```bash
az login
cp terraform.tfvars.example terraform.tfvars   # set subscription_id
terraform init
terraform plan
terraform apply
```

## Troubleshooting runbook

- **VPN gateway takes 30 to 45 minutes to provision.** `terraform apply` will sit on `azurerm_virtual_network_gateway` for a long time. That is expected, not a hang. Plan your apply around it.
- **Firewall subnet must be named exactly `AzureFirewallSubnet`.** Same for `GatewaySubnet`. Any other name and the firewall or gateway deployment fails with a not-obvious error. Both names are hard-coded in the networking module for that reason.
- **Spoke has no internet after apply.** That is the design. Traffic goes through the firewall, and the firewall policy only allows HTTPS by default. If a workload needs another port or FQDN, add a rule to the firewall policy rather than a route around it.
- **Peering shows connected but routes do not propagate.** Check that the route table is associated with the workload subnet (`azurerm_subnet_route_table_association`) and that `allow_forwarded_traffic` is true on the peering, otherwise the firewall's forwarded packets are dropped.
- **`subscription_id is required` on plan.** `validate` does not need it; `plan`/`apply` do. Set it in `terraform.tfvars` or export `ARM_SUBSCRIPTION_ID`.

## Roadmap

- [x] Networking: hub-and-spoke, Azure Firewall + policy, VPN gateway, peering, forced-tunnel routing, NSGs
- [ ] Identity: Microsoft Entra ID security groups, RBAC role assignments scoped per resource group, Conditional Access baseline (require MFA, block legacy auth)
- [ ] Endpoint: Microsoft Intune device compliance policy and a configuration profile baseline
- [ ] Remote state backend (Azure Storage) and a dev/prod environment split

Built with Terraform and an agentic workflow (Claude Code, custom skills, MCP integrations).
