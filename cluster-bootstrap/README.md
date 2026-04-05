# cluster-bootstrap

This directory contains manifests that must be applied manually to bootstrap a cluster before ArgoCD can take over.

## Why manual?

These manifests are foundational — they configure ArgoCD itself to manage the cluster. They can't be applied by ArgoCD (the chicken-and-egg problem), so they're applied once by hand after a cluster is provisioned.

> TODO: Automate this step so manifests here are applied automatically on first boot.

## Manifests

### `applicationset.yaml`

An ArgoCD [ApplicationSet](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/) that discovers all applications in the [`k8s-deployments`](https://github.com/fergalhk-lab/k8s-deployments) repo and creates one ArgoCD Application per app per cluster.

**To apply to a cluster:**

```bash
kubectl apply -f cluster-bootstrap/applicationset.yaml
```

Once applied, ArgoCD discovers `clusters/{cluster}/{app}/` directories in `k8s-deployments` and syncs them to the cluster automatically. All subsequent changes go through the rendered manifests workflow — no further manual steps are needed.
