#/bin/bash
# gather the ovs, ovn nb and ovn sb databases

# based on gather-extra-commands.sh
function queue() {
  local TARGET="${1}"
  shift
  local LIVE
  LIVE="$(jobs | wc -l)"
  echo "${@}"
  if [[ -n "${FILTER:-}" ]]; then
    "${@}" | "${FILTER}" >"${TARGET}" &
  else
    "${@}" >"${TARGET}" &
  fi
}

# KUBECONFIG must be supplied
if [[ ${KUBECONFIG:-XX} == "XX" ]] ; then
  echo "KUBECONFIG must be provided"
fi

# ARTIFACT_DIR is where the resultant output is placed
ARTIFACT_DIR=${ARTIFACT_DIR:-artifact-dir}

rm -rf ${ARTIFACT_DIR}
mkdir -p ${ARTIFACT_DIR}

prj=$(oc projects | grep openshift-sdn)
if [[ $? == 0 ]] ; then
  echo "SDN"
  pds=$(oc --insecure-skip-tls-verify get --request-timeout=20s -n openshift-sdn -l app=sdn pods --template '{{ range .items }}{{ .metadata.name }}{{ "\n" }}{{ end }}')
  for i in ${pds}; do
    queue ${ARTIFACT_DIR}/iptables-save-$i oc --insecure-skip-tls-verify rsh --request-timeout=20 -n openshift-sdn -c sdn $i iptables-save
  done
  pds=$(oc --insecure-skip-tls-verify get --request-timeout=20s -n openshift-sdn -l app=ovs pods --template '{{ range .items }}{{ .metadata.name }}{{ "\n" }}{{ end }}')
  for i in ${pds}; do
    queue ${ARTIFACT_DIR}/iptables-save-$i oc --insecure-skip-tls-verify rsh --request-timeout=20 -n openshift-sdn $i ovs-vsctl show
  done
fi

prj=$(oc projects | grep openshift-ovn)
if [[ $? == 0 ]] ; then
  echo "OVN"
  # caprute ovs-vsctl --show for each node
  pds=$(oc --insecure-skip-tls-verify get --request-timeout=20s -n openshift-ovn-kubernetes -l app=ovs-node pods --template '{{ range .items }}{{ .metadata.name }}{{ "\n" }}{{ end }}')
  for i in ${pds}; do
    echo "POD $i"
    queue ${ARTIFACT_DIR}/ovs-db-$i oc --insecure-skip-tls-verify rsh --request-timeout=20 -n openshift-ovn-kubernetes $i ovs-vsctl show
  done
  # caprute ovs-vsctl --show for each node
  pds=$(oc --insecure-skip-tls-verify get --request-timeout=20s -n openshift-ovn-kubernetes -l app=ovnkube-master pods --template '{{ range .items }}{{ .metadata.name }}{{ "\n" }}{{ end }}')
  for i in ${pds}; do
    echo "POD $i"
    queue ${ARTIFACT_DIR}/ovn-nb-$i oc --insecure-skip-tls-verify rsh --request-timeout=20 -n openshift-ovn-kubernetes -c nbdb $i ovn-nbctl show 2>/dev/null
    queue ${ARTIFACT_DIR}/ovn-sb-$i oc --insecure-skip-tls-verify rsh --request-timeout=20 -n openshift-ovn-kubernetes -c sbdb $i ovn-sbctl show 2>/dev/null
  done
fi

exit
