# Project Feedback — CCGC 5502 Automation Project

George Mohareb — N01275877

Requested feedback on project flow, errors encountered, and the fixes applied.

---

## Project flow

The flow works well. Reusing the Terraform project as the foundation meant the
infrastructure was already proven before any Ansible was written, so every
failure during this project could be attributed to configuration rather than
provisioning. Building the four roles independently and only then wiring them
into the provisioner also helped — each role could be run and corrected on its
own before the integration was attempted.

The single most useful decision was making the provisioner generate the Ansible
inventory from Terraform outputs rather than maintaining a static inventory
file. The IP addresses do not exist until Azure assigns them, so a hand-written
inventory would have to be edited after every deployment, which conflicts
directly with the non-interactive requirement.

The one part of the specification that proved fragile is the requirement for
exactly 48 lines in `terraform state list`. That number constrains how the
provisioner may be structured. Three separate `null_resource` blocks would have
been the more natural Ansible pattern, but produced 50 lines, so the design
uses one `null_resource` carrying several provisioner blocks instead.

---

## Errors encountered, and the fixes applied

### 1. Azure region policy blocked the recommended region

```
RequestDisallowedByAzure: This policy maintains a set of best available regions
where your subscription can deploy resources.
```

The project recommends Canada Central. A subscription policy named
`Allowed resource deployment regions` restricted deployment to `eastus2`,
`westus3`, `southcentralus`, `centralus`, `northcentralus`.

**Fix:** deployed to East US 2, which has availability zones and was unused.

### 2. Student subscription could not host the deployment

Two hard caps made it impossible:

```
PublicIPCountLimitReached: Cannot create more than 3 public IP addresses
```

The deployment needs five — three Linux VMs, one Windows VM, one load balancer.
The regional vCPU limit of 6 was also below what four VMs required once the
only available sizes turned out to be 2 vCPU.

I tried allocating a `/30` public IP prefix and carving addresses from it. Azure
rejected that too — prefixes count against the same cap.

**Fix:** moved to a pay-as-you-go subscription, which the project text lists as
the preferred option. Its limits are 10 vCPU and 20 public IPs.

### 3. Resource providers were unregistered on the new subscription

The first check against the pay-as-you-go subscription reported zero quota for
everything, which looked like a hard block. It was not — the subscription had
never been used, so its resource providers were `NotRegistered` and the quota
APIs returned nothing at all.

**Fix:** registered `Microsoft.Compute`, `Microsoft.Storage`,
`Microsoft.DBforPostgreSQL`, `Microsoft.RecoveryServices`,
`Microsoft.OperationalInsights` and `Microsoft.Network`. Quota then reported
correctly. Worth knowing: an empty quota response is not the same as a quota of
zero.

### 4. Basic SKU load balancer cannot be created

```
IPv4BasicSkuPublicIpCountLimitReached: Cannot create more than 0 IPv4 Basic SKU
public IP addresses for this subscription in this region.
```

A public-facing basic load balancer requires a basic public IP. Tested on both
subscriptions with the same result — Basic SKU is retired globally, not limited
by the student account.

**Fix:** Standard SKU for the load balancer and all VM public IPs. One
consequence worth noting: Standard SKU denies inbound traffic by default, so
the NSG rules became functionally required rather than merely present.

### 5. PostgreSQL Single Server is retired

```
InvalidElasticServerType: The provided server type value
'Azure Database for PostgreSQL - Single Server' is invalid.
```

**Fix:** switched to `azurerm_postgresql_flexible_server`. The retired
configuration is kept in the repository as
`modules/database-5877/main-single-server.tf.disabled` for reference.

### 6. No VM size could boot the specified operating systems

This was the most involved problem. `Standard_B1ms` is
`NotAvailableForSubscription`, so `Standard_F1as_v7` was selected — also 1 vCPU,
and from the same family as `Standard_F1ads_v7` which the project text gives as
an acceptable example. The VMs then failed to boot:

```
InvalidParameter: The VM size 'Standard_F1as_v7' cannot boot with OS image or
disk. Please check that disk controller types supported by the OS image or disk
is one of the supported disk controller types for the VM size.
```

Investigating with `az vm list-skus` joined against `az vm list-usage` showed
every VM size available to the subscription is **NVMe-only**, while every
SCSI-capable family is `NotAvailableForSubscription`. CentOS 8.2 (2020) and
Windows Server 2016 predate NVMe support and cannot boot on NVMe.

**Fix:** Rocky Linux 9 for the Linux nodes — the direct community successor to
CentOS — and Windows Server 2022, the earliest Windows Server with NVMe
support. Verified in three regions before concluding this was a subscription
gate rather than a regional shortage.

