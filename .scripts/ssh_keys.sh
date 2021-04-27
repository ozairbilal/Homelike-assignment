#!/bin/bash

DIR=$(realpath "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/../");

while getopts l:n:a: OPTION
  do
    case "${OPTION}"
      in
        l) KEY_LOCAL_NAME=${OPTARG};;
        n) KEY_NAME=${OPTARG};;
        a) AWS_PROFILE=${OPTARG};;
    esac
done

if [ -z "${KEY_NAME}" ]
  then
    echo
    echo "SSH Key Generation Script."
    echo
    echo "Syntax:"
    echo "./ssh_keys.sh -l key_local_name -n my_key_name -a aws_profile"
    echo
    exit 1
fi


KEY_PATH="${DIR}/.tmp/${KEY_LOCAL_NAME}.pem"

echo "The new stack. Check keys."

if aws --profile="${AWS_PROFILE}" --region eu-central-1 ec2 describe-key-pairs --key-names="${KEY_NAME}" 2>/dev/null | jq -r .KeyPairs[0].KeyName | grep -q "${KEY_NAME}"
  then
    echo "The key \"${KEY_NAME}\" already exists on AWS. Skipping key import to AWS."
    exit 1
fi
if test -s "${KEY_PATH}"
  then
    echo "The key file \"${KEY_LOCAL_NAME}.pem\" already exists. Skipping key generation."
    exit 1
fi

echo "Generate the new keys pair."
ssh-keygen -f "${KEY_PATH}" -N "" -q || exit 1

echo -n "Import the key \"${KEY_NAME}\": "
aws --profile="${AWS_PROFILE}" --region eu-central-1 ec2 import-key-pair --key-name="${KEY_NAME}" --public-key-material="`cat ${KEY_PATH}.pub`" | jq -r ".KeyName"

chmod 600 "${KEY_PATH}"

varSSHPrivateKey=`cat "${KEY_PATH}" | base64 -w 0`
varSSHPublicKey=`cat "${KEY_PATH}.pub" | base64 -w 0`
