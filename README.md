# kernel-mitigations

A collection of fast kernel-level mitigations deployable as Kubernetes DaemonSets while waiting for official patches.

Currently covers:

| CVE | Name | Module | Status |
|-----|------|--------|--------|
| CVE-2026-31431 | CopyFail | `algif_aead` | ✅ Available |

---

## Why a DaemonSet?

When a kernel LPE drops with a public PoC, you need to act on every node in minutes — not hours. A DaemonSet is the fastest way to push a change to the entire fleet without touching node launch templates, AMIs, or rolling node groups.

Each mitigation runs as a privileged **init container** that does its work once per node, then exits. The remaining pause container keeps the pod alive so you can track rollout status and confirm coverage across all nodes.

---

## CVE-2026-31431 — CopyFail

A logic bug in the Linux kernel's `authencesn` crypto template exposed via the `algif_aead` AF_ALG socket interface. Any unprivileged local user can exploit it to gain root. A working single-script PoC was released alongside the disclosure and runs unmodified across all vulnerable distributions.

**Affected:** Linux kernel ≥ 2017, including Amazon Linux 2023.  
**Vector:** local — attacker needs existing code execution on the host (container escape, compromised pod, CI/CD runner, etc.).  
**Fix:** upstream patches merged; distro packages pending.

The mitigation unloads `algif_aead` if present and blacklists it so it cannot be reloaded until the patched kernel is in place.

---

## Requirements

- Kubernetes 1.24+
- Helm 3
- Nodes running Amazon Linux 2023 (the init container checks for this and exits safely on other OSes)

> **Other platforms:** the underlying `modprobe` approach works on any Linux distribution. The OS check in `scripts/mitigate.sh` currently validates for Amazon Linux — extend or remove it as needed for your environment.

---

## Installation

```bash
helm upgrade --install cve-2026-31431-mitigation \
  oci://ghcr.io/csepulveda/kernel-mitigations/chart \
  --namespace kube-system
```

Or directly from the repo:

```bash
helm upgrade --install cve-2026-31431-mitigation \
  https://github.com/csepulveda/kernel-mitigations/archive/refs/heads/main.tar.gz \
  --namespace kube-system
```

### Verify rollout

```bash
# All nodes should have a Running pod
kubectl get pods -n kube-system -l app=cve-2026-31431-mitigation -o wide

# Check mitigation log on any node
kubectl logs -n kube-system <pod-name> -c mitigate
```

Expected output per node:

```
[mitigation] node=ip-x.x.x.x OS=Amazon Linux — proceeding
[mitigation] algif_aead is not loaded on node=ip-x.x.x.x
[mitigation] blacklist written: /host-modprobe-d/disable-algif-aead.conf on node=ip-x.x.x.x
[mitigation] done on node=ip-x.x.x.x
```

If the module was loaded at the time of execution:

```
[mitigation] ALERT: algif_aead is loaded on node=ip-x.x.x.x — attempting unload
[mitigation] ALERT: algif_aead unloaded successfully on node=ip-x.x.x.x
```

### Uninstall

Once your nodes are running a patched kernel, remove the DaemonSet:

```bash
helm uninstall cve-2026-31431-mitigation -n kube-system
```

---

## How it works

```
init container (privileged)
  ├── 1. Check /etc/os-release → exit if not Amazon Linux
  ├── 2. lsmod | grep algif_aead → unload if present, log ALERT
  └── 3. echo "install algif_aead /bin/false" > /etc/modprobe.d/disable-algif-aead.conf

main container (pause — no privileges)
  └── keeps pod alive for rollout tracking
```

The init container mounts two host paths:
- `/etc/modprobe.d` — to write the blacklist (read-write)
- `/etc/os-release` — to verify the OS (read-only)

---

## Image

Published to GitHub Container Registry, multi-arch (amd64 + arm64):

```
ghcr.io/csepulveda/kernel-mitigations:latest
```

The CI pipeline builds and pushes on every change outside `chart/`. A second pipeline updates `chart/values.yaml` with the exact image SHA after each successful build.

---

## Contributing

PRs welcome — especially for mitigations targeting other distributions or other CVEs. Add a new directory under `mitigations/` and a corresponding Helm chart value set.

---

## References

- [Ars Technica — CopyFail disclosure](https://arstechnica.com/security/2026/04/as-the-most-severe-linux-threat-in-years-surfaces-the-world-scrambles/)
- [Sysdig — CopyFail deep dive](https://www.sysdig.com/blog/cve-2026-31431-copy-fail-linux-kernel-flaw-lets-local-users-gain-root-in-seconds)
- [Tenable — CopyFail FAQ](https://www.tenable.com/blog/copy-fail-cve-2026-31431-frequently-asked-questions-about-linux-kernel-privilege-escalation)
