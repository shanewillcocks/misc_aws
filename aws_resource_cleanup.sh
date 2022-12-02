#!/bin/bash
#-----------------------------------------
# Clean Up AWS Resources:
# 1. Available EBS Volumes
# 2. RDS Snapshots older than 33 days
# 3. Packer AMI's older than 7 days
# 4. Temporary Packer Security Groups
# 5. Backup vault recovery points
# 6. EBS Snapshots
#-----------------------------------------
if [ $# -ne 2 ]; then
  echo "Usage: $0 <aws_account> <rds_id>"
  exit
fi

aws_id=$1
rds_id=$2
epoch_ts=$(date +'%s')
backup_vault="Backup-vault-daily"

delete_ebs_volumes () {
  ebs_volumes=$(aws ec2 describe-volumes --filters "Name=status,Values=available" --query 'Volumes[*].VolumeId' --output text)
  delete_count=0
  for volume in $ebs_volumes
  do
    echo "Deleting volume ${volume}"
    aws ec2 delete-volume --volume-id ${volume} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
      delete_count=$(($delete_count+1))
    else
      echo "Delete failed: ${rc}"
    fi
    sleep 1
  done
  echo "Deleted ${delete_count} EBS volumes"
}

# Only delete a snapshot if creation date is older than 33 days
delete_rds_snapshots () {
  rds_snapshots=$(aws rds describe-db-snapshots --filters "Name=db-instance-id,Values=${rds_id}"|jq '.DBSnapshots')
  rds_snapshot_count=$(echo ${rds_snapshots}|jq length)
  echo "Found ${rds_snapshot_count} RDS snapshots"
  delete_count=0
  for ((count=0; count < ${rds_snapshot_count}; ++count))
  do
    snapshot_name=$(echo $rds_snapshots|jq ".[$count].DBSnapshotIdentifier"|sed 's/\"//g')
    snapshot_date=$(echo $rds_snapshots|jq ".[$count].SnapshotCreateTime"|sed 's/\"//g')
    snapshot_ts=$(date -d "${snapshot_date}" +%s)
    delta=$((${epoch_ts} - ${snapshot_ts}))
    if [ ${delta} -gt 2851200 ]; then
       echo "Deleting snapshot ${snapshot_name}"
       aws rds delete-db-snapshot --db-snapshot-identifier ${snapshot_name} >/dev/null 2>&1
       rc=$?
       if [ ${rc} -eq 0 ]; then
         echo "Delete successful"
         delete_count=$(($delete_count+1))
       else
         echo "Delete failed: ${rc}"
       fi
       sleep 1
    fi
  done
  echo "Deleted ${delete_count} RDS snapshots"
}

# Only deregister an AMI if creation date is older than 7 days
deregister_packer_amis () {
  packer_amis=$(aws ec2 describe-images --filters "Name=owner-id,Values=${aws_id}" "Name=tag:Name,Values=Packer*"|jq '.Images')
  packer_ami_count=$(echo ${packer_amis}|jq length)
  dereg_count=0
  echo "Found ${packer_ami_count} AMIs"
  for ((count=0; count < ${packer_ami_count}; ++count))
  do
    ami_name=$(echo $packer_amis|jq ".[$count].ImageId"|sed 's/\"//g')
    ami_date=$(echo $packer_amis|jq ".[$count].CreationDate"|sed 's/\"//g')
    ami_ts=$(date -d "${ami_date}" +%s)
    delta=$((${epoch_ts} - ${ami_ts}))
    if [ ${delta} -gt 604800 ]; then
      echo "Deregistering AMI ${ami_name}"
      aws ec2 deregister-image --image-id ${ami_name} >/dev/null 2>&1
      rc=$?
      if [ ${rc} -eq 0 ]; then
        echo "Deregister successful"
        dereg_count=$(($dereg_count+1))
      else
        echo "Deregister failed: ${rc}"
      fi
      sleep 1
    fi
  done
  echo "Deregistered ${dereg_count} Packer AMIs"
}

delete_packer_security_groups () {
  security_groups=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=packer_*" --query 'SecurityGroups[*].GroupId' --output text)
  delete_count=0
  for packer_sg in $security_groups
  do
    echo "Deleting Packer security group ${packer_sg}"
    aws ec2 delete-security-group --group-id ${packer_sg} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
      delete_count=$(($delete_count+1))
    else
      echo "Delete failed: ${rc}"
    fi
    sleep 1
  done
  echo "Deleted ${delete_count} Packer security groups"
}

# This is needed to delete EBS snapshots created by AWS backup
delete_vault_recovery_points() {
  recovery_points=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name ${backup_vault} --query 'RecoveryPoints[*].RecoveryPointArn' --output text)
  delete_count=0
  for recovery_point in $recovery_points
  do
    echo "Deleting recovery point ${recovery_point}"
    aws backup delete-recovery-point --backup-vault-name ${backup_vault} --recovery-point-arn ${recovery_point} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
      delete_count=$(($delete_count+1))
    else
      echo "Delete failed: ${rc}"
    fi
    sleep 1
  done
  echo "Deleted ${delete_count} Vault recovery points"
}

# Snapshots can only be deleted if they are not associated with an existing AMI, so this needs to be run after deleting AMIs
delete_ebs_snapshots () {
  ebs_snapshots=$(aws ec2 describe-snapshots --filters "Name=owner-id,Values=${aws_id}" --query 'Snapshots[*].SnapshotId' --output text)
  delete_count=0
  for snapshot in $ebs_snapshots
  do
    echo "Deleting EBS snapshot ${snapshot}"
    aws ec2 delete-snapshot --snapshot-id ${snapshot} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
      delete_count=$(($delete_count+1))
    else
      echo "Delete failed: ${rc}"
    fi
    sleep 1
  done
  echo "Deleted ${delete_count} EBS snapshots"
}

delete_packer_keypairs () {
  packer_keypairs=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=packer*" --query 'KeyPairs[*].KeyName' --output text)
  delete_count=0
  for keypair in $packer_keypairs
  do
    echo "Deleting keypair ${keypair}"
    aws ec2 delete-key-pair --key-name ${keypair} >/dev/null 2>&1
    rc=$?
    if [ ${rc} -eq 0 ]; then
      echo "Delete successful"
      delete_count=$(($delete_count+1))
    else
      echo "Delete failed: ${rc}"
    fi
    sleep 1
  done
  echo "Deleted ${delete_count} Packer keypairs"
}

echo "1. Cleaning up available EBS volumes"
delete_ebs_volumes
echo "2. Cleaning up RDS snapshots older than 33 days"
delete_rds_snapshots
echo "3. Cleaning up temporary Packer security groups"
delete_packer_security_groups
echo "4. Cleaning up backup vault recovery points"
delete_vault_recovery_points
echo "5. Cleaning up Packer AMIs older than 7 days"
deregister_packer_amis
echo "6. Cleaning up orphaned EBS snapshots"
delete_ebs_snapshots
echo "7. Deleting Packer temporary keypairs"
delete_packer_keypairs
exit
