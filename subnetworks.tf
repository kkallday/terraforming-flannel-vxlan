resource "google_compute_subnetwork" "my-subnet-1" {
  name          = "my-subnet-1"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.my-network.id
}

resource "google_compute_subnetwork" "my-subnet-2" {
  name          = "my-subnet-2"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.my-network.id
}
