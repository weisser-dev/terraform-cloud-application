# Cloud Application #3 Infrastructre as Code - Create K8 Cluster on GCloud with Terraform
You're thinking about your last game of Buzzword Bingo when you read the headline? I trust you immediately!
But here I explain to you - what exactly is "Infrastructure as Code" using the examples of Terraform, Kubernetes and the Gcloud.

## WHAT is ``infrastructure as code``

First of all, it's more than just a buzzword that sounds fancy on presentations!
Infrastructure as Code means that a infrastructe is the result of executable code. This code can then be executed, duplicated, automatically deployed or deleted in the cloud. This approach uses the potential of the cloud very intensively. Because of that, systems could be created and scaled in the shortest possible time.  Infrastructure as Code makes the following points possible: 
- Centralized management of source code with versioning.
- High transparency
- Automated testing of server and virtual machine configuration
- Automated testing of deployments

It also has the advantage that anyone can simply delete and create a cluster that is always in the defined state - not like dedicated hardware!
What previously was a manual process is now automated and more efficient than ever. With the "Infrastructure as Code" concept, a company can quickly set up new servers, automate development cycles and respond quickly to new business requirements. In my opinion, Infrastructure as Code is part of every good cloud solution. 

## Terraform Kubernetes Setup:
### Requirements:
- Google Account
	- *if you don't have a cloud account yet: a credit card (to get free access to the Google Cloud)
