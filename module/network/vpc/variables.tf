variable "name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization"
  type        = bool
  default     = false
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Enable DNS support"
  type        = bool
  default     = true
}

variable "enable_flow_log" {
  description = "Enable VPC Flow Logs"
  type        = bool
  default     = false
}

variable "vpc_tags" {
  description = "Tags for the VPC"
  type        = map(string)
  default     = {}
}

variable "igw_tags" {
  description = "Tags for the Internet Gateway"
  type        = map(string)
  default     = {}
}

variable "nat_gateway_tags" {
  description = "Tags for NAT Gateways"
  type        = map(string)
  default     = {}
}

variable "nat_eip_tags" {
  description = "Tags for NAT Gateway EIPs"
  type        = map(string)
  default     = {}
}

variable "public_subnet_tags" {
  description = "Tags for public subnets"
  type        = map(string)
  default     = {}
}

variable "public_subnet_names" {
  description = "Names for public subnets"
  type        = list(string)
  default     = []
}

variable "public_route_table_tags" {
  description = "Tags for public route tables"
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Tags for private subnets"
  type        = map(string)
  default     = {}
}

variable "private_subnet_names" {
  description = "Names for private subnets"
  type        = list(string)
  default     = []
}

variable "private_route_table_tags" {
  description = "Tags for private route tables"
  type        = map(string)
  default     = {}
}

variable "manage_default_security_group" {
  description = "Manage default security group"
  type        = bool
  default     = true
}

variable "default_security_group_ingress" {
  description = "Default security group ingress rules"
  type        = list(any)
  default     = []
}

variable "default_security_group_egress" {
  description = "Default security group egress rules"
  type        = list(any)
  default     = []
}

variable "default_security_group_name" {
  description = "Name for default security group"
  type        = string
  default     = null
}

variable "default_security_group_tags" {
  description = "Tags for default security group"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
