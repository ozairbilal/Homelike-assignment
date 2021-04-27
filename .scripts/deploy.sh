#!/bin/bash
DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../");

# Deploy / Update the stage

# Get input parameters
while getopts a:p:s:r: OPTION
  do
    case "${OPTION}"
      in
        a) AWS_PROFILE=${OPTARG};;
        p) STACK_PATH=${OPTARG};;
        s) STACK_NAME=${OPTARG};;
        r) REGION=${OPTARG};;
    esac
done

if [ -z "${AWS_PROFILE}" ] || [ -z "${STACK_PATH}" ] || [ -z "${STACK_NAME}" ]
  then
    echo
    echo "Deploy the stack template to create or update the CloudFormation stack."
    echo
    echo "Syntax:"
    echo "./deploy.sh -a AWS_PROFILE_NAME -p STACK_PATH -s STACK_NAME"
    echo
    exit 1
fi

if [ -z "${REGION}" ]
then
  REGION=$(aws configure --profile="${AWS_PROFILE}" get region)
fi
# Auto-export variables
set -a

PATH="/usr/local/bin:${PATH}" # use /usr/local/bin/aws if exist
ZONE_ID=""
CERT_ID=""
NAT_IP=""
PARAMETERS_DEPLOY=""
PARAMETERS_UPDATE=""

ACCOUNT_PARAMETER_FILE_PATH="${DIR}/account.ini"

### Validation
echo -e "\e[40m\e[96mIdentity Information:"
CALLER_ID=$(aws --profile="${AWS_PROFILE}" sts get-caller-identity )
ACCOUNT_ID=$(echo ${CALLER_ID} | jq -r '.Account' )
echo ${CALLER_ID}
echo

if [ ! -s ${ACCOUNT_PARAMETER_FILE_PATH} ]
  then
    echo -e "\e[31mThe file ${ACCOUNT_PARAMETER_FILE_PATH} does not exist or empty"
    echo -e '\e[39m'
    exit 1
fi

ENV=$(awk -F= -v key="${ACCOUNT_ID}" '$1==key {print $2}' ${ACCOUNT_PARAMETER_FILE_PATH})

if [ -z "${ENV}" ]
  then
    echo -e "\e[31mThe Account ID Doesn't Exists"
    echo -e '\e[39m'
    exit 1
fi
echo "STAGE: ${ENV}"
echo "Stack Name: ${STACK_NAME}"
echo "Region: ${REGION}"
echo -e '\e[39m\e[49m'
echo
echo "Press Ctrl+C to abort this deployment."
echo "Press any key to continue."
read
echo "Export a project variables..."

ENV_PARAMETER_FILE_PATH="${DIR}/${STACK_PATH}/${STACK_NAME}/parameters/${ENV}.ini"
COMMON_PARAMETER_FILE_PATH="${DIR}/${STACK_PATH}/${STACK_NAME}/parameters/common.ini"
TEMPLATE_FILE_PATH="${DIR}/${STACK_PATH}/${STACK_NAME}/template.yaml"
BEFORE_DEPLOY_FILE_PATH="${DIR}/${STACK_PATH}/${STACK_NAME}/before_deploy.sh"
BEFORE_DEPLOY_SCRIPT="${BEFORE_DEPLOY_FILE_PATH} -a ${AWS_PROFILE} -e ${ENV} -s ${STACK_NAME} -r ${REGION}"
AFTER_DEPLOY_FILE_PATH="${DIR}/${STACK_PATH}/${STACK_NAME}/after_deploy.sh"
AFTER_DEPLOY_SCRIPT="${AFTER_DEPLOY_FILE_PATH} -a ${AWS_PROFILE} -e ${ENV} -s ${STACK_NAME} -r ${REGION}"
# if aws --profile="${AWS_PROFILE}" ec2 describe-instances 2>&1 | grep -q InstanceId
#   then
#     echo
#     echo "WARNING!"
#     echo "The AWS profile \"${AWS_PROFILE}\" is NOT EMPTY."
#     echo "Press Ctrl+C to abort this deployment."
#     echo "Press any key to continue."
#     read
# fi

