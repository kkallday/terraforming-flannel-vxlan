resource "google_compute_instance" "etcd" {
  name         = "etcd"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.my-subnet-1.self_link

    network_ip = google_compute_address.etcd.address

    access_config {
      // Ephemeral public IP
    }
  }

  service_account {
    email = "${var.service_account_name}@${var.project_name}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "cell-1" {
  name         = "cell-1"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.my-subnet-1.self_link

    network_ip = google_compute_address.cell-1.address

    access_config {
      // Ephemeral public IP
    }
  }

  can_ip_forward = true

  service_account {
    email = "${var.service_account_name}@${var.project_name}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance" "cell-2" {
  name         = "cell-2"
  machine_type = "e2-medium"
  zone         = "us-central1-b"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.my-subnet-2.self_link

    network_ip = google_compute_address.cell-2.address

    access_config {
      // Ephemeral public IP
    }
  }

  can_ip_forward = true

  service_account {
    email = "${var.service_account_name}@${var.project_name}.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }
}
