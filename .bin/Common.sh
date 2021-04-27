#!/bin/bash

# get the current directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )";
cd ${DIR}/../.scripts

# Common Accounts
# This include CFN template which is generic and used by all other accounts like standard and devtools
# This is called by all account scripts as a first step

## Foundation
# set -x
./deploy.sh -a default -p common/foundation -s network -r eu-central-1




