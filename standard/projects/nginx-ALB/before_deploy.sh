#!/bin/bash


while getopts a:e:s: OPTION
  do
    case "${OPTION}"
      in
        a) AWS_PROFILE=${OPTARG};;
        e) ENV=${OPTARG};;
        s) STACK_NAME=${OPTARG};;
    esac
done

if [ -z "${AWS_PROFILE}" ]
  then
    echo "Syntax Error:"
    echo "./before_deploy.sh -a aws_profile -e ENVIRONMENT_NAME -s STACK_NAME"
    echo
    exit 1
fi

DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../../../");

KEY_NAME="${AWS_PROFILE}-${ENV}-${STACK_NAME}"

${DIR}/.scripts/ssh_keys.sh -l ${KEY_NAME} -n $varSSHKey -a ${AWS_PROFILE}