### 7. Marketplace image required a plan block

```
VMMarketplaceInvalidInput: Creating a virtual machine from Marketplace image
requires Plan information in the request.
```

**Fix:** accepted the image terms once with
`az vm image terms accept --publisher resf --offer rockylinux-x86_64 --plan 9-lvm`
and added a matching `plan` block to the Linux VM resource.

### 8. Azure rejects resource names beginning with a digit

```
Recovery Service Vault name must be 2 - 50 characters long, start with a letter
domain_name_label ... must start with a letter
```

The instruction to prepend the last four digits of the Humber ID produces
`5877-...`, which starts with a digit.

**Fix:** a local `alpha_prefix = "n${var.prefix}"` gives `n5877` for the
Recovery Services vault, the PostgreSQL server, the backup policy, and all
public IP DNS labels. Every other resource keeps the plain `5877-` prefix.

### 9. ssh-keygen hung forever with no error message

The hardest failure to diagnose, because nothing reported an error — the
playbook simply stopped making progress. Inspecting the process table on the
node showed the cause:

```
/bin/ssh-keygen -t rsa -b 4096 -C ... -f /home/user100/.ssh/id_rsa
```

There is no `-N` flag. `ssh-keygen` was waiting at an interactive
"Enter passphrase:" prompt that no one could see or answer. The cause was
setting `ssh_key_passphrase: ""` in the user role — Ansible treats a supplied
passphrase as interactive mode and drops `-N`.

**Fix:** removed the option entirely, which makes the module pass `-N ""`. Key
generation went from indefinite to under a second. Key size was also reduced
from 4096 to 2048 bits, which is the `ssh-keygen` default and much faster on a
1 vCPU machine.

A side effect worth recording: each interrupted run left an orphaned
`ssh-keygen` process running on the node. Several accumulated and competed for
the single vCPU, making everything else appear slow. They had to be killed
before the fixed playbook would run at a normal speed.

### 10. Privilege escalation timed out on some nodes

```
Timeout (62s) waiting for privilege escalation prompt
```

Two of the three nodes failed this way while the third succeeded, yet running
`sudo` manually over SSH returned instantly on all three. Testing connection
options in isolation identified SSH `ControlMaster` multiplexing as the cause.

**Fix:** disabled connection sharing in `ansible.cfg` with
`-o ControlMaster=no`. Every run has been reliable since.

### 11. The data disk role was not idempotent

The role originally identified the data disk by looking for a device of the
right size **with no partitions**. That worked on the first run and failed on
every run afterwards, because the disk it had just partitioned no longer
matched. This mattered a great deal: the Terraform provisioner re-runs the
playbook on every `terraform apply`, so a role that only works once breaks the
whole integration.

**Fix:** match the disk on size alone. `parted`, `filesystem` and `mount` are
all idempotent, so re-running is now safe.

### 12. The data disk is not /dev/sdc

On the NVMe VM sizes the attached data disk appears as `/dev/nvme0n2`, and its
partitions take a `p` before the number — `nvme0n2p1`, not `sdc1`.

**Fix:** the role derives the partition prefix from the device name rather than
hardcoding either convention, so it works on NVMe and SCSI machines alike.

### 13. The fetched private key was rejected by ssh

```
Load key "user100_id_rsa": bad permissions
```

The role fetches the key to the playbook directory, which sits on a Windows
drive mounted into WSL. Windows filesystems ignore `chmod`, so the file reports
as world-readable and `ssh` refuses to use it.

**Fix:** copy the key into the Linux filesystem before using it, where `chmod
600` takes effect. Not a defect in the role — the key is fetched exactly as the
project requires — but it must be moved off the Windows mount before the login
test will work.

---

## Suggestions

1. The requirement for exactly 48 resources in state is worth revisiting. It
   constrains legitimate design choices — three `null_resource` blocks is the
   more idiomatic Ansible pattern but produces the wrong count.

2. The specified operating systems, VM size, load balancer SKU and database
   type are all now retired or unavailable on current Azure subscriptions.
   Students on a fresh account cannot follow the specification literally.
   Suggested modern equivalents: Rocky Linux 9 or AlmaLinux 9, Windows Server
   2022, Standard SKU load balancer, PostgreSQL Flexible Server.

3. Worth warning students that `Standard_B1ms` — named in both project
   documents — is frequently `NotAvailableForSubscription` on new accounts, and
   that the newer v6/v7 families are NVMe-only and will not boot older images.
   That combination cost the most time by a wide margin.
