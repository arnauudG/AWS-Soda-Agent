variable "name" {
  description = "Name of the security group"
  type        = string
}

variable "description" {
  description = "Description of the security group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the security group will be created"
  type        = string
}

variable "ingress_rules" {
  description = "List of ingress rules"
  type        = list(string)
  default     = []
}

variable "ingress_with_cidr_blocks" {
  description = "List of ingress rules with CIDR blocks"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
    cidr_blocks = string
  }))
  default = []
}

variable "ingress_with_source_security_group_id" {
  description = "List of ingress rules with source security group ID"
  type = list(object({
    from_port                = number
    to_port                  = number
    protocol                 = string
    description              = string
    source_security_group_id = string
  }))
  default = []
}

variable "egress_rules" {
  description = "List of egress rules"
  type        = list(string)
  default     = []
}

variable "egress_with_cidr_blocks" {
  description = "List of egress rules with CIDR blocks"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
    cidr_blocks = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default     = {}
}
