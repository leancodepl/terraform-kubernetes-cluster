variable "plugin" {
  description = "The output of cluster module for plugins."
  type = object({
    cluster_id = string
  })
}

variable "viewers" {
  description = "A list of Object IDs of AAD groups that have view role."
  type        = set(string)
}

variable "admins" {
  description = "A list of Object IDs of AAD groups that have cluster admin role."
  type        = set(string)
}
