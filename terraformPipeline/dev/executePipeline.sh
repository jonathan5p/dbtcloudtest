#!/bin/bash

SITE=$1
ENV=$2
TERRAFORM_WORKSPACE=${SITE}_${ENV}

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

set -e
echo -e "${GREEN}terraform worksapce is ${BLUE}${TERRAFORM_WORKSPACE}${NC}"
echo -e "${GREEN}Codepipeline Site is ${BLUE}${SITE}${NC}"
echo -e "${GREEN}Codepipeline ENV is ${BLUE}${ENV}${NC}"

terraform init -upgrade
#terraform init -reconfigure
terraform workspace select $TERRAFORM_WORKSPACE || terraform workspace new $TERRAFORM_WORKSPACE

export TF_VAR_site=$SITE
terraform plan -out="plan.tfplan" --var-file=${ENV}.tfvars

deploy_terraform()
{
echo -e "${GREEN}Executing terraform apply${NC}"
terraform apply "plan.tfplan"
exit
}


PS3='After verifying terraform plan, Please select Apply or Quit to proceed further:'
LIST="Apply Quit"
select i in $LIST
                do
                if [ $i = "Apply" ]
                then
                        deploy_terraform

                elif [ $i = "Quit" ]
                then
                        exit
		    fi
done