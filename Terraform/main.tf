terraform {
  required_version = ">= 1.0"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
  name    = "meine-app-allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "8080"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["meine-app"]
}

resource "google_compute_firewall" "allow_https" {
  name    = "meine-app-allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["meine-app"]
}

# Static IP
resource "google_compute_address" "static_ip" {
  name   = "meine-app-ip"
  region = var.region
}

# VM Instance
resource "google_compute_instance" "app" {
  name         = "meine-app-vm"
  machine_type = "e2-micro"  # Free tier!
  zone         = var.zone
  tags         = ["meine-app", "http-server", "https-server"]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
      size  = 10
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata = {
    gce-container-declaration = <<EOF
spec:
  containers:
  - name: meine-app
    image: europe-west1-docker.pkg.dev/${var.project_id}/meine-app/app:latest
    env:
    - name: PORT
      value: "8080"
    ports:
    - containerPort: 8080
      hostPort: 8080
    restartPolicy: Always
EOF
    # Startup Script für Caddy
    startup-script = file("${path.module}/../scripts/startup.sh")
  }

  service_account {
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }
}

output "instance_ip" {
  value = google_compute_address.static_ip.address
}