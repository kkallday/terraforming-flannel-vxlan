resource "google_compute_network" "my-network" {
  name                    = "my-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}