- Terraform ([How to install terraform](https://learn.hashicorp.com/terraform/getting-started/install.html))

### Create a new GCloud Project
Because I expect that you haven't created a project yet, or your existing one is already configured somehow, we simply create a new project.
To do this, simply click on this link: [https://console.cloud.google.com/projectcreate](https://console.cloud.google.com/projectcreate)
As the project name we take something suitable, just like the project ID. In our case, because it is an example tutorial, the project is called: "cloud-application-tutorial".
After we have created the project, we start with configuring the cloud provider.

### Configure the Cloud Provider
So that we can authenticate ourselves against the Google Cloud, we have to generate a JSON with the corresponding access data once. This works as follows:
1.  Log in to the  [Google Developers Console](https://console.developers.google.com/)  and select the project you would like to obtain the credentials file for
2.  Go to the “API Manager” through the hamburger menu on the left-side
3.  Now click on “Credentials” on the left-side
4.  Click the “Create credentials” button and select “Service account key”  and choose “JSON” as the format. (If you have to create a new "Service Account" - sei dir sicher das er ausreichende rechte hat. Ich habe als Beispiel jetzt gesagt der Service Account ist Bearbeiter des gesamten Projektes)
5.  Click on “Create” to generate and download the key (save it to a new Directory called "terraform-cloud-application").

So that we can authenticate our system against the Google Cloud, we have to generate a JSON with the required credentials once. The next step is to configure our cloud provider for Terraform.
*important here is that our ServiceAccount.Json is located in the same folder as our terraform.file, or you store the credentials as an environment variable. 
But please **NEVER PUSH CREDENTIALS TO A PUBLIC REPO!!!**
Now let's create our cloud-provider file, called``providers.tf``:
```terraform
provider "google" {  
	credentials = "${file("account.json")}"  
	project = "${var.gcloud-project}"  
	region = "${var.gcloud-region}"  
}
``` 

### Create some Default-Variables
If you are wondering about where we got the "var.gcloud-project"-param at our providers.tf file... the answer is: currently we don't know it yet!
Because of that we have to create a file called ``variables.tf`` which contains them:
```terraform
variable "gcloud-region" { default = "europe-west1" }  
variable "gcloud-zone" { default = "europe-west1-b" }  
variable "gcloud-project" { default = "cloud-application-tutorial" }  
variable "platform-name" { default = "cloud-application-platform" }
```
**Info**: *If you create the files with VS code, you will be shown how often your variables are used. In this way you can sort out unnecessary variables later.*

### Network Basic Structure
Next we create a global network for our platform. *In this network, or rather its firewall, we determine which IP's have access to our application and which ports are open for these IP's.*
For our global network we create the file ``global.tf`` and define the network there as follows:
```terraform
resource "google_compute_network" "platform" {  
	name = "${var.platform-name}"  
}
```
As already said we need a firewall to restrict the traffic to http (port 80), https (port 443) and two custom ports (8080, 8081). The following is applied to our network above and only allows the protocol "tcp" with the defined ports. Through the ``source_ranges = ["0.0.0.0/0"] `` we allow all external traffic. For the firewall we add the following to the ``global.tf``:
```
resource "google_compute_firewall" "ssh" {  
	name = "${var.platform-name}-ssh"  
	network = "${google_compute_network.platform.name}"  
	allow {  
		protocol = "tcp"  
		ports = ["80", "443", "8080", "8081"]  
	}  
	source_ranges = ["0.0.0.0/0"]  
}
```
**Info**: *To access our network more easily, it is a good idea to register a domain name. For this we add the following:*
```terraform
resource "google_dns_managed_zone" "sample-platform" {  
	name = "endless-beer"  
	dns_name = "endless.beer."  
	description = "endless.beer DNS zone"  
}
```
*In the above example we’re setting up a DNS zone for the domain name “endless.beer” (yeah it's one of my websites :P). Of course, this will only work if you actually set the domain’s nameservers to the nameservers Google provides after you create the DNS zone by applying the Terraform code.*

### Create our K8-Cluster
We could now create several clusters for our network above. Depending on the company structure, it might be a good idea to have a development, test and production cluster. Of course this can be done individually. If you maybe work with canary releases, a production cluster is quite enough. Each cluster is defined in its own terraform file. That could be ``develop.tf``, ``qa.tf``, ``staging.tf``, ``production.tf`` or something like that.
I would like to show you how to create a cluster, in our case the "production" cluster. 
First we create the sub-network for the cluster. All configurations are stored in a file called: ``prod.tf``.  
```
resource "google_compute_subnetwork" "prod" {  
	name = "prod-${var.platform-name}-${var.gcloud-region}"  
	ip_cidr_range = "10.1.2.0/24"  
	network = "${google_compute_network.platform.self_link}"  
	region = "${var.gcloud-region}"  
}
```
Everything we define here for our subnet is: "the name", "the IP range", "the global network" (in which the subnet is located), "the region". 
It is important here that each network has its own IP range. Overlaps can cause problems when creating your subnetwork. (``terraform plan`` then thinks "the file looks correct" and ``terraform apply`` creates everything up to the collision of the networks and then aborts... which means that you have to manually delete everything, at the worst case). 
Our next ip_cidr_range would be e.g. 10.1.3.0/24 because 10.1.2.0/24 contains the IPs from 10.1.2.0 to 10.1.2.255.
So after we have created our subnet, we create the k8 cluster.
Here we define things like the initial Node Count (1), the [Node-Machine-Type] (https://cloud.google.com/compute/docs/machine-types) and our network settings (global network, subnet, and zone):
```
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
```

We've finished everything up to here! Next:
### Apply Terraform Code
If you are starting terraform for the first time, please run "terraform init". This will initialize all required providers (e.g. gcloud) once.
Before we apply our infrastructure / code into the cloud, we execute ``terraform plan``. ([Terraform Doc](https://www.terraform.io/docs/commands/plan.html) ).

When running the _plan_ command, Terraform will perform a refresh and determine which actions are necessary to achieve the desired state as specified in our code. 

But now run it! 
```bash
terraform plan -out prod.plan
```
We save the plan by specifying the _-out_ parameter which ensures that when we run _apply_ only the actions in this plan are executed.
Before we apply our infrastructure: *if you dont configure your gcloud yet, you have to enable the Compute Engine API: https://console.developers.google.com/apis/library/compute.googleapis.com?project=yourProject and the Kubernetes Engine API: https://console.developers.google.com/apis/library/container.googleapis.com?project=yourProject*
Let’s now run ``apply`` to actually create our infrastructure.

```
terraform apply
```
**Info**: *The apply and build of our new infrastructure can take a few minutes*

The sources for our Terraform example are available here:
[https://github.com/whit-e/terraform-cloud-application](https://github.com/whit-e/terraform-cloud-application)

## Connect to the Cluster
### Install required Tools:
>1.  [Install the Google Cloud SDK](https://cloud.google.com/sdk/docs/quickstarts), which includes the  `gcloud`  command-line tool.
>2.  Using the  `gcloud`  command line tool, install the  [Kubernetes](https://kubernetes.io/)  command-line tool.  `kubectl`  is used to communicate with Kubernetes, which is the cluster orchestration system of GKE clusters:   
>    gcloud components install kubectl
>3.  Install  [Docker Community Edition (CE)](https://docs.docker.com/engine/installation/)  on your workstation. You will use this to build a container image for the application.
>4.  Install the  [Git source control](https://git-scm.com/downloads)  tool to fetch the sample application from GitHub.

Quote from: [https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app](https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app)

### Build & Push Docker Images to the Cloud
#### build
Next we take one of the docker images we created here ( [https://whit-e.com/articles/dockerizing-our-service](https://whit-e.com/articles/dockerizing-our-service) ) and push it into the Google Cloud.

**Attention**: *We have to build our container as follows (because it will be placed in the Google Registry and there are some conventions here)*:
```
export PROJECT_ID=yourProject
docker build -t gcr.io/${PROJECT_ID}/node-api:v1 .
```
Since we have already worked with the containers in the previous [tutorial](https://whit-e.com/articles/dockerizing-our-service), we go directly to the next step:
#### push
From Google - https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app#step_2_upload_the_container_image 
> You need to upload the container image to a registry so that GKE can download and run it.
> First, configure Docker command-line tool to authenticate to  [Container Registry](https://cloud.google.com/container-registry)  (you need to run this only once):
> ``gcloud auth configure-docker``
>You can now use the Docker command-line tool to upload the image to your Container Registry:
> ``docker push gcr.io/${PROJECT_ID}/node-api:v1``

If everything works, we could see our image here: https://console.cloud.google.com/gcr/images
### Create a Container Deploymen
We can now deploy our container very easily via shell command or we can apply a deployment.yaml file. 
**Info**: *You must have [kubectl installed](https://kubernetes.io/de/docs/tasks/tools/install-kubectl/) and you must be in the corresponding Google Cluster*.
####  via Shell Command
Here you must first specify "What we create", "the name" and the "image of our container". 
```shell
kubectl create deployment node-api --image=gcr.io/${PROJECT_ID}/node-api:v1 
```
#### via deploy.yaml
```yaml
apiVersion: extensions/v1beta1  
kind: Deployment  
metadata:  
	name: node-api   
spec:  
	replicas: 1
template:  
	metadata:  
	labels:  
	app: node-api  
spec:  
	containers:  
		- name: node-api  
		image: eu.gcr.io/yourApplication/node-api:v1
imagePullPolicy: Always  
resources:  
	limits:  
		cpu: 20m  
		memory: 128Mi  
	requests:  
		cpu: 10m  
		memory: 64Mi  
```
Now you could apply the deploy.yaml with the following command: 
``kubectl apply -f deploy.yaml``

#### Portfreigabe
So that we can access to our application (from outside) we need a simple port mapping:
```
kubectl expose deployment node-api --type=LoadBalancer --port 8080 --target-port 3000
```
--port : is the port which is opened to the external traffic.
--target-port : is the port which is used by our application (defined at bin/www at our node.js app).


That's it! Google itself also has a VERY good guide on how to deploy a container (if mine isn't enough for you):  [https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app](https://cloud.google.com/kubernetes-engine/docs/tutorials/hello-app)


We have now successfully created a cluster with Terraform and then pushed a container into the Google Registry and deployed it manually.

__________
*The sources for our Terraform example are available here:*
[https://github.com/whit-e/terraform-cloud-application](https://github.com/whit-e/terraform-cloud-application)

If you have any questions, please feel free to write a comment. Even if something doesn't work anymore (software becomes more up-to-date and some methods outdated) just write!

In the next step we look at: "Deploy it Continuously to the Cloud"!
