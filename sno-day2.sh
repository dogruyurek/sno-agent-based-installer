#!/bin/bash
# 
# Helper script to apply the day2 operations on SNO node
# Usage: ./sno-day2.sh config.yaml
#

if [ ! -f "/usr/bin/yq" ] && [ ! -f "/app/vbuild/RHEL7-x86_64/yq/4.25.1/bin/yq" ]; then
  echo "cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

if [ ! -f "/usr/local/bin/jinja2" ]; then
  echo "Cannot find jinja2 in the path, will install it with pip3 install jinja2-cli and pip3 install jinja2-cli[yaml]"
  pip3 install jinja2-cli
  pip3 install jinja2-cli[yaml]
fi

usage(){
	echo "Usage: $0 [config.yaml]"
  echo "Example: $0 config-sno130.yaml"
}

if [ $# -lt 1 ]
then
  usage
  exit
fi

if [[ ( $@ == "--help") ||  $@ == "-h" ]]
then 
  usage
  exit
fi


info(){
  printf  $(tput setaf 2)"%-60s %-10s"$(tput sgr0)"\n" "$@"
}

warn(){
  printf  $(tput setaf 3)"%-60s %-10s"$(tput sgr0)"\n" "$@"
}

basedir="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
templates=$basedir/templates

config_file=$1;

cluster_name=$(yq '.cluster.name' $config_file)
cluster_workspace=$cluster_name
export KUBECONFIG=$cluster_workspace/auth/kubeconfig

oc get clusterversion
echo
oc get nodes
echo

echo
echo "------------------------------------------------"
echo "Applying day2 operations...."
echo

if [ "false" = "$(yq '.day2.performance_profile.enabled' $config_file)" ]; then
  warn "performance profile:" "disabled"
else
  info "performance profile:" "enabled"
  jinja2 $templates/openshift/day2/performance-profile.yaml.j2 $config_file | oc apply -f -
fi

echo 

if [ "false" = "$(yq '.day2.tuned_profile.enabled' $config_file)" ]; then
  warn "tuned performance patch:" "disabled"
else
  info "tuned performance patch:" "enabled"
  jinja2 $templates/openshift/day2/performance-patch-tuned.yaml.j2 $config_file | oc apply -f -
fi

echo 

if [ "true" = "$(yq '.day2.tuned_profile.kdump' $config_file)" ]; then
  info "tuned kdump settings:" "enabled"
  oc apply -f $templates/openshift/day2/performance-patch-kdump-setting.yaml
else
  warn "tuned kdump settings:" "disabled"
fi

echo 

if [ "false" = "$(yq '.day2.cluster_monitor_tuning' $config_file)" ]; then
  warn "cluster monitor tuning:" "disabled"
else
  info "cluster monitor tuning:" "enabled"
  oc apply -f $templates/openshift/day2/cluster-monitoring-cm.yaml
fi

echo 

if [ "false" = "$(yq '.day2.operator_hub_tuning' $config_file)" ]; then
  warn "operator hub tuning:" "disabled"
else
  info "operator hub tuning:" "enabled"
  oc patch operatorhub cluster --type json -p "$(cat $templates/openshift/day2/patchoperatorhub.yaml)"
fi

echo 

if [ "false" = "$(yq '.day2.disable_ocp_console' $config_file)" ]; then
  warn "openshift console:" "enable"
else
  info "openshift console:" "disabled"
  oc patch consoles.operator.openshift.io cluster --type='json' -p=['{"op": "replace", "path": "/spec/managementState", "value":"Removed"}']
fi

echo 

if [ "false" = "$(yq '.day2.disable_network_diagnostics' $config_file)" ]; then
  warn "network diagnostics:" "enabled"
else
  info "network diagnostics:" "disabled"
  oc patch network.operator.openshift.io cluster --type='json' -p=['{"op": "replace", "path": "/spec/disableNetworkDiagnostics", "value":true}']
fi

echo 

if [ "true" = "$(yq '.day2.enable_ptp_amq_router' $config_file)" ]; then
  info "ptp amq router:" "enabled"
  oc apply -f $templates/openshift/day2/ptp-amq-instance.yaml
else
  warn "ptp amq router:" "disabled"
fi

echo 

if [ "false" = "$(yq '.day2.disable_operator_auto_upgrade' $config_file)" ]; then
  warn "operator auto upgrade:" "enable"
else
  subs=$(oc get subs -A -o jsonpath='{range .items[*]}{@.metadata.namespace}{" "}{@.metadata.name}{"\n"}{end}')
  subs=($subs)
  length=${#subs[@]}
  for i in $( seq 0 2 $((length-2)) ); do
    ns=${subs[$i]}
    name=${subs[$i+1]}
    info "operator $name auto upgrade:" "disabled"
    oc patch subscription -n $ns $name --type='json' -p=['{"op": "replace", "path": "/spec/installPlanApproval", "value":"Manual"}']
  done
fi


echo
echo "Done."
