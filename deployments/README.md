# deployments

This directory contains declarative configurations for Kubernetes that are rendered to a deployment repo, using the _rendered manifests_ pattern.

## Structure

* `deployments/` - base directory.
    * `{cluster name}/` - cluster to deploy to.
        * `charts/` - directory containing [helm manifests](#helm-manifest-syntax).
            * `{manifest}.yaml` - helm manifest.


## Helm manifest syntax

