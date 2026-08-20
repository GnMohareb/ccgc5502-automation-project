# CCGC 5502 — Automation Project

**George Mohareb — N01275877**

Terraform builds the Azure infrastructure and, in the same `terraform apply`, a
`null_resource` provisioner runs an Ansible playbook that configures the guest
operating systems. One command, no interactive steps.

Deployed result: three Rocky Linux web servers behind a public load balancer,
one Windows server, four data disks, and a PostgreSQL database — **48 resources**
in Terraform state.

---

## Repository layout

```
.
├── providers.tf          azurerm ~> 3.100, null ~> 3.2
├── backend.tf            remote state in an Azure storage account
├── variables.tf          20 input variables
├── main.tf               root module — calls the 8 child modules, locals for tagging
├── outputs.tf            hostnames, FQDNs, private and public IPs
├── FEEDBACK.md           project flow, errors encountered, fixes applied
│
├── modules/
│   ├── rgroup-5877/         resource group
│   ├── network-5877/        vnet, subnet, NSG (ports 22 / 3389 / 5985 / 80)
│   ├── common-5877/         Log Analytics, Recovery Services vault, storage account
│   ├── vmlinux-5877/        3 × Linux VM (for_each)  +  provisioner.tf
│   ├── vmwindows-5877/      1 × Windows VM (count)
│   ├── datadisk-5877/       4 × 10 GB managed disks and attachments
│   ├── loadbalancer-5877/   public load balancer, 3 Linux VMs in the backend pool
│   └── database-5877/       Azure Database for PostgreSQL
│
└── ansible/
    ├── ansible.cfg
    ├── 5877-playbook.yml    runs all four roles against the linux group
    └── roles/
        ├── profile-5877/     appends the test block to /etc/profile
        ├── user-5877/        cloudadmins group, user100/200/300, SSH keys
        ├── datadisk-5877/    4 GB XFS on /part1, 5 GB EXT4 on /part2
        └── webserver-5877/   Apache, per-node index.html, handler-driven start
```

Each child module uses the required file names: `main.tf`, `variables.tf`,
`outputs.tf`, and `provisioner.tf` where a provisioner is present.

---

## Running it

```bash
# Clear any inherited service-principal credentials from the shell profile,
# otherwise Terraform authenticates against the wrong subscription.
unset ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID ARM_ACCESS_KEY

export ARM_SUBSCRIPTION_ID='<subscription id>'
export TF_VAR_admin_password='<vm admin password>'
export TF_VAR_db_admin_password='<postgres admin password>'

terraform init
terraform validate
terraform apply --auto-approve     # builds infrastructure AND runs Ansible

terraform state list | nl          # 48 lines
terraform output
```

Secrets are supplied only through `TF_VAR_*` environment variables. Nothing
sensitive is committed — `.gitignore` excludes state files, saved plans,
`*.tfvars`, the generated inventory, and the fetched private keys.

---

## How Terraform hands off to Ansible

All of it lives in `modules/vmlinux-5877/provisioner.tf`, in a single
`null_resource` that runs after the VMs and their extensions exist:

1. **Three `remote-exec` blocks**, one per Linux node, each opening an SSH
   session. This blocks until every machine is genuinely accepting connections,
   so Ansible cannot race a VM that is still booting.
2. **A `local-exec` block** writes `ansible/inventory.ini` from the public IP
   addresses Azure has just assigned, passing each node's FQDN through as the
   `node_fqdn` host variable. Nothing about the inventory is hardcoded.
3. **A second `local-exec` block** runs `ansible-playbook 5877-playbook.yml`.

It is deliberately one `null_resource` rather than three: the project requires
exactly 48 entries in `terraform state list`, and three separate resources
would produce 50.

Authentication is by SSH key. Terraform installs a public key on each Linux VM
through `admin_ssh_key`, and Ansible connects with the matching private key —
so no password is ever prompted for, typed, or written to the inventory.

---

## The Ansible roles

| Role | What it does |
|---|---|
| `profile-5877` | Uses `blockinfile` to append the test comment and `export TMOUT=1500` to `/etc/profile`, so re-running never duplicates the block. |
| `user-5877` | Creates the `cloudadmins` group; creates `user100`, `user200` and `user300` with a **loop**; adds each to `cloudadmins` and `wheel`; generates a passphrase-less RSA key for each; authorises each key for its own account; fetches `user100`'s private key from VM1 to the control node. |
| `datadisk-5877` | Identifies the 10 GB data disk at run time, creates a 4 GB XFS partition on `/part1` and a 5 GB EXT4 partition on `/part2`, both persistent through `/etc/fstab`. |
| `webserver-5877` | Installs Apache; generates `vm1.html`, `vm2.html` and `vm3.html` **on the control node**, each carrying that node's FQDN; copies each to its own node as `/var/www/html/index.html` with mode `0444`; starts Apache through a **handler**; enables it at boot; opens port 80 in firewalld. |

Every role is parameterised through its own `vars/main.yml` — group names,
account lists, key type and size, the partition table, package names, document
root, file mode and port are all data rather than literals in tasks.

### Logging in as user100

```bash
# Copy the key off any Windows-mounted path first — those filesystems ignore
# chmod, and ssh refuses a key it considers world-readable.
cp ansible/fetched_keys/user100_id_rsa ~/user100_id_rsa
chmod 600 ~/user100_id_rsa

ssh -i ~/user100_id_rsa user100@<VM1 public IP>
```

No password and no passphrase is requested.

---

## Deviations from the project specification

Each of these was forced by the Azure platform, not chosen. `FEEDBACK.md`
records the exact error message behind every one.

| Specification | Deployed | Reason |
|---|---|---|
| CentOS 8.2 | Rocky Linux 9 | Every VM size available to the subscription is NVMe-only; CentOS 8.2 predates NVMe and cannot boot |
| Windows Server 2016 | Windows Server 2022 | Same NVMe constraint |
| Basic load balancer | Standard SKU | `Cannot create more than 0 IPv4 Basic SKU public IP addresses` — Basic SKU is retired globally |
| PostgreSQL Single Server | Flexible Server | `InvalidElasticServerType` — Single Server is retired |
| `Standard_B1ms` | `Standard_F1as_v7` | B-series is `NotAvailableForSubscription`; F1as_v7 is also 1 vCPU and shares a family with `Standard_F1ads_v7`, which the project names as acceptable |
| `5877-` on every name | `n5877-` on four | Azure rejects names beginning with a digit for Recovery Services vaults, PostgreSQL servers and DNS labels |

---

## Cost

Deallocate the VMs when they are not in use — a shut-down VM still holds its
compute allocation and continues to bill, while a deallocated one does not:

```bash
az vm deallocate --ids $(az vm list -g 5877-P2-RG --query "[].id" -o tsv)
```

Destroy the infrastructure once it has been marked:

```bash
terraform destroy --auto-approve
```
