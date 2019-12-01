# Google Cloud K8S cluster using terraform.

This project aims at creating a Highly scalable K8S cluster by using terraform.   
The idea is to follow Infrastructure as code such that it is easy to manage. 
In order to maintain cross compatablity between cloud providers terraform is used instead of google deployment manager/AWS cloud formation.

### Requirements:
1. Google Cloud Account.
2. Terraform.
3. Google SDK.

### GCP Resources used:
1. VPC.
2. Kubernetes cluster with custom node pool.
3. Memorystore.

### Prerequisites:
1. Google service account with permissions to create K8S cluster.
2. Service account file.

### Steps to run:
1. Run `terraform init` to download required libraries.
2. Run `terraform plan` which will show what will happen.
3. Run `terraform apply` and approve te changes by typing `yes` when prompted.

### Notes:
1. All the variables have default value in order to over ride either use `-var=variablename=value` or export them as `TF_VAR_variablename`. As mentioned in the [documentation][1].
2. Since mostly we will be given service account file with least privileges. Service account creation is not a part of the project. The same can be created with gcloud as per this [google community tutorial][2].
 
[1]: https://www.terraform.io/docs/configuration/variables.html
[2]: https://elastisys.com/2019/04/12/kubernetes-on-gke-from-scratch-using-terraform/