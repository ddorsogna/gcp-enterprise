# GCP Enterprise Terraform Setup

## Pre-Requisites
1. Bootstrap Terraform
    - See Bootstrap section below
    - Reference: [Managing GCP project with Terraform](https://cloud.google.com/community/tutorials/managing-gcp-projects-with-terraform)
2. Download the Terraform Service Account Private SSH Key
3. Configure Terraform Service Account privileges for Cloud Identity
    - Select a Cloud Identity User to Impersonate
    - Follow: [Terraform G Suite Provider](https://github.com/DeviaVir/terraform-provider-gsuite/blob/master/README.md)
    - Reference: [G Suite Domain-Wide Delegation of Authority](https://developers.google.com/admin-sdk/directory/v1/guides/delegation)

## Deployment Order
1. Organization
    - (e.g. [./examples/org/lor.tfvars.example](./examples/org/lor.tfvars.example))
    - Comment out Leaf Folders configuration due to:
     - Dependency on a Host Project with a Shared VPC Network
     - Dependency on an Images Project

## Bootstrap
The following commands can be run in GCP Console Cloud Shell
```
export TF_VAR_org_id=<your organization id>
export TF_VAR_billing_account=<your billing account id>
export TF_ADMIN=<your Terraform admin project name & id>
export TF_CREDS=<your path to the terraform service account private key> (e.g. ~/.config/gcloud/terraform-<org_id>.json)

gcloud projects create ${TF_ADMIN} \
  --organization ${TF_VAR_org_id} \
  --set-as-default

gcloud beta billing projects link ${TF_ADMIN} \
  --billing-account ${TF_VAR_billing_account}

gcloud iam service-accounts create terraform-${TF_VAR_org_id} \
  --display-name "Terraform service account"

gcloud iam service-accounts keys create ${TF_CREDS} \
  --iam-account terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com
```

### Organization Level Roles
Admin Project Role Assignment
```
gcloud projects add-iam-policy-binding ${TF_ADMIN} \
  --member serviceAccount:terraform-${TF_VAR_org_id}@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/viewer
```

To Create Terraform Service Accounts for Folders (and containing Projects)
```
gcloud projects add-iam-policy-binding ${TF_ADMIN} \
  --member serviceAccount:terraform-${TF_VAR_org_id}@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/iam.serviceAccountAdmin
```

### Organization Level Roles
To manage Folders
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/resourcemanager.folderCreator
```

To create Projects (not included in other Roles)
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/resourcemanager.projectCreator
```

To manage Projects' association with Billing Accounts
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/billing.user
```

To manage Shared VPC Network configuration
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/compute.xpnAdmin
```

To manage Organization Policies
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/orgpolicy.policyAdmin
```

To manage Organization Policies' association with Organization & Folders
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/resourcemanager.organizationAdmin
```

To align with automatic assignment of Project Owner role when Projects are created
```
gcloud organizations add-iam-policy-binding ${TF_VAR_org_id} \
  --member serviceAccount:terraform-admin@${TF_ADMIN}.iam.gserviceaccount.com \
  --role roles/owner
```

### Admin Project API Enablement
(Required for Terraform Service Accounts to use APIs)
```
gcloud services enable admin.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable cloudresourcemanager.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable cloudbilling.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable compute.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable container.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable iam.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable servicenetworking.googleapis.com \
  --project ${TF_ADMIN}
gcloud services enable sqladmin.googleapis.com \
  --project ${TF_ADMIN}
```