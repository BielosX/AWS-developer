variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "lb_subnets" {
  type = list(string)
}