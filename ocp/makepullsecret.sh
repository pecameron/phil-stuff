#!/bin/bash
# set -x
# get the combined pull secret
# use the try.openshift secret (doesn't change much) 
# and api.ci.openshift.org secret
# combine them into the combined-pull-secret

# installer is at  https://openshift-release.svc.ci.openshift.org/
# secrets are at   https://github.com/openshift/shared-secrets/
# ci token at      https://api.ci.openshift.org/oauth/token/request

# Run at top level of CNO
# expect secrets/pull-secret-* to be present

pullSecret=$(ls -t ${HOME}/.secrets/pull-secret-* 2>/dev/null | gawk '{ print $1}' | head -1)
if [[ ${pullSecret:-XX} == "XX" ]] ; then
	echo "pull-secret not found. Create a new pull secret first."
	echo "go to try.openshift secret"
	echo "select your desired cluster"
	echo "Copy Pull Secret"
	echo "the copied pull secret is the same for all clusters"
        echo "put it in a file ${HOME}/.secrets/pull-secret-<date>"
	exit 1
#else
#	echo "Using: ${pullSecret}"
fi

dateTag=$(date "+%Y%m%d")
if [[ ${1:-XX} == "XX" ]] ; then
	echo "token from: https://api.ci.openshift.org/oauth/token/request"
	combinedSecret=$(ls -t ${HOME}/.secrets/combined-pull-secrets-* 2>/dev/null | gawk '{ print $1}' | head -1)
	echo "Using ${combinedSecret}"
	echo "to get a new secret"
	echo "browse to: https://api.ci.openshift.org/oauth/token/request"
	echo "pass the token as the argument"

	cat ${combinedSecret}
	exit 1
fi
echo token ${1}

echo "get the ci token"
echo "login to https://api.ci.openshift.org with token: ${1}"
oc login --token=${1} --server=https://api.ci.openshift.org

echo "Get user info"
curl -H "Authorization: Bearer ${1}"  "https://api.ci.openshift.org/oapi/v1/users/~"

echo "Pull the ci token"
oc registry login --to ${HOME}/.secrets/ci-pull-secret-${dateTag}

cat ./ci-pull-secret-${dateTag}

# cluster pull-secret doesn't change often, just use pull-secret-1111
secret=$(ls -r ${HOME}/.secrets/pull-secret-* | head -1)
echo "Using cluster secret ${secret}"
jq -nc "$(cat ${secret}) * $(cat ${HOME}/.secrets/ci-pull-secret-${dateTag})" > ${HOME}/.secrets/combined-pull-secrets-${dateTag}

cat ${HOME}/.secrets/combined-pull-secrets-${dateTag}
