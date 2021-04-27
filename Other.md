```
.docker                              Tools for build docker comtainers.
.docker/stub                         The ECS initial image. The image do sleep against run any commands.
.docker/awscli                       The Linux image for scripts console.

.scripts                             Deploy tools
scripts/deploy-init.sh               Deploy the Init template to crerate/update the base infrastructure.
scripts/deploy-project.sh            Create and deploy the project template to create/uptade the stack.
add_vpn_client.sh                    Create and download a new OpenVPN user profile.
ssh_key.sh                           Check and deploy SSH keys (runs from the before_deploy.sh).

.tmp                                 The working directory (GIT excluded)

standard                             EC2 and ECS projects
serverless                           Lambda projects

*/init                               The Base infrastructure (VPS, Subnets, etc.).
*/projects                           Projects.

template.yaml                        The CloudFormation stack template.
parameters/STAGE.ini                 Stack parameters for STAGE.
scripts/before_deploy.sh             Runs before the stack deployment/update (if exist).
scripts/before_deploy.sh             Runs after the stack successfylly deployment/update (if exist).

```

**Usage examples**

Start the console:  
```docker-compose run awscli```

To create/update the Init stack resources:  
```./deploy-init.sh -a AWS_PROFILE_NAME -t standard```  
Parameters:  
  \- a AWS profile name  
  \- t Environment type (standard, serverless)  
  \- e Environment name  

To create/update a project stack resources:  
```deploy-project.sh -a AWS_PROFILE_NAME -t standard -p bac-api```  
Parameters:  
  \- a AWS profile name  
  \- t Environment type (standard, serverless)  
  \- e Environment name  
  \- p The project name  

**Step-by-step guide to deploy the new Staging environment**

1. Register the new AWS account.
2. Create the new IAM user with Admin privileges and API only access.
3. Configure the new local aws profile (for example, "sac-staging").
4. Register the new domain name for Staging environment tacks.
5. Accept MR https://gitlab-ci.sactech.org/admins/iaac/cloudformation/merge_requests
6. Clone the ptogect https://gitlab-ci.sactech.org/admins/iaac/cloudformation
7. Check and edit the file /standard/init/parameters/staging.ini
8. Run the command ("sac-staging" - its the local profile name from the step 3):
```
./deploy-init.sh -a sac-staging -t standard 
```
Follow the script instructions.  

**Step-by-step guide to deploy projects in the Standard Staging environment**

9. Check the file /projects/vpn/parameters/staging.ini
10. To deploy VPN gateway run the command:  
```
./deploy-project.sh -a sac-staging -t standard -p vpn
```
11. Check the file /projects/gitlab-runner/parameters/staging.ini
12. To deploy GitLab Runner run the command:  
```
./deploy-project.sh -a sac-staging -t standard -p gitlab-runner
```
Check the page https://gitlab-ci.sactech.org/admin/runners for 2 new runners:  

```worker-staging```  
```worker-large-staging```  

13. Check the file /projects/adminer/parameters/staging.ini  
14. To deploy Adminer run the command:  
```
./deploy-project.sh -a sac-staging -t standard -p adminer
```
15. Check the file /projects/bac-api/parameters/staging.ini
16. To deploy BAC-API run the command ("sac-staging" - its the local profile name from the step 3):  
```
./deploy-project.sh -a sac-staging -t standard -p bac-api
```
**Batch/manual create VPN users**

The script ```add_vpn_client.sh``` can create and download a new OpenVPN user profile.  
Parameters:  
  \- a AWS profile name  
  \- e Environment name  
  \- t Environment type (standard, serverless)  
  \- u User name  
  \- p Password (optional)  
  \- s Path to save a profile (optional)  
  \- k Path to a SSH key file (optional)  

**The stub image**

The image used for first run "cli-like" tasks via a CloudFormation template.  
Run "cd .docker/stub && ./build.sh" to build and push into ECR the "stub:latest" image.  

**Note: Correct values for varCPUUnins and varRAMUnits**

> 512 (0.5 GB), 1024 (1 GB), 2048 (2 GB) - Available cpu values: 256 (.25 vCPU)  
> 1024 (1 GB), 2048 (2 GB), 3072 (3 GB), 4096 (4 GB) - Available cpu values: 512 (.5 vCPU)  
> 2048 (2 GB), 3072 (3 GB), 4096 (4 GB), 5120 (5 GB), 6144 (6 GB), 7168 (7 GB), 8192 (8 GB) - Available cpu values: 1024 (1 vCPU)  
> Between 4096 (4 GB) and 16384 (16 GB) in increments of 1024 (1 GB) - Available cpu values: 2048 (2 vCPU)  
> Between 8192 (8 GB) and 30720 (30 GB) in increments of 1024 (1 GB) - Available cpu values: 4096 (4 vCPU)  
