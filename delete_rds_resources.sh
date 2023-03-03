#------------------------------------------
# Delete AWS RDS databases and snapshots
#------------------------------------------
# Octopus only
#export AWS_ACCESS_KEY_ID=#{AWS_Account.AccessKey}
#export AWS_SECRET_ACCESS_KEY=#{AWS_Account.SecretKey}
#export AWS_REGION=#{AWS_Region}

# Remove this after testing
get_rds_snapshots () {
  rds_snapshots=$(aws rds describe-db-snapshots --filters "Name=db-instance-id,Values=${rds_id}" | jq '.DBSnapshots')
  rds_snapshot_count=$(echo ${rds_snapshots} | jq length)
  echo "Found ${rds_snapshot_count} RDS snapshots:"
  for ((count=0; count < ${rds_snapshot_count}; ++count))
  do
    snapshot_name=$(echo $rds_snapshots | jq ".[$count].DBSnapshotIdentifier" | sed 's/\"//g')
    snapshot_date=$(echo $rds_snapshots | jq ".[$count].SnapshotCreateTime" | sed 's/\"//g')
    echo "${count}. ${snapshot_name} created ${snapshot_date}"
  done
}

delete_rds_instances () {
  echo "Deleting RDS instance ${rds_id}"
  aws rds delete-db-instance --db-instance-identifier ${rds_id} --skip-final-snapshot --delete-automated-backups
  #aws rds delete-db-instance --db-instance-identifier ${rds_id} --skip-final-snapshot --delete-automated-backups >/dev/null 2>&1
  rc=$?
  if [ ${rc} -eq 0 ]; then
    echo "RDS instance ${rds_id} deleted"
  else
    echo "Deleting RDS instance ${rds_id} may have failed, returned code: ${rc}"
  fi
}

delete_rds_snapshots () {
  rds_snapshots=$(aws rds describe-db-snapshots --filters "Name=db-instance-id,Values=${rds_id}" | jq '.DBSnapshots')
  rds_snapshot_count=$(echo ${rds_snapshots} | jq length)
  for ((count=0; count < ${rds_snapshot_count}; ++count))
  do
    snapshot_name=$(echo $rds_snapshots | jq ".[$count].DBSnapshotIdentifier" | sed 's/\"//g')
    snapshot_date=$(echo $rds_snapshots | jq ".[$count].SnapshotCreateTime" | sed 's/\"//g')
    echo "Deleting snapshot ${snapshot_name} created ${snaphost_date}"
    aws rds delete-db-snapshot --db-snapshot-identifier ${snapshot_name}
    #aws rds delete-db-snapshot --db-snapshot-identifier ${snapshot_name} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
    else
      echo "Deleting snapshot may have failed, return code: ${rc}"
    fi
    sleep 1
  done
}

echo -e "\nGetting RDS identifiers from AWS"
db_identifiers=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output text)

for rds_id in ${db_identifiers}
do
  echo "Checking RDS instance ${rds_id}"
  get_rds_snapshots
  #delete_rds_snapshots
  #delete_rds_instances
done
