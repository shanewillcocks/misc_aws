#/bin/bash
#---------------------------------------------------------------
# Function to delete AMI transporter products provisioned via
# the AWS Service Catalog
# Set ami_transporter_id to correct Service Catalog ID
#---------------------------------------------------------------
delete_provisioned_products () {
  epoch_ts=$(date +'%s')
  # Only delete provisioned AMI Transporter products
  ami_transporter_id=prod-ss2uoc263tvt6
  delete_count=0

  provisioned_products=$(aws servicecatalog scan-provisioned-products | jq '.ProvisionedProducts')
  product_count=$(echo ${provisioned_products} | jq length)
  echo "Checking ${product_count} provisioned products"
  for ((count=0; count < ${product_count}; ++count)); do
    product_id=$(echo ${provisioned_products} | jq -r ".[$count].ProductId")
    if [ "${product_id}" == "${ami_transporter_id}" ]; then
      creation_time=$(echo ${provisioned_products} | jq ".[$count].CreatedTime" | sed 's/\"//g')
      prov_product_name=$(echo ${provisioned_products} | jq ".[$count].Name")
      prov_product_id=$(echo ${provisioned_products} | jq ".[$count].Id")
      product_ts=$(date -d "${creation_time}" +%s)
      echo "Checking provisioned AMI Transporter product ${prov_product_name}"
      delta=$((${epoch_ts} - ${product_ts}))
      if [ ${delta} -gt 2592000 ]; then
        echo "Provisioned product ${prov_product_name} is older than 30 days, deleting"
        aws servicecatalog terminate-provisioned-product --provisioned-product-name ${product_name} >/dev/null 2>&1
        if [ ${rc} -eq 0 ]; then
          echo "Delete initiated successfully"
        delete_count=$((delete_count+1))
        else
          echo "Delete failed to initiate: ${rc}"
        fi
      else
         echo "Ignoring provisioned AMI Transporter ${prov_product_name}, not older than 30 days"
      fi
      sleep 1
    fi
  done
  echo "Deleted ${delete_count} provisioned products"
}

delete_provisioned_products
