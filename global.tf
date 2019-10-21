resource "google_compute_network" "platform" {  
	name = "${var.platform-name}"  
}
resource "google_compute_firewall" "ssh" {  
	name = "${var.platform-name}-ssh"  
	network = "${google_compute_network.platform.name}"  
	allow {  
		protocol = "tcp"  
		ports = ["80", "443", "8080", "8081"]  
	}  
	source_ranges = ["0.0.0.0/0"]  
}
resource "google_dns_managed_zone" "sample-platform" {  
	name = "endless-beer"  
	dns_name = "endless.beer."  
	description = "endless.beer DNS zone"  
}