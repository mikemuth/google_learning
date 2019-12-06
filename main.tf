provider "google" {
#  credentials = file(var.credentials_file)
  credentials = file(var.GOOGLE_APPLICATION_CREDENTIALS)

  project = var.project
  region  = var.region
  zone    = var.zone
}

#resource "google_compute_network" "vpc_network" {
#  name = "terraform-network"
#}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = var.machine_types[var.environment]
  tags         = ["web", "dev"]

 provisioner "local-exec" {
    command = "echo ${google_compute_instance.vm_instance.name}:  ${google_compute_instance.vm_instance.network_interface[0].access_config[0].nat_ip} >> ip_address.txt"
  }

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
#    network = google_compute_network.vpc_network.name
    network    = module.network.network_name
    subnetwork = module.network.subnets_names[0]
    access_config {
      nat_ip = google_compute_address.vm_static_ip.address
    }
  }
}
resource "google_compute_address" "vm_static_ip" {
  name = "terraform-static-ip"
}
# New resource for the storage bucket our application will use.
resource "google_storage_bucket" "example_bucket" {
  name     = "terraform-example-bucket-mike-nov26"
  location = "US"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# Create a new instance that uses the bucket
resource "google_compute_instance" "another_instance" {
  # Tells Terraform that this VM instance must be created only after the
  # storage bucket has been created.
  depends_on = [google_storage_bucket.example_bucket]

  name         = "terraform-instance-2"
  machine_type = var.machine_types[var.environment]

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
#    network = google_compute_network.vpc_network.self_link
    network    = module.network.network_name
    subnetwork = module.network.subnets_names[0]
    access_config {
    }
  }
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "1.1.0"

  network_name = "terraform-vpc-network"
  project_id   = var.project

  subnets = [
    {
      subnet_name   = "subnet-01"
      subnet_ip     = var.cidrs[0]
      subnet_region = var.region
    },
    {
      subnet_name   = "subnet-02"
      subnet_ip     = var.cidrs[1]
      subnet_region = var.region

      subnet_private_access = "true"
    },
  ]

  secondary_ranges = {
    subnet-01 = []
    subnet-02 = []
  }
}

terraform {
  backend "remote" {
    organization = "mikes_org"

    workspaces {
      name = "google_example_workspace"
    }
  }
}
