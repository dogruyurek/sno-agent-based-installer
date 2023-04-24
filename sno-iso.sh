#!/bin/bash

if ! type "yq" > /dev/null; then
  echo "Cannot find yq in the path, please install yq on the node first. ref: https://github.com/mikefarah/yq#install"
fi

if ! type "jinja2" > /dev/null; then
  echo "Cannot find jinja2 in the path, will install it with pip3 install jinja2-cli and pip3 install jinja2-cli[yaml]"
  pip3 install --user jinja2-cli
  pip3 install --user jinja2-cli[yaml]
fi

info(){
  printf  $(tput setaf 2)"%-28s %-10s"$(tput sgr0)"\n" "$@"
}

warn(){
  printf  $(tput setaf 3)"%-28s %-10s"$(tput sgr0)"\n" "$@"
}

basedir="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
templates=$basedir/templates

config_file=$1; shift
ocp_release=$1; shift

if [ -z "$config_file" ]
then
  config_file=config.yaml
fi

if [ -z "$ocp_release" ]
then
  ocp_release='stable-4.12'
fi

ocp_release_version=$(curl -s https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release}/release.txt | grep 'Version:' | awk -F ' ' '{print $2}')

echo "You are going to download OpenShift installer ${ocp_release_version}"

if [ -f $basedir/openshift-install-linux.tar.gz ]
  rm -f $basedir/openshift-install-linux.tar.gz
then
  curl -L https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/${ocp_release_version}/openshift-install-linux.tar.gz -o $basedir/openshift-install-linux.tar.gz
  tar xfz $basedir/openshift-install-linux.tar.gz openshift-install
fi

cluster_name=$(yq '.cluster.name' $config_file)
cluster_workspace=$cluster_name

mkdir -p $cluster_workspace
mkdir -p $cluster_workspace/openshift

echo
echo "Enabling day1 configuration..."
if [ "false" = "$(yq '.day1.workload_partition' $config_file)" ]; then
  warn "Workload partitioning:" "disabled"
else
  info "Workload partitioning:" "enabled"
  export crio_wp=$(jinja2 $templates/openshift/day1/workload-partition/crio.conf $config_file |base64 -w0)
  export k8s_wp=$(jinja2 $templates/openshift/day1/workload-partition/kubelet.conf $config_file |base64 -w0)
  jinja2 $templates/openshift/day1/workload-partition/02-master-workload-partitioning.yaml.j2 $config_file > $cluster_workspace/openshift/02-master-workload-partitioning.yaml
fi

if [ "false" = "$(yq '.day1.accelerate' $config_file)" ]; then
  warn "SNO boot accelerate:" "disabled"
else
  info "SNO boot accelerate:" "enabled"
  cp $templates/openshift/day1/accelerate/*.yaml $cluster_workspace/openshift/
fi

if [ "false" = "$(yq '.day1.kdump' $config_file)" ]; then
  warn "kdump service/config:" "disabled"
else
  info "kdump service/config:" "enabled"
  cp $templates/openshift/day1/kdump/*.yaml $cluster_workspace/openshift/
fi

if [ "false" = "$(yq '.day1.storage' $config_file)" ]; then
  warn "Local Storage Operator:" "disabled"
else
  info "Local Storage Operator:" "enabled"
  cp $templates/openshift/day1/storage/*.yaml $cluster_workspace/openshift/
fi

if [ "false" = "$(yq '.day1.ptp' $config_file)" ]; then
  warn "PTP Operator:" "disabled"
else
  info "PTP Operator:" "enabled"
  cp $templates/openshift/day1/ptp/*.yaml $cluster_workspace/openshift/
fi

if [ "false" = "$(yq '.day1.sriov' $config_file)" ]; then
  warn "SR-IOV Network Operator:" "disabled"
else
  info "SR-IOV Network Operator:" "enabled"
  cp $templates/openshift/day1/sriov/*.yaml $cluster_workspace/openshift/
fi

if [ "false" = "$(yq '.day1.amq' $config_file)" ]; then
  info "AMQ Interconnect Operator:" "enabled"
else
  warn "AMQ Interconnect Operator:" "disabled"
  cp $templates/openshift/day1/amq/*.yaml $cluster_workspace/openshift/
fi

if [ "true" = "$(yq '.day1.rhacm' $config_file)" ]; then
  info "Red Hat ACM:" "enabled"
  cp $templates/openshift/day1/rhacm/*.yaml $cluster_workspace/openshift/
else
  warn "Red Hat ACM:" "disabled"
fi

if [ "true" = "$(yq '.day1.gitops' $config_file)" ]; then
  info "GitOps Operator:" "enabled"
  cp $templates/openshift/day1/gitops/*.yaml $cluster_workspace/openshift/
else
  warn "GitOps Operator:" "disabled"
fi

if [ "true" = "$(yq '.day1.talm' $config_file)" ]; then
  info "TALM Operator:" "enabled"
  cp $templates/openshift/day1/talm/*.yaml $cluster_workspace/openshift/
else
  warn "TALM Operator:" "disabled"
fi

echo

if [ -d $basedir/extra-manifests ]; then
  echo "Copy customized CRs from extra-manifests folder if present"
  echo "$(ls -l $basedir/extra-manifests/)"
  cp $basedir/extra-manifests/*.yaml $cluster_workspace/openshift/ 2>/dev/null
fi

pull_secret=$(yq '.pull_secret' $config_file)
export pull_secret=$(cat $pull_secret)
ssh_key=$(yq '.ssh_key' $config_file)
export ssh_key=$(cat $ssh_key)

stack=$(yq '.host.stack' $config_file)
if [ ${stack} = "ipv4" ]; then
  jinja2 $templates/agent-config-ipv4.yaml.j2 $config_file > $cluster_workspace/agent-config.yaml
  jinja2 $templates/install-config-ipv4.yaml.j2 $config_file > $cluster_workspace/install-config.yaml
else
  jinja2 $templates/agent-config-ipv6.yaml.j2 $config_file > $cluster_workspace/agent-config.yaml
  jinja2 $templates/install-config-ipv6.yaml.j2 $config_file > $cluster_workspace/install-config.yaml
fi

echo
echo "Generating boot image..."
echo
$basedir/openshift-install --dir $cluster_workspace agent create image

echo ""
echo "------------------------------------------------"
echo "kubeconfig: $cluster_workspace/auth/kubeconfig."
echo "kubeadmin password: $cluster_workspace/auth/kubeadmin-password."
echo "------------------------------------------------"

echo
echo "Next step: Go to your BMC console and boot the node from ISO: $cluster_workspace/agent.x86_64.iso."
echo "You can also run ./sno-install.sh to boot the node from the image automatically if you have a HTTP server serves the image."
echo "Enjoy!"





