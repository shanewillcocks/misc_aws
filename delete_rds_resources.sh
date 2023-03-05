#------------------------------------------
# Delete AWS RDS databases and snapshots
#------------------------------------------
# Octopus only
#export AWS_ACCESS_KEY_ID=#{AWS_Account.AccessKey}
#export AWS_SECRET_ACCESS_KEY=#{AWS_Account.SecretKey}
#export AWS_REGION=#{AWS_Region}

# This function is for testing only - can be removed later
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

# This is not required, just delete the RDS instances
# Delete all snapshots for any RDS instances returned from AWS
delete_rds_snapshots () {
  rds_snapshots=$(aws rds describe-db-snapshots --filters "Name=db-instance-id,Values=${rds_id}" | jq '.DBSnapshots')
  rds_snapshot_count=$(echo ${rds_snapshots} | jq length)
  for ((count=0; count < ${rds_snapshot_count}; ++count))
  do
    snapshot_name=$(echo $rds_snapshots | jq ".[$count].DBSnapshotIdentifier" | sed 's/\"//g')
    snapshot_date=$(echo $rds_snapshots | jq ".[$count].SnapshotCreateTime" | sed 's/\"//g')
    echo "${count}. Deleting snapshot ${snapshot_name} created ${snaphost_date}"
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

# Delete all RDS instances returned from AWS
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

wait_for_delete () {
  for rds_id in ${db_identifiers} 
  do
    echo "Waiting for instance ${rds_id} to delete"
    while (true)
    do
      sleep 30
      db_status=$(aws rds describe-db-instances --db-instance-identifier ${rds_id} --query 'DBInstances[*].DBInstanceStatus' --output text) >>/dev/null 2>&1
      rc=$?
      # AWS returns code 254 when the database is not found, so break the loop as deletion is complete 
      if [ ${rc} -eq 254 ]; then
        echo "Delete complete for database ${rds_id}"
        break
      elif [ ${rc} -eq 0 ]; then
        echo "Status for instance ${rds_id} is ${db_status}, wait for 30 seconds..."
      fi
    done 
  done 
}

echo -e "\nGetting RDS identifiers from AWS"
db_identifiers=$(aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier' --output text)

for rds_id in ${db_identifiers}
do
  echo "Checking RDS instance ${rds_id}"
#  get_rds_snapshots
#  delete_rds_snapshots
  delete_rds_instances
done

for rds_id in ${db_identifiers}
do
  wait_for_delete
done
