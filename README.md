# orm-stack-oke-nvidia-drug-research-blueprint

## Introduction

This stack deploys the infrastructure required to run Nvidia NIM Agent Blueprint for Generative Virtual Screening in Drug Discovery. The agent leverages three high performance AI models: **AlphaFold2** for folding, **MolMIM** for molecular generation, and **DiffDock** for protein-ligand docking.

### AlphaFold2

[AlphaFold](https://github.com/google-deepmind/alphafold) is a deep learning model developed by Google's AI company, DeepMind, to predict protein structures. It uses neural networks trained on known protein structures to estimate the 3D shape of proteins based on their amino acid sequences. AlphaFold made a significant breakthrough in 2020 by achieving unprecedented accuracy in the Critical Assessment of protein Structure Prediction (CASP) competition, effectively solving the long-standing protein folding problem. The model's ability to rapidly and accurately predict protein structures has wide-ranging implications for biological research, drug discovery, and understanding diseases at the molecular level.

AlphaFold2's initial training focused on individual protein chains, making it highly proficient in predicting their structures. Subsequently, a variant called [AlphaFold-Multimer](https://doi.org/10.1101/2021.10.04.463034) was developed to address protein-protein complexes. This version can predict structures of both homo-multimers (complexes of identical protein chains) and hetero-multimers (complexes of different protein chains).

AlphaFold-Multimer is available as a different [NIM container on NGC](https://catalog.ngc.nvidia.com/orgs/nim/teams/deepmind/containers/alphafold2-multimer).

### MolMIM

[MolMIM](https://arxiv.org/pdf/2208.09016) a probabilistic auto-encoder based model, designed for the controlled generation of small molecules, which is crucial in drug discovery. MolMIM uses Mutual Information Machine (MIM) learning to create a dense and informative latent space, allowing for the generation of valid molecules from random perturbations of latent codes. The model outperforms several other encoder-decoder models in terms of validity, uniqueness, and novelty of generated molecules. Additionally, MolMIM demonstrates state-of-the-art results in single-property and multi-objective optimization tasks, attributed to its structured latent space that clusters similar molecules together, facilitating efficient molecule optimization.

### DiffDock

[DiffDock](https://arxiv.org/abs/2210.01776) is an innovative molecular docking model developed by researchers at MIT, designed to enhance drug development. Utilizing diffusion generative models, DiffDock predicts multiple potential binding poses for protein-ligand interactions, refining random poses in just 20 steps. This approach significantly improves the accuracy and efficiency of identifying binding sites compared to traditional methods. By accelerating drug discovery, reducing development costs, and identifying potential side effects early on, DiffDock represents a paradigm shift in computational drug design, offering a faster and more reliable alternative to current state-of-the-art tools.

## Getting started

This stack deploys an OKE cluster with two nodepools:
- one nodepool with flexible shapes
- one nodepool with GPU shapes

And several supporting applications using helm:
- nginx
- cert-manager
- jupyterhub

with the scope of demonstrating how generative AI and accelerated NIM microservices can be used to design optimized small molecules smarter and faster.
- [nVidia NIM AlphaFold2](https://docs.nvidia.com/nim/bionemo/alphafold2/latest/overview.html) is used to determine the 3D structure of the proteins.
- [nVidia NIM MolMIM](https://docs.nvidia.com/nim/bionemo/molmim/latest/overview.html) is used to generate novel molecules with optimized chemical properties starting from a seed molecule of interest.
- [nVidia NIM DiffDock](https://docs.nvidia.com/nim/bionemo/diffdock/latest/overview.html) is used to determine how the novel molecule binds to the protein of interest, offering valuable insights for subsequent investigations. 

**Note:** For the helm deployments is necessary to enable bastion and operator hosts provisioning (with the associated policy for the operator to manage the cluster), **or** configure the cluster with a public API endpoint.

In case the bastion and the operator hosts are not created, is a prerequisite to have the following tools already installed and configured:
- bash
- helm
- jq
- kubectl
- oci-cli

## Helm Deployments

### Nginx

[Nginx](https://kubernetes.github.io/ingress-nginx/deploy/) is deployed and configured as default ingress controller.

### Cert-manager

[Cert-manager](https://cert-manager.io/docs/) is deployed to handle the configuration of TLS certificate for the configured ingress resources. Currently it's using the [staging Let's Encrypt endpoint](https://letsencrypt.org/docs/staging-environment/).

### Jupyterhub

[Jupyterhub](https://jupyterhub.readthedocs.io/en/stable/) will be accessible to the address: [https://jupyter.a.b.c.d.nip.io](https://jupyter.a.b.c.d.nip.io), where a.b.c.d is the public IP address of the load balancer associated with the NGINX ingress controller.

JupyterHub is using a dummy authentication scheme (user/password) and the access is secured using the variables:

```
jupyter_admin_user
jupyter_admin_password
```

It also supports the option to automatically clone a git repo when user is connecting and making it available in the JupyterHub home directory.

If you are looking to integrate JupyterHub with an Identity Provider, please take a look at the options available here: https://oauthenticator.readthedocs.io/en/latest/tutorials/provider-specific-setup/index.html

For integration with your OCI tenancy IDCS domain, you may go through the following steps:

1. Setup a new **Application** in IDCS

- Navigate to the following address: https://cloud.oracle.com/identity/domains/

- Click on the `OracleIdentityCloudService` domain

- Navigate to `Integrated applications` from the left-side menu

- Click **Add application**

- Select *Confidential Application* and click **Launch worflow**

2. Application configuration

- Under *Add application details* configure

    name: `Jupyterhub`

    (all the other fields are optional, you may leave them empty)

- Under *Configure OAuth*

    Resource server configuration -> *Skip for later*

    Client configuration -> *Configure this application as a client now*

    Authorization:
    - Check the `Authorization code` check-box
    - Leave the other check-boxes unchecked

    Redirect URL:

    `https://<jupyterhub-domain>/hub/oauth_callback`

- Under *Configure policy*
    
    Web tier policy -> *Skip for later*

- Click **Finish**

- Scroll down wehere you fill find the *General Information* section.

- Copy the `Client ID` and `Client secret`:

- Click **Activate** button at the top.

3. Connect to the OKE cluster and update the JupyterHub Helm deployment values.

- Create a file named `oauth2-values.yaml` with the following content (make sure to fill-in the values relevant for your setup)

    ```yaml
    hub:
      config:
        Authenticator:
          allow_all: true
        GenericOAuthenticator:
          client_id: <client-id>
          client_secret: <client-secret>

          authorize_url:  <idcs-stripe-url>/oauth2/v1/authorize
          token_url:  <idcs-stripe-url>/oauth2/v1/token
          userdata_url:  <idcs-stripe-url>/oauth2/v1/userinfo

          scope:
          - openid
          - email
          username_claim: "email"
        JupyterHub:
          authenticator_class: generic-oauth
    ```

    **Note:** IDCS stripe URL can be fetched from the OracleIdentityCloudService IDCS Domain Overview -> Domain Information -> Domain URL.

    Should be something like this: `https://idcs-18bb6a27b33d416fb083d27a9bcede3b.identity.oraclecloud.com`


- Execute the following command to update the JupyterHub Helm deployment:

    ```bash
    helm upgrade jupyterhub jupyterhub --repo https://hub.jupyter.org/helm-chart/ --reuse-values -f oauth2-values.yaml
    ```


### Nvidia NIMs 

All Nvidia NIM containers rely on NGC to pull the optimized model for the detected hardware. Because of this you need to sign-up with [Nvidia NGC](https://docs.nvidia.com/ngc/index.html) and configure an [API Key](https://docs.nvidia.com/ngc/gpu-cloud/ngc-user-guide/index.html#ngc-api-keys).

Parameters:
- `NGC_API_KEY`

#### AlphaFold2

AlphaFold2 is deployed using [NIM](https://docs.nvidia.com/nim/index.html).

Parameters:
- `alphafold2_image_repository` and `alphafold2_image_tag` - used to specify the container image location

To customize the helm chart deployment, create a file `alphafold2_user_values_override.yaml` with the values override and upload it during the ORM stack based deployment.

In case of manual deployment, assign this multiline string to the `alphafold2_user_values_override` variable.

#### MolMIM

MolMIM is deployed using [NIM](https://docs.nvidia.com/nim/index.html).

Parameters:
- `molmim_image_repository` and `molmim_image_tag` - used to specify the container image location

To customize the helm chart deployment, create a file `molmim_user_values_override.yaml` with the values override and upload it during the ORM stack based deployment.

In case of manual deployment, assign this multiline string to the `molmim_user_values_override` variable.

#### DiffDock

DiffDock is deployed using [NIM](https://docs.nvidia.com/nim/index.html).

Parameters:
- `diffdock_image_repository` and `diffdock_image_tag` - used to specify the container image location

To customize the helm chart deployment, create a file `diffdock_user_values_override.yaml` with the values override and upload it during the ORM stack based deployment.

In case of manual deployment, assign this multiline string to the `diffdock_user_values_override` variable.

**Note:**
- The initial container start time will be long (~6 hours) as the required databases (~500 GB) are pulled from NGC.
- Make sure the deployment meets the [minimum hardware requirements](https://docs.nvidia.com/nim/bionemo/alphafold2/latest/prerequisites.html#supported-hardware).

## How to deploy?

1. Deploy via ORM
- Create a new stack
- Upload the TF configuration files
- Configure the variables
- Apply

[![Deploy to OCI](https://docs.oracle.com/en-us/iaas/Content/Resources/Images/deploy-to-oracle-cloud.svg)](https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/robo-cap/orm-stack-oke-nvidia-drug-research-blueprint/archive/refs/tags/v1.0.zip)

2. Local deployment

- Create a file called `terraform.auto.tfvars` with the required values.

```
# ORM injected values

region            = "eu-frankfurt-1"
tenancy_ocid      = "ocid1.tenancy.oc1..aaaaaaaaiyavtwbz4kyu7g7b6wglllccbflmjx2lzk5nwpbme44mv54xu7dq"
compartment_ocid  = "ocid1.compartment.oc1..aaaaaaaaqi3if6t4n24qyabx5pjzlw6xovcbgugcmatavjvapyq3jfb4diqq"

# OKE Terraform module values
create_iam_resources     = false
create_iam_tag_namespace = false
ssh_public_key           = "<ssh_public_key>"

## NodePool with non-GPU shape is created by default with size 1
simple_np_flex_shape   = { "instanceShape" = "VM.Standard.E4.Flex", "ocpus" = 2, "memory" = 12 }

## NodePool with GPU shape is created by default with size 0
gpu_np_size  = 3
gpu_np_shape = "VM.GPU.A10.1"

## OKE Deployment values
cluster_name           = "oke-nim-gvs-agent"
vcn_name               = "oke-vcn-nim-gvs-agent"
compartment_id         = "ocid1.compartment.oc1..aaaaaaaaqi3if6t4n24qyabx5pjzlw6xovcbgugcmatavjvapyq3jfb4diqq"

# Jupyter Hub deployment values
jupyter_admin_user     = "oracle-ai"
jupyter_admin_password = "<admin-password>"
jupyter_playbooks_repo = "https://github.com/robo-cap/generative-virtual-screening.git"

# NIM Deployment values
NGC_API_KEY            = "<ngc_api_key>"
alphafold2_image_repository   = "nvcr.io/nim/mit/diffdock"
alphafold2_image_tag          = "1.2.0"
molmim_image_repository       = "nvcr.io/nim/nvidia/molmim"
molmim_image_tag              = "1.0.0"
diffdock_image_repository     = "nvcr.io/nim/mit/diffdock"
diffdock_image_tag            = "2.0.0"
```

- Execute the commands

```
terraform init
terraform plan
terraform apply
```

## Known Issues

If `terraform destroy` fails, manually remove the LoadBalancer resource configured for the Nginx Ingress Controller.

After `terrafrom destroy`, the block volumes corresponding to the PVCs used by the applications in the cluster won't be removed. You have to manually remove them.
