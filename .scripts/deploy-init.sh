#!/bin/bash

# Deploy / Update the Init stage

# Get input parameters
while getopts a:t:e: OPTION
  do
    case "${OPTION}"
      in
        a) AWS_PROFILE=${OPTARG};;
        t) TYPE=${OPTARG};;
        e) ENV=${OPTARG};;
    esac
done

if [ -z "${AWS_PROFILE}" ] || [ -z "${TYPE}" ] || [ -z "${ENV}" ]
  then
    echo
    echo "Deploy the Init template to create or update the CloudFormation stack."
    echo
    echo "Usage example:"
    echo "./deploy-init.sh -a AWS_PROFILE_NAME -t ENVIRONMENT_TYPE -e ENVIRONMENT_NAME"
    echo
    echo "Environment types:"
    echo "standard - EC2 and ECS projects"
    echo "serverless - Lambda projects"
    echo
    echo "Environment names:"
    echo "staging - the Staging environment"
    echo "production - the Production environment"
    exit 1
fi

# Auto-export variables
set -a

PATH="/usr/local/bin:${PATH}" # use /usr/local/bin/aws if exist
ZONE_ID=""
CERT_ID=""
NAT_IP=""
PARAMETERS_DEPLOY=""
PARAMETERS_UPDATE=""

if aws --profile="${AWS_PROFILE}" ec2 describe-instances 2>&1 | grep -q InstanceId
  then
    echo
    echo "WARNING!"
    echo "The AWS profile \"${AWS_PROFILE}\" is NOT EMPTY."
    echo "Press Ctrl+C to abort this deployment."
    echo "Press any key to continue."
    read
fi

if [ ! -s "../${TYPE}/init/parameters/${ENV}.ini" ]
  then
    echo "The file ../${TYPE}/init/parameters/${ENV}.ini does not exist or empty"
    exit 1
fi
if [ ! -s "../${TYPE}/init/template.yaml" ]
  then
    echo "The file ../${TYPE}/init/template.yaml does not exist or empty"
    exit 1
fi

echo "Export a project variables..."
for VAR in `env | grep -E "^var"`
  do
    unset ${VAR}
  done
. ../${TYPE}/init/parameters/${ENV}.ini
varEnvironment="${ENV}"


if [ -s "../${TYPE}/init/scripts/before_deploy.sh" ]
  then
    echo "Run the before deploy script..."
    . "../${TYPE}/init/scripts/before_deploy.sh"
fi

echo "Create variables list..."
for VAR in `env | grep -E "^var"`
  do
    PARAMETERS_DEPLOY="${PARAMETERS_DEPLOY} ${VAR}"
    PARAMETERS_UPDATE="${PARAMETERS_UPDATE} ParameterKey=\"`echo -n ${VAR} | cut -f 1 -d '='`\",ParameterValue=\"`echo -n ${VAR} | sed 's/^[[:alnum:]]*=//'`\""
  done

if aws --profile="${AWS_PROFILE}" cloudformation describe-stacks --stack-name="init-stack" 2>/dev/null | jq -r '.Stacks[0].StackStatus' | grep -qE "(CREATE|UPDATE)_COMPLETE"
  then
    echo "${PARAMETERS_UPDATE}" | tr ' ' '\n' | sort
    echo
    echo "Create the change set..."
    aws --profile="${AWS_PROFILE}" cloudformation create-change-set \
        --stack-name="init-stack" \
        --change-set-name="init-stack-`date +\"%Y%m%d%H%M%S\"`" \
        --template-body="file://../${TYPE}/init/template.yaml" \
        --capabilities="CAPABILITY_IAM" \
        --capabilities="CAPABILITY_NAMED_IAM" \
        --parameters ${PARAMETERS_UPDATE} | jq -r ".Id"
    echo
    echo "Done."
    exit 0
fi

if aws --profile="${AWS_PROFILE}" cloudformation describe-stacks --stack-name="init-stack" 2>/dev/null | jq -r '.Stacks[0].StackStatus' | grep -q "_"
  then
    echo
    echo "The stack is already exist!"
    exit 0
fi

echo "${PARAMETERS_DEPLOY}" | tr ' ' '\n' | sort
echo
echo "Deploy the template..."
aws --profile="${AWS_PROFILE}" cloudformation deploy \
    --stack-name="init-stack" \
    --template-file="../${TYPE}/init/template.yaml" \
    --capabilities="CAPABILITY_IAM" \
    --capabilities="CAPABILITY_NAMED_IAM" \
    --parameter-overrides ${PARAMETERS_DEPLOY} &
sleep 30
echo

if [ -s "../${TYPE}/init/scripts/after_deploy.sh" ]
  then
    echo "Run the after_deploy script..."
    . "../${TYPE}/init/scripts/after_deploy.sh"
fi

echo "Waiting for the stack \"init-stack\" is created..."
if aws --profile="${AWS_PROFILE}" cloudformation wait stack-create-complete --stack-name="init-stack"
  then
    echo "Enable terminate protection for the stack \"init-stack\""
    aws --profile="${AWS_PROFILE}" cloudformation update-termination-protection \
        --enable-termination-protection \
        --stack-name="init-stack" >/dev/null
fi

echo "Done."
