#!/bin/bash

# Deploy / Update the Project stage

# Get input parameters
while getopts a:t:e:p: OPTION
  do
    case "${OPTION}"
      in
        a) AWS_PROFILE=${OPTARG};;
        t) TYPE=${OPTARG};;
        p) PROJECT_NAME=${OPTARG};;
        e) ENV=${OPTARG};;
    esac
done

if [ -z "${AWS_PROFILE}" ] || [ -z "${TYPE}" ] || [ -z "${PROJECT_NAME}" ] || [ -z "${ENV}" ]
  then
    echo
    echo "Deploy the Init template to create or update the CloudFormation stack."
    echo
    echo "Usage example:"
    echo "./deploy-project.sh -a AWS_PROFILE_NAME -t ENVIRONMENT_TYPE -p PROJECT_NAME -e ENVIRONMENT_NAME"
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
PARAMETERS_DEPLOY=""
PARAMETERS_UPDATE=""

if [ ! -s "../${TYPE}/projects/${PROJECT_NAME}/parameters/${ENV}.ini" ]
  then
    echo "The file ../${TYPE}/projects/${PROJECT_NAME}/parameters/${ENV}.ini does not exist or empty"
    exit 1
fi
if [ ! -s "../${TYPE}/projects/${PROJECT_NAME}/template.yaml" ]
  then
    echo "The file ../${TYPE}/projects/${PROJECT_NAME}/template.yaml does not exist or empty"
    exit 1
fi

echo "Export a project variables..."
for VAR in `env | grep -E "^var"`
  do
    unset ${VAR}
  done
. ../${TYPE}/projects/${PROJECT_NAME}/parameters/${ENV}.ini
echo


if [ -s "../${TYPE}/projects/${PROJECT_NAME}/scripts/before_deploy.sh" ]
  then
    echo "Run the before deploy script..."
    . "../${TYPE}/projects/${PROJECT_NAME}/scripts/before_deploy.sh"
fi

echo "Create variables list..."
for VAR in `env | grep -E "^var"`
  do
    PARAMETERS_DEPLOY="${PARAMETERS_DEPLOY} ${VAR}"
    PARAMETERS_UPDATE="${PARAMETERS_UPDATE} ParameterKey=\"`echo -n ${VAR} | cut -f 1 -d '='`\",ParameterValue=\"`echo -n ${VAR} | sed 's/^[[:alnum:]]*=//'`\""
  done

if [ ! -z "`aws --profile=${AWS_PROFILE} cloudformation describe-stacks --stack-name=${PROJECT_NAME}-stack 2>/dev/null | jq -r '.Stacks[0].StackStatus'`" ]
  then
    echo "${PARAMETERS_UPDATE}" | tr ' ' '\n' | sort
    echo
    echo "Create the change set..."
    aws --profile="${AWS_PROFILE}" cloudformation create-change-set \
        --stack-name="${PROJECT_NAME}-stack" \
        --change-set-name="${PROJECT_NAME}-stack-`date +\"%Y%m%d%H%M%S\"`" \
        --template-body="file://../${TYPE}/projects/${PROJECT_NAME}/template.yaml" \
        --capabilities="CAPABILITY_IAM" \
        --capabilities="CAPABILITY_NAMED_IAM" \
        --parameters ${PARAMETERS_UPDATE} | jq -r ".Id"
    echo
    echo "Done."
    exit 0
fi

echo "${PARAMETERS_DEPLOY}" | tr ' ' '\n' | sort
echo
echo "Deploy the template..."
if aws --profile="${AWS_PROFILE}" cloudformation deploy \
    --stack-name="${PROJECT_NAME}-stack" \
    --template-file="../${TYPE}/projects/${PROJECT_NAME}/template.yaml" \
    --capabilities="CAPABILITY_IAM" \
    --capabilities="CAPABILITY_NAMED_IAM" \
    --parameter-overrides ${PARAMETERS_DEPLOY}
  then
    echo

    if [ -s "../${TYPE}/projects/${PROJECT_NAME}/scripts/after_deploy.sh" ]
      then
        echo "Run the after deploy script..."
        . "../${TYPE}/projects/${PROJECT_NAME}/scripts/after_deploy.sh"
    fi

    echo "Enable terminate protection for the stack \"${PROJECT_NAME}-stack\""
    aws --profile="${AWS_PROFILE}" cloudformation update-termination-protection \
        --enable-termination-protection \
        --stack-name="${PROJECT_NAME}-stack" >/dev/null

fi

echo "Done."
