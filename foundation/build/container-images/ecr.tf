resource "aws_ecr_repository" "this" {
  for_each = local.container_images

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
}
