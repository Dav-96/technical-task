terraform {
  backend "gcs" {
    bucket = "test-dav-390413-terraform-state"
    prefix = "terraform/dev/state"
  }
}
