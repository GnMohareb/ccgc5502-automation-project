# CCGC 5502 — Automation Project (Terraform + Ansible)

George Mohareb — N01275877

Terraform builds the infrastructure and, in the same `terraform apply`, a
`null_resource` provisioner runs an Ansible playbook that configures the guest
operating systems. One command, no interactive steps.

## Layout

```
assignment2-5877/
├── providers.tf, backend.tf, variables.tf, main.tf, outputs.tf
├── modules/
│   ├── rgroup-5877/        resource group
│   ├── network-5877/       vnet, subnet, NSG (22/3389/5985/80)
│   ├── common-5877/        log analytics, recovery vault, storage account
│   ├── vmlinux-5877/       3 × Linux (for_each) + provisioner.tf  <-- Ansible runs here
│   ├── vmwindows-5877/     1 × Windows (count)
│   ├── datadisk-5877/      4 × 10 GB disks + attachments
│   ├── loadbalancer-5877/  public load balancer, 3 Linux VMs behind it
│   └── database-5877/      Azure DB for PostgreSQL
└── ansible/
    ├── ansible.cfg
    ├── 5877-playbook.yml   calls all four roles against the linux group
    └── roles/
        ├── profile-5877/    appends the test block to /etc/profile
        ├── user-5877/       cloudadmins group, user100/200/300, SSH keys
        ├── datadisk-5877/   4 GB XFS on /part1, 5 GB EXT4 on /part2
        └── webserver-5877/  Apache, per-node index.html, handlers
```

## How to run

```bash
export ARM_SUBSCRIPTION_ID=8f53d0de-7f31-434c-a18a-0066b8526f19
export TF_VAR_admin_password='<vm admin password>'
export TF_VAR_db_admin_password='<postgres admin password>'

terraform init
terraform validate
terraform apply --auto-approve      # builds infrastructure AND runs Ansible
terraform state list | nl           # 48 lines
terraform output
```

Secrets are supplied through `TF_VAR_*` environment variables and never written
to a file, so nothing sensitive is committed.

## How the Terraform / Ansible integration works

`modules/vmlinux-5877/provisioner.tf` holds a single `null_resource` that, after
the VMs and their extensions are up:

1. Opens an SSH session to each of the three Linux nodes, so Ansible cannot race
   the boot.
2. Writes `ansible/inventory.ini` from the live public IPs, passing each node
   Azure FQDN through as the `node_fqdn` host variable.
3. Runs `ansible-playbook 5877-playbook.yml`.

It remains one `null_resource`, which keeps `terraform state list` at the 48
lines the project requires.

Authentication is by SSH key, not password. Terraform installs
`~/.ssh/id_rsa_5877.pub` on every Linux VM via `admin_ssh_key`, and Ansible
connects with the matching private key. That is what makes the run genuinely
non-interactive.

## The Ansible roles

| Role | What it does |
|---|---|
| `profile-5877` | `blockinfile` appends the test comment and `export TMOUT=1500` to `/etc/profile`. `tail -4 /etc/profile` shows the begin marker, both lines, and the end marker. |
| `user-5877` | Creates the `cloudadmins` group; creates `user100`, `user200`, `user300` with a loop; adds each to `cloudadmins` and `wheel`; generates a 4096-bit RSA key with an empty passphrase for each; authorises each key for its own account; fetches `user100` private key from VM1 to `ansible/fetched_keys/`. |
| `datadisk-5877` | Detects the unpartitioned 10 GB data disk, creates a 4 GB XFS partition mounted on `/part1` and a 5 GB EXT4 partition mounted on `/part2`, both persistent through `/etc/fstab`. |
| `webserver-5877` | Installs Apache; generates `vm1.html`, `vm2.html`, `vm3.html` **on the control node**, each carrying that node FQDN; copies each to its own node as `/var/www/html/index.html` with mode `0444`; starts Apache through a **handler**; enables it at boot; opens port 80 in firewalld. |

### Logging in as user100

After the apply, the private key is waiting on the control node:

```bash
ssh -i ansible/fetched_keys/user100_id_rsa user100@<VM1 public IP>
```

No password and no passphrase is requested.

## Deviations from the project specification

These are inherited from the Terraform project and are forced by the Azure
subscription. `CHANGELOG.md` records the literal Azure error text behind each.

| # | Project says | Deployed | Reason |
|---|---|---|---|
| 1 | Canada Central | East US 2 | no usable VM size in Canada Central on this subscription |
| 2 | basic load balancer | Standard SKU LB and public IPs | Basic SKU public IPs are retired globally |
| 3 | CentOS 8.2 | Rocky Linux 9 | every available VM size is NVMe-only; CentOS 8.2 predates NVMe |
| 4 | Windows Server 2016 | Windows Server 2022 | same NVMe constraint |
| 5 | PostgreSQL Single Server | PostgreSQL Flexible Server | Single Server is retired |
| 6 | `5877-` prefix on all names | `n5877-` on some | Azure rejects names starting with a digit |

The VM size is `Standard_F1as_v7` — 1 vCPU, and from the same family as
`Standard_F1ads_v7` that the project text gives as an acceptable example.

Because the nodes run Rocky Linux 9 rather than CentOS 8.2, the roles use
`httpd`, `firewalld` and NVMe-aware device detection. The data disk appears as
`/dev/nvme0n2` rather than `/dev/sdc`, so `datadisk-5877` discovers the device at
run time instead of hardcoding it.

## Isolation from the Terraform project

This project shares an Azure subscription with `assignment1-5877` but cannot
disturb it:

| | Terraform project | This project |
|---|---|---|
| State key | `assignment1-5877.terraform.tfstate` | `assignment2-5877.terraform.tfstate` |
| Resource group | `5877-RG` | `5877-P2-RG` |
| `name_suffix` | `x1` | `p2` |
