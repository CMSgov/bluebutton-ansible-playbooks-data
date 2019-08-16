#!/bin/bash

# Constants
# FIXME figure out DB name/verify username
dbname= "DATABASE_NAME"
username= "postgres"
databaseQueries= "/bluebutton-ansible-playbooks-data/dev/database-queries.txt"

# select random sample of Beneficiaries.beneficiaryId
numBenesToQuery= 1000
randomBeneIds= `psql -U $username -d $dbname -c "SELECT beneficiaryId FROM Beneficiaries ORDER BY RANDOM() LIMIT $numBenesToQuery"`

# set queries to timeout after 15 seconds
setTimeout() {
	psql -U $username -d $dbname -c "SET statement_timeout TO 15000"
}

# check if query exit status returned anything other than 0
checkForTimeout() {
	# FIXME exit status of 2 might be for timeouts - need to verify
	if [ echo $? != 0]
	then
		$timedout= true
	fi
}

runPsqlQuery() {
	dbQuery= $1
	setTimeout()
	psql -U $username -d $dbname $dbQuery
	checkForTimeout()
}

timedout= false
numberOfTimeouts= 0
for beneId in $randomBeneIds
do
	echo "Running all DB queries for beneId = $beneId"
	
	# get the hicn and claimIds for this beneId since it is needed for other queries
	hicn= `psql -U $username -d $dbname -c "SELECT hicn FROM Beneficiaries WHERE beneficiaryId = $beneId"`
	carrClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM CarrierClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	dmeClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM DMEClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	hhaClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM HHAClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	hospiceClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM HospiceClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	inpatientClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM InpatientClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	outpatientClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM OutpatientClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	pdeEventId= `psql -U $username -d $dbname -c "SELECT eventId FROM PartDEvents WHERE beneficiaryId = $beneId" LIMIT 1`
	snfClaimId= `psql -U $username -d $dbname -c "SELECT claimId FROM SNFClaims WHERE beneficiaryId = $beneId" LIMIT 1`
	
	# run all DB queries once for the current beneId
	while IFS= read -r line
	do
  		runPsqlQuery($line)
	done
	
	if [$timedout]
	then
		((numberOfTimeouts++))
		$timedout= false
	fi
done

# report total number of benes tests vs number benes that had timeouts
echo "Of $numBenesToQuery total Beneficiaries queried, $numberOfTimeouts resulted in timeouts."
