#!/bin/bash
# set -x

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
