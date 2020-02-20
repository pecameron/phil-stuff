#!/bin/bash
# set -x

# Internal script called by get-ci-artifacts

# When a ci failure occurs this script can download the artifacts 
# for later offline analysis
# this takes a while and is not always useful
# analysis is left to the user (may integrate it with debugbootstrap)

# $1 base directory to put results e.g., t12105
# $2 base url e.g., https://gcsweb-ci.svc.ci.openshift.org/gcs/origin-ci-test/logs/release-openshift-origin-installer-e2e-aws-upgrade/12105/

baseurl="https://gcsweb-ci.svc.ci.openshift.org"

basedir=${1}
echo "basedir=${basedir}"
mkdir -p ${basedir}
cd ${basedir}

echo "======================================================"
echo "Calling with ${1} -- ${2}" >> /tmp/cilog
echo "Calling with ${1} -- ${2}"
echo "======================================================"

rm -f index.html
wget ${2}

list=$(grep -v "\.\." index.html | grep "><a href=" | sed 's;<div class="pure-u-2-5"><a href=";;' | sed 's/"><img//' | gawk '{ print $1 }')
rm -f index.html

for l in ${list}
do
	#echo PHIL $l
	thisdir=$(basename $l)
	#echo $thisdir
	if [[ $thisdir == "must-gather" ]] ; then
		continue
	fi
	if [[ $thisdir == "heap" ]] ; then
		continue
	fi
	if [[ $thisdir == "prometheus.tar" ]] ; then
		continue
	fi
	echo ${l} | grep "http" > /dev/null
	if [[ $? -eq 0 ]] ; then
		wget ${l}
		echo will get $l
		if [[ $thisdir == "masters-journal" ]] ; then
			mv masters-journal masters-journal.gz
			gunzip masters-journal.gz
		fi
		if [[ $thisdir == "workers-journal" ]] ; then
			mv workers-journal workers-journal.gz
			gunzip workers-journal.gz
		fi
		if [[ $thisdir == "prometheus-target-metadata.json" ]] ; then
			mv prometheus-target-metadata.json prometheus-target-metadata.json.gz
			gunzip prometheus-target-metadata.json.gz
		fi
		if [[ $thisdir == "statefulsets.json" ]] ; then
			mv statefulsets.json statefulsets.json.gz
			gunzip statefulsets.json.gz
		fi
		if [[ $thisdir == "replicasets.json" ]] ; then
			mv rworkers-journal rworkers-journal.gz
			gunzip rworkers-journal.gz
		fi
		if [[ $thisdir == "daemonsets.json" ]] ; then
			mv daemonsets.json daemonsets.json.gz
			gunzip daemonsets.json.gz
		fi
		if [[ $thisdir == "deployments.json" ]] ; then
			mv deployments.json deployments.json.gz
			gunzip deployments.json.gz
		fi
		if [[ $thisdir == "openapi.json" ]] ; then
			mv openapi.json openapi.json.gz
			gunzip openapi.json.gz
		fi

	else
		# sub directory
		dir=$(echo ${baseurl}${l} | sed "s;${2};;")
		#echo ${baseurl}${l}
		#echo ${l}
		#echo ${2}
		#echo $dir
		if [[ ${dir} == "audit_logs/" ]] ; then
			echo "skipping audit_logs/"
		else
			get-ci-artifacts.sh ${dir} ${baseurl}${l}
		fi
	fi
done
cd -
