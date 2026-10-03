terraform {
  # 1.10: S3 state locking with use_lockfile (live/root.hcl), no lock table.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
