variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "create_security_group" {
  description = "Create security group for interface endpoints"
  type        = bool
  default     = true
}

variable "security_group_name" {
  description = "Name of the security group"
  type        = string
  default     = null
}

variable "security_group_description" {
  description = "Description of the security group"
  type        = string
  default     = "Security group for VPC endpoints"
}

variable "security_group_rules" {
  description = "Security group rules for interface endpoints"
  type = list(object({
    type        = string
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "security_group_tags" {
  description = "Tags for the security group"
  type        = map(string)
  default     = {}
}

variable "endpoints" {
  description = "Map of VPC endpoints to create (interface or gateway)"
  type = map(object({
    service             = string
    service_type        = optional(string, "Interface")
    private_dns_enabled = optional(bool, true)
    subnet_ids          = optional(list(string), [])
    route_table_ids     = optional(list(string), [])
    security_group_ids  = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
