# container_images: map of image_name => {
#   github_workflows: list of {
#     repo: string  # "org/repo" — no github.com prefix
#   }
# }
locals {
  container_images = {
    "apps/billsplit" = {
      github_workflows = [
        { repo = "fergalhk-lab/apps" }
      ]
    }
  }
}
