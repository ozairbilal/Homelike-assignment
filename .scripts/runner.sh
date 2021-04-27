#!/bin/bash
input=$1
while IFS= read -r line
do
  type=$(echo $line | cut -f1 -d~)
  key=$(echo $line | cut -f2 -d~)
  value=$(echo $line | cut -f3 -d~)

  aws ssm put-parameter --profile devops.qa --name "$key" --type "String"  --value "$value" --overwrite
#  aws ssm delete-parameter --profile devops.qa --name "$key"
done < "$input"


#input=$2
#while IFS= read -r line
#do
#  type=$(echo $line | cut -f1 -d~)
#  key=$(echo $line | cut -f2 -d~)
#  value=$(echo $line | cut -f3 -d~)
#
#  aws secretsmanager update-secret --profile devops.qa --secret-id "$key" --secret-string "$value"
#
#done < "$input"
