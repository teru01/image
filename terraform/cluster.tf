provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_container_cluster" "primary" {
  project  = var.project_id
  name     = "imagechat-cluster"
  location = var.zone
  # ノードプールとクラスタを分けて作成したいが，ノードプールのないクラスタは作成できない
  # そのため小さなノードプールを作成してすぐに削除する．
  remove_default_node_pool = true
  initial_node_count       = 1

  # VPCネイティブクラスタを作成するために必要
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }
  network    = google_compute_network.private_network.self_link
  subnetwork = google_compute_subnetwork.imagechat-subnet.self_link

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  workload_identity_config {
    identity_namespace = local.gke_identity_namespace
  }
}

locals {
  gke_identity_namespace = "${var.project_id}.svc.id.goog"
}

resource "google_container_node_pool" "primary_nodes" {
  provider   = google-beta
  name       = "imagechat-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "n1-standard-2"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    # devstorage.read_onlyはGCRからイメージをpullするために必要
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
    ]

    workload_metadata_config {
      node_metadata = "GKE_METADATA_SERVER"
    }
  }
}

resource "google_compute_global_address" "default" {
  project = var.project_id
  name    = "global-ingress-ip"
}

provider "kubernetes" {}

resource "kubernetes_config_map" "k8s-map" {
  depends_on = [google_container_node_pool.primary_nodes]
  metadata {
    name = "tf-output"
  }

  data = {
    cloudsql-connection-name = google_sql_database_instance.master.connection_name,
    bucket-name              = google_storage_bucket.bucket.name
  }
}

resource "kubernetes_service_account" "ksa" {
  depends_on = [google_container_node_pool.primary_nodes]
  metadata {
    name = var.k8s_service_account
    annotations = {
      "iam.gke.io/gcp-service-account" = "${var.gke_service_account}@${var.project_id}.iam.gserviceaccount.com"
    }
  }
}

resource "kubernetes_secret" "db-info" {
  depends_on = [google_container_node_pool.primary_nodes]
  metadata {
    name = "db-info"
  }

  data = {
    db_user     = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  }
}

resource "kubernetes_secret" "tls" {
  depends_on = [google_container_node_pool.primary_nodes]
  metadata {
    name = "tls-cert"
  }

  type = "tls"

  data = {
    "tls.crt" = file(var.cert_path)
    "tls.key" = file(var.key_path)
  }
}
