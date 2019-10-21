provider "google" {  
	credentials = "${file("origAccount.json")}"  
	project = "${var.gcloud-project}"  
	region = "${var.gcloud-region}"  
}