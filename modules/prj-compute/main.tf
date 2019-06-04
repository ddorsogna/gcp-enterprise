# Module to create a Service Project with a Subnet

locals {
  deployment_name = "${var.company_id}-${var.asset_id}-${var.component_id}${var.environment_id == "" ? "" : format("-%s", var.environment_id)}${var.instance_id == "" ? "" : format("-%s", var.instance_id)}"
}

data "google_compute_network" "shared_vpc" {
  name    = "${var.shared_vpc_name}"
  project = "${var.host_project_id}"
}

# Generate a new ID when a Project name is created or changed
resource "random_id" "project" {
  keepers = {
    name = "${local.deployment_name}"
  }

  byte_length = 3
}

# Create Service Project.
# (Auto-Create Network is not set to False due to Organization Policy)
resource "google_project" "project" {
  name            = "${local.deployment_name}"
  project_id      = "${local.deployment_name}${var.project_id_suffix ? format("-%s", random_id.project.hex) : ""}"
  org_id          = "${var.org_id}"
  folder_id       = "${var.folder_id}"
  billing_account = "${var.billing_account_id}"
}

# Enable Compute API in Service Project
resource "google_project_service" "project_compute" {
  project            = "${google_project.project.project_id}"
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Set Project to be a Service Project & associate with Host Project
resource "google_compute_shared_vpc_service_project" "project" {
  host_project    = "${var.host_project_id}"
  service_project = "${google_project.project.project_id}"
  depends_on      = ["google_project_service.project_compute"]
}

# Create a Subnet for Service Project with a single Primary IP Range (e.g. for VMs)
resource "google_compute_subnetwork" "service_subnet" {
  name                     = "${local.deployment_name}-subnet"
  project                  = "${var.host_project_id}"
  region                   = "${var.region}"
  ip_cidr_range            = "${var.ipv4_range_primary}"
  network                  = "${data.google_compute_network.shared_vpc.self_link}"
  enable_flow_logs         = "${var.subnet_flow_logs}"
  private_ip_google_access = true
}

resource "google_compute_project_metadata_item" "oslogin" {
  project    = "${google_project.project.project_id}"
  key        = "enable-oslogin"
  value      = "TRUE"
  depends_on = ["google_compute_shared_vpc_service_project.project"]
}

# Assign subnet-use privileges to the Service Project's Google APIs Service Agent with IAM
# Needs to be manually re-run a second time if Subnetwork is re-created
resource "google_compute_subnetwork_iam_member" "service_network_cloudservices" {
  provider   = "google-beta"
  project    = "${var.host_project_id}"
  region     = "${var.region}"
  subnetwork = "${google_compute_subnetwork.service_subnet.name}"
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_project.project.number}@cloudservices.gserviceaccount.com"
  depends_on = ["google_compute_shared_vpc_service_project.project"]
}

resource "google_compute_subnetwork_iam_member" "service_network_terraform" {
  provider   = "google-beta"
  project    = "${var.host_project_id}"
  region     = "${var.region}"
  subnetwork = "${google_compute_subnetwork.service_subnet.name}"
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${var.terraform_delegate_email}"
  depends_on = ["google_compute_shared_vpc_service_project.project"]
}

resource "google_compute_subnetwork_iam_member" "service_network_editors" {
  provider   = "google-beta"
  project    = "${var.host_project_id}"
  region     = "${var.region}"
  subnetwork = "${google_compute_subnetwork.service_subnet.name}"
  role       = "roles/compute.networkUser"
  member     = "group:${var.editor_group_email}"
  depends_on = ["google_compute_shared_vpc_service_project.project"]
}