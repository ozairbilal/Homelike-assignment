#!/bin/bash
# get the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";


# Get input parameters
while getopts a: OPTION
  do
    case "${OPTION}"
      in
        a) PROFILE=${OPTARG};;
    esac
done

# run common scripts
./Common.sh ${PROFILE}
cd ${DIR}/../.scripts
# ## Projects

./deploy.sh -a default -p standard/projects -s nginx-ALB -r eu-central-1
./deploy.sh -a default -p standard/projects -s node-CLB -r eu-central-1
./deploy.sh -a default -p standard/projects -s mongo-RDS -r eu-central-1
./deploy.sh -a default -p standard/projects -s vpn-instance -r eu-central-1



###### ECS


