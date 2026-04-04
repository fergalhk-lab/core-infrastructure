# container_images: map of image_name => {
#   github_workflows: list of {
#     repo:     string               # "org/repo" — no github.com prefix
#     branches: optional list(string) # omit or null to allow all branches
#   }
# }
locals {
  container_images = {
    "apps/billsplit" = {
      github_workflows = [
        { repo = "fergalhk-lab/apps", branches = ["main"] }
      ]
    }
  }
}
