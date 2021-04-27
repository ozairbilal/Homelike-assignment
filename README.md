#About Project
- I have segregated the stacks based on the requirements, VPC is in foundation stack which is reused in all projects.
- ALB, CLB and DB are in projects folder.
- ```deploy.sh``` does all the magic, checks:
    - If stack exists
    - Creates change set
    - Creates new stack 
    - Checks drift in stack.
- ```ssh_keys.sh``` generates the keys and saves in ```.tmp``` folder.

#Prerequisites 
- aws cli installed 
- aws profile set to ```default```

#How it works
- Simple execute the command ```.bin/StandardAccounts.sh``` and check status of all in console
  
#ssh files
- ssh files are generated and saved in .tmp folder
## Additional Resources
- [Standard Accounts](.bin/StandardAccounts.sh)
