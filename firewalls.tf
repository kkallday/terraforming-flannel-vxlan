resource "google_compute_firewall" "my-network-allow-ssh" {
  name    = "my-network-allow-ssh"
  network = google_compute_network.my-network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["${var.allow_ip_ssh}/32"]
}

resource "google_compute_firewall" "my-network-allow-all-internal" {
  name    = "my-network-allow-all-internal"
  network = google_compute_network.my-network.name

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.0.0/16"]
}
