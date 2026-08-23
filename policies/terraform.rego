package terraform

deny contains msg if {
    resource := input.resource_changes[_]

    resource.type == "aws_s3_bucket"

    tags := object.get(resource.change.after, "tags", {})
    environment := object.get(tags, "Environment", null)

    environment == null

    msg := sprintf(
        "Resource %s must have an Environment tag",
        [resource.address]
    )
}

deny contains msg if {
    resource := input.resource_changes[_]

    resource.type == "aws_s3_bucket"

    tags := object.get(resource.change.after, "tags", {})
    owner := object.get(tags, "Owner", null)

    owner == null

    msg := sprintf(
        "Resource %s must have an Owner tag",
        [resource.address]
    )
}
