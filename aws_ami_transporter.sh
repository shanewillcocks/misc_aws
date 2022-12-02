#-------------------------------------------------------
# Use the AMI-Transporter from the Service Catalog
# to migrate the latest RHEL8 AMI from Dev to Prod
#-------------------------------------------------------
# Add a datestamp to the AMI prefix in Prod LZ for uniqueness
datestamp=$(date '+%d%m%Y')
# Product Name is the name we allocate to this instance of the provisioned AMI-Transporter
product_name=AAP-RHEL8-AMI-Transporter-${datestamp}
dev_aws_id=$(get_octopusvariable "dev_aws_id")
target_acct=$(get_octopusvariable "target_acct")
key_arn=ebscmk_arn

# Get the latest RHEL8 AMI ID
rhel8_latest_ami=$(aws ec2 describe-images --owner ${dev_aws_id} --filters "Name=name,Values=BNZ-RHEL8-stable*" --query 'reverse(sort_by(Images, &CreationDate))[0]' | jq -r '.ImageId')
# Get the Product ID from the AWS Service Catalog
product_id=$(aws servicecatalog search-products --query "ProductViewSummaries[?Name=='AMI Transporter'].[ProductId]" --output text)
# Get the latest Provisioning artefact ID (this is the version in the Service Catalog)
version=$(aws servicecatalog list-provisioning-artifacts --product-id ${product_id} | jq -r '.ProvisioningArtifactDetails[].Id')

# Push the AMI to AWS Prod
aws servicecatalog provision-product --provisioned-product-name ${product_name} --product-id ${product_id} \
--provisioning-artifact-id ${version} \
--provisioning-parameters Key=CopyPrefix,Value=AAP-${datestamp} Key=AMIId,Value=${rhel8_latest_ami} Key=TargetAccountId,Value=${target_acct} Key=SSMParameterName,Value=${key_arn}
rc=$?
if [ ${rc} -eq 0 ]; then
  echo "AMI Transport to Prod successful"
else
  echo "AMI Transprt to Prod failed: ${rc}"
fi
