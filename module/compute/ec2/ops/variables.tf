variable "name" {
  description = "Name of the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami" {
  description = "AMI ID"
  type        = string
  default     = null
}

variable "ami_ssm_parameter" {
  description = "SSM parameter for AMI"
  type        = string
  default     = null
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "root_block_device" {
  description = "Root block device configuration"
  type        = list(any)
  default     = []
}

variable "create_iam_instance_profile" {
  description = "Create IAM instance profile"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "IAM role name for the instance"
  type        = string
}

variable "iam_role_use_name_prefix" {
  description = "Use name prefix for IAM role"
  type        = bool
  default     = true
}

variable "iam_role_policies" {
  description = "IAM role policies"
  type        = map(string)
  default     = {}
}

variable "iam_inline_policies" {
  description = "Inline IAM policies (JSON) to attach to the instance role"
  type        = map(string)
  default     = {}
}

variable "metadata_options" {
  description = "Instance metadata options"
  type = object({
    http_endpoint               = string
    http_tokens                 = string
    http_put_response_hop_limit = number
    instance_metadata_tags      = string
  })
  default = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }
}


variable "placement_group" {
  description = "Placement group"
  type        = string
  default     = null
}

variable "tenancy" {
  description = "Instance tenancy"
  type        = string
  default     = "default"
}

variable "ebs_optimized" {
  description = "Enable EBS optimization"
  type        = bool
  default     = false
}

variable "user_data_base64" {
  description = "User data as base64 encoded string"
  type        = string
  default     = null
}

variable "user_data_replace_on_change" {
  description = "Replace instance when user data changes"
  type        = bool
  default     = false
}

variable "associate_public_ip_address" {
  description = "Associate public IP address"
  type        = bool
  default     = false
}

variable "monitoring" {
  description = "Enable detailed monitoring"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
