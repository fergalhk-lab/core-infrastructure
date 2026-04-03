# Cluster API Operator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Helm chart manifest for the cluster-api-operator to the management cluster, deploying the operator plus core, kubeadm bootstrap, kubeadm control plane, and Hetzner (CAPH) infrastructure providers via `extraObjects`, with the Hetzner token sourced from AWS Secrets Manager via ExternalSecrets.

**Architecture:** A single chart config YAML at `cluster-config/management/charts/cluster-api-operator.yaml` follows the existing rendered-manifests pattern (same format as `argocd.yaml`). Four Provider CRs and one ExternalSecret are declared as `extraObjects` so they are rendered alongside the operator's own manifests.

**Tech Stack:** Helm, cluster-api-operator, ExternalSecrets (ClusterSecretStore `aws-secrets-manager`), CAPH (Hetzner), kubeadm CAPI providers.

---

### Task 1: Look up latest stable versions

**Files:**
- No files modified — research only.

- [ ] **Step 1: Look up the cluster-api-operator Helm chart version**

  Visit https://github.com/kubernetes-sigs/cluster-api-operator/releases and note the latest stable release tag (e.g. `v0.15.0`). The chart version matches the release tag (strip the `v` prefix for the chart version field, e.g. `0.15.0`).

- [ ] **Step 2: Look up the CAPI core/kubeadm provider version**

  Visit https://github.com/kubernetes-sigs/cluster-api/releases and note the latest stable release tag (e.g. `v1.9.3`). This version is used for `CoreProvider`, `BootstrapProvider`, and `ControlPlaneProvider`. Keep the `v` prefix in the `spec.version` field.

- [ ] **Step 3: Look up the CAPH (Hetzner) provider version**

  Visit https://github.com/syself/cluster-api-provider-hetzner/releases and note the latest stable release tag (e.g. `v1.1.0`). This version is used for `InfrastructureProvider`. Keep the `v` prefix.


---

### Task 2: Create the chart manifest

**Files:**
- Create: `cluster-config/management/charts/cluster-api-operator.yaml`

- [ ] **Step 1: Create the file**

  Create `cluster-config/management/charts/cluster-api-operator.yaml` with the content below. Fill in the version placeholders from Task 1.

  ```yaml
  name: cluster-api-operator
  namespace: capi-operator-system
  chart:
    source: https://kubernetes-sigs.github.io/cluster-api-operator/
    name: cluster-api-operator
    version: <OPERATOR_CHART_VERSION>   # e.g. 0.15.0 — no leading v
  values:
    extraObjects:
      - apiVersion: external-secrets.io/v1beta1
        kind: ExternalSecret
        metadata:
          name: hetzner-token
          namespace: caph-system
        spec:
          refreshInterval: 1h
          secretStoreRef:
            name: aws-secrets-manager
            kind: ClusterSecretStore
          target:
            name: hetzner
            template:
              data:
                hcloud-token: "{{ .hcloud_token }}"
          data:
            - secretKey: hcloud_token
              remoteRef:
                key: apikeys/hetzner/management
                # no property field — secret is a flat token string

      - apiVersion: operator.cluster.x-k8s.io/v1alpha2
        kind: CoreProvider
        metadata:
          name: cluster-api
          namespace: capi-system
        spec:
          version: <CAPI_VERSION>   # e.g. v1.9.3 — keep leading v

      - apiVersion: operator.cluster.x-k8s.io/v1alpha2
        kind: BootstrapProvider
        metadata:
          name: kubeadm
          namespace: capi-kubeadm-bootstrap-system
        spec:
          version: <CAPI_VERSION>   # same as CoreProvider

      - apiVersion: operator.cluster.x-k8s.io/v1alpha2
        kind: ControlPlaneProvider
        metadata:
          name: kubeadm
          namespace: capi-kubeadm-control-plane-system
        spec:
          version: <CAPI_VERSION>   # same as CoreProvider

      - apiVersion: operator.cluster.x-k8s.io/v1alpha2
        kind: InfrastructureProvider
        metadata:
          name: hetzner
          namespace: caph-system
        spec:
          version: <CAPH_VERSION>   # e.g. v1.1.0 — keep leading v
  ```

---

### Task 3: Verify the manifest renders

**Files:**
- Read: `cluster-config/management/charts/cluster-api-operator.yaml`

- [ ] **Step 1: Render the chart**

  Run:
  ```bash
  go run ./util/render-chart -config cluster-config/management/charts/cluster-api-operator.yaml
  ```

  Expected: helm template output printed to stdout containing (at minimum):
  - A `Deployment` in namespace `capi-operator-system` for the operator itself
  - The five `extraObjects` resources (ExternalSecret, CoreProvider, BootstrapProvider, ControlPlaneProvider, InfrastructureProvider)

  If the command exits non-zero, check:
  - Version numbers are valid (helm will fail if it can't find the chart version)
  - YAML indentation is correct (especially inside `extraObjects`)
  - The chart source URL is reachable

- [ ] **Step 2: Verify extraObjects appear in output**

  Run:
  ```bash
  go run ./util/render-chart -config cluster-config/management/charts/cluster-api-operator.yaml \
    | grep -E "^kind:"
  ```

  Expected output must include:
  ```
  kind: ExternalSecret
  kind: CoreProvider
  kind: BootstrapProvider
  kind: ControlPlaneProvider
  kind: InfrastructureProvider
  ```
  (plus the operator's own resources)

  If any of the Provider kinds are missing, the chart version may not support `extraObjects` — check the operator chart's `values.yaml` for the correct key name.

---

### Task 4: Commit on a branch

- [ ] **Step 1: Create a branch**

  ```bash
  git checkout -b feat/cluster-api-operator
  ```

- [ ] **Step 2: Stage and commit**

  ```bash
  git add cluster-config/management/charts/cluster-api-operator.yaml
  git commit -m "feat: add cluster-api-operator chart for management cluster"
  ```
