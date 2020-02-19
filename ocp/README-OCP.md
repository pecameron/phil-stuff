# phil-stuff/ocp

General hacking on OCP
Useful to People in Redhat since it references some internal sites.
Environment variables are usually placed in ${HOME}/.bashrc
```
OCPtoolFuncs -- path to where this is installed
OCPinstallerBranch -- installer branch (e.g., 4.4.0-0.ci)
OCPinstallDir -- path to installed openshift-installer
MY_CLUSTER_DIR -- base directory for installed clusters
```

## kubeconfig  
Set up the following environment variable first:
```
MY_CLUSTER_DIR -- path to the base directory used in creating clusters.
```

Quick way to set up KUBECONFIG env var for a cluster --dir directory
```
$ . kubeconfig MY-CLUSTER-DIR-NAME
$ echo $KUBECONFIG
```

## makepullsecret.sh
Refresh the pull secrets needed for openshift-installer creating clusters.
Puts secrets in $HOME/.secrets
Combination of the try.openshift secret (doesn't change much)
and the api.ci.openshift.org secret (occasionally changes)

### Refresh token
Get the new token from "https://api.ci.openshift.org/oauth/token/request"`
```
$ makepullsecret.sh new-ci-token
```

### Display combined token -- needed by openshfit-installer
```
$ makepullsecret.sh
```

## getinstaller
Refreshes the openshfit-installer when there are manifest errors in
bringing up a cluster.

Goes to https://openshift-release.svc.ci.openshift.org and gets the latest
accepted installer.

Set up the following environment variables first:
```
OCPinstallDir     --- where to unpack the binaries (include in PATH)
OCPinstallerBranch --- at present 4.4.0-0.ci
```

```
$ getinstaller
```

## debugbootstrap
[Work in progress]
Tease information out of openshift-installer --dir mm gather bootstrap
cluster-dir is the directory passed in --dir above

This is occasionally useful when some well known problems occur.

```
$ debugbootstrap cluster-dir gather
```

When improving the analysis, don't bother doing the gather
```
$ debugbootstrap cluster-dir
```


## get-ci-artifacts.sh  
When a ci failure occurs this script can download the artifacts 
for later offline analysis.

When a ci test fails the PR has a link to the test results. That
page has an artifacts button. The second parameter, artifacts,
is the url in the browser window.

This takes a while and is not always useful.

For now, analysis is left to the user (may integrate it with debugbootstrap)

```
$ get-ci-artifacts.sh save-dir http://----/artifacts/
```

