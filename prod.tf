resource "google_compute_subnetwork" "prod" {  
	name = "prod-${var.platform-name}-${var.gcloud-region}"  
	ip_cidr_range = "10.1.2.0/24"  
	network = "${google_compute_network.platform.self_link}"  
	region = "${var.gcloud-region}"  
}
resource "google_container_cluster" "prod" {  
	name = "prod"  
	network = "${google_compute_network.platform.name}"  
	subnetwork = "${google_compute_subnetwork.prod.name}"  
	zone = "${var.gcloud-zone}"  
  
	initial_node_count = 1  
  
	node_config {  
		machine_type = "n1-standard-1"  
	}  
}