if [ ! -s ${TEMPLATE_FILE_PATH} ]
  then
    echo "The file ${TEMPLATE_FILE_PATH} does not exist or empty"
    exit 1
fi

echo "Export a project variables..."

for VAR in `env | grep -E "^var"`
  do
    unset ${VAR}
  done

if [ -f ${COMMON_PARAMETER_FILE_PATH} ]
  then
    echo "Reading common parameters INI file"
    . ${COMMON_PARAMETER_FILE_PATH}
fi

if [ -f ${ENV_PARAMETER_FILE_PATH} ]
  then
    echo "Reading environment parameters INI file"
    . ${ENV_PARAMETER_FILE_PATH}
fi

echo "Variable import complete"


if [ -s ${BEFORE_DEPLOY_FILE_PATH} ]
  then
    echo "Run the before deploy script..."
    . ${BEFORE_DEPLOY_SCRIPT}
fi

echo "Create variables list..."
for VAR in `env | grep -E "^var"`
  do

    ParamValue=$(echo ${VAR} | sed 's/^[[:alnum:]]*=//')
    ParamName=$(echo ${VAR} | cut -f 1 -d '=')

    if [ -z ${ParamValue} ]; then
      echo
      echo
      echo "Error: Parameter ${ParamName} has an empty value. Aborting...";
      echo
      exit 1
    fi

    PARAMETERS_DEPLOY="${PARAMETERS_DEPLOY} ${VAR}"``
    PARAMETERS_UPDATE="${PARAMETERS_UPDATE} ParameterKey=\"${ParamName}\",ParameterValue=\"${ParamValue}\""
  done
## IF Stack Already Exists create a change-set
if aws --profile="${AWS_PROFILE}" --region="${REGION}" cloudformation describe-stacks --stack-name="${STACK_NAME}" 2>/dev/null | jq -r '.Stacks[0].StackStatus' | grep -qE "(CREATE|UPDATE|UPDATE_ROLLBACK)_COMPLETE|DELETE_FAILED"
  then
    echo "${PARAMETERS_UPDATE}" | tr ' ' '\n' | sort
    echo
    echo "Create the change set..."
    echo "file://${TEMPLATE_FILE_PATH}"
    COMMAND="\
    aws --profile=\"${AWS_PROFILE}\" cloudformation create-change-set \
        --stack-name=\"${STACK_NAME}\" \
        --region=\"${REGION}\" \
        --change-set-name=\"${STACK_NAME}-`date +\\\"%Y%m%d%H%M%S\\\"`\" \
        --template-body=\"file://${TEMPLATE_FILE_PATH}\" \
        --capabilities=\"CAPABILITY_IAM\" \
        --capabilities=\"CAPABILITY_NAMED_IAM\" \
    "
    if [ ! -z "${PARAMETERS_UPDATE}" ]
    then
      COMMAND="${COMMAND} --parameters ${PARAMETERS_UPDATE}"
    fi
    COMMAND="${COMMAND} | jq -r \".Id\" "
    CHANGESET_ARN=$(eval ${COMMAND})

    echo -e "\e[33mWait for changeset creation to complete..."
    echo -e "\e[39m"
    aws --profile="${AWS_PROFILE}" --region="${REGION}" \
      cloudformation wait change-set-create-complete \
      --stack-name "${STACK_NAME}" \
      --change-set-name ${CHANGESET_ARN}

    echo
    echo "Done. Changeset created with ARN: ${CHANGESET_ARN}"

    CHANGES=$(aws --profile="${AWS_PROFILE}" --region="${REGION}" cloudformation describe-change-set --change-set-name ${CHANGESET_ARN})
    NO_CHANGE_SET=$( echo ${CHANGES} | jq -r ".StatusReason" | grep -i "The submitted information didn't contain changes.")
    echo ${NO_CHANGE_SET}
    if [ ! -z "${NO_CHANGE_SET}" ]
    then
      echo -e "\e[31mNo Changes Found. Deleting changeset..."
      aws --profile="${AWS_PROFILE}" --region="${REGION}" cloudformation delete-change-set --change-set-name ${CHANGESET_ARN}
      echo -e "Changeset was deleted."
      echo -e '\e[39m'
    else
      echo -e "\e[32mValid Changeset contains changes."

      STACK_ID=$(echo ${CHANGES} | jq -r '.StackId')

      echo -e "\e[32mChanges:"
      echo ${CHANGES} | jq -r '.Changes'
      echo
      URL="https://${REGION}.console.aws.amazon.com/cloudformation/home?region=${REGION}#/stacks/changesets/changes?stackId=${STACK_ID}&changeSetId=${CHANGESET_ARN}"
      echo -e "\e[32mURL: \e[34m${URL}"
      echo -e '\e[39m'
    fi
    echo -e "\e[32mChecking the drift in stack  \"${STACK_NAME}\" ..."
    aws cloudformation detect-stack-drift \
     --stack-name=${STACK_NAME} --profile="${AWS_PROFILE}"

    echo -e "\e[32mDescribing the drift in stack  \"${STACK_NAME}\" ..."
    DRIFT=$(aws cloudformation describe-stack-resource-drifts \
    --stack-name=${STACK_NAME} --profile="${AWS_PROFILE}" \
    --stack-resource-drift-status-filters "MODIFIED" "DELETED" "NOT_CHECKED")
    NO_DRIFT=$( echo ${DRIFT} | jq -r ".StackResourceDrifts" | grep  "\[]")
    if [ ! -z "${NO_DRIFT}" ]
    then
      echo -e "\e[31mNo Drift Found"
    else
      echo -e "\e[31mDRIFT: \"${DRIFT}\" ..."
    fi
    echo -e "\e[32mDescribing the Vulnerabilities in  \"${STACK_NAME}\" ..."
    cfn_nag_scan --input-path ${TEMPLATE_FILE_PATH}
  #  exit 0
