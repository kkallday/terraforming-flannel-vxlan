resource "google_compute_address" "etcd" {
  name         = "etcd-ip"
  subnetwork   = google_compute_subnetwork.my-subnet-1.id
  address_type = "INTERNAL"
  address      = "10.0.1.2"
  region       = "us-central1"
}

resource "google_compute_address" "cell-1" {
  name         = "cell-1-ip"
  subnetwork   = google_compute_subnetwork.my-subnet-1.id
  address_type = "INTERNAL"
  address      = "10.0.1.3"
  region       = "us-central1"
}

resource "google_compute_address" "cell-2" {
  name         = "cell-2-ip"
  subnetwork   = google_compute_subnetwork.my-subnet-2.id
  address_type = "INTERNAL"
  address      = "10.0.2.3"
  region       = "us-central1"
}