#fi

elif aws --profile="${AWS_PROFILE}" --region="${REGION}" cloudformation describe-stacks --stack-name=${STACK_NAME} 2>/dev/null | jq -r '.Stacks[0].StackStatus' | grep -q "_"
  then
    echo
    echo "The stack already exists!"
   # exit 0
#fi

else
  echo "${PARAMETERS_DEPLOY}" | tr ' ' '\n' | sort
  echo
  echo "Deploy the template..."

  COMMAND="
  aws --profile=\"${AWS_PROFILE}\" cloudformation deploy \
  --stack-name=\"${STACK_NAME}\" \
  --region=\"${REGION}\" \
  --template-file=\"${TEMPLATE_FILE_PATH}\" \
  --capabilities=\"CAPABILITY_IAM\" \
  --capabilities=\"CAPABILITY_NAMED_IAM\" \
  "
  if [ ! -z "${PARAMETERS_DEPLOY}" ]
  then
    echo "No parameters provided, skipping"
    COMMAND="${COMMAND} --parameter-overrides ${PARAMETERS_DEPLOY} "
  fi
  COMMAND="${COMMAND} & sleep 30"
  eval ${COMMAND}
  echo

  if [ -s ${AFTER_DEPLOY_FILE_PATH} ]
    then
      echo "Run the after_deploy script..."
      . ${AFTER_DEPLOY_SCRIPT}
  fi

  echo "Waiting for the stack \"${STACK_NAME}\" to be created..."
  if aws --profile="${AWS_PROFILE}" cloudformation wait stack-create-complete --stack-name="${STACK_NAME}"
    then
      echo "Enable terminate protection for the stack \"${STACK_NAME}\""
      aws --profile="${AWS_PROFILE}" cloudformation update-termination-protection \
          --enable-termination-protection \
          --stack-name=${STACK_NAME} >/dev/null
  fi
fi

