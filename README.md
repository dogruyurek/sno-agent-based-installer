# sno-agent-based-installer
Script to deploy SNO with Agent Based Installer

## Dependencies
Some software and tools are required to be installed before running the scripts:

- nmstatectl: sudo dnf install /usr/bin/nmstatectl -y
- yq: https://github.com/mikefarah/yq#install
- jinja2: pip3 install jinja2-cli, pip3 install jinja2-cli[yaml] 
 
## Configuration

Prepare config.yaml to fit your lab situation, example:

IPv4 with vlan:

```yaml
cluster:
  domain: outbound.vz.bos2.lab
  name: sno148

host:
  interface: ens1f0
  stack: ipv4
  hostname: sno148.outbound.vz.bos2.lab
  ip: 192.168.58.48
  dns: 192.168.58.15
  gateway: 192.168.58.1
  mac: b4:96:91:b4:9d:f0
  prefix: 25
  machine_network_cidr: 192.168.58.0/25
  vlan:
    enabled: true
    name: ens1f0.58
    id: 58
  disk: /dev/nvme0n1

cpu:
  isolated: 2-31,34-63
  reserved: 0-1,32-33

proxy:
  enabled: false
  http:
  https:
  noproxy:

pull_secret: ./pull-secret.json
ssh_key: /home/bzhai/.ssh/id_rsa.pub

```

IPv6 without vlan:

```yaml
cluster:
  domain: outbound.vz.bos2.lab
  name: sno148

host:
  interface: ens1f0
  stack: ipv6
  hostname: sno148.outbound.vz.bos2.lab
  ip: 2600:52:7:58::58
  dns: 2600:52:7:58::15
  gateway: 2600:52:7:58::1
  mac: b4:96:91:b4:9d:f0
  prefix: 64
  machine_network_cidr: 2600:52:7:58::/64
  vlan:
    enabled: false
    name: ens1f0.58
    id: 58
  disk: /dev/nvme0n1

cpu:
  isolated: 2-31,34-63
  reserved: 0-1,32-33

proxy:
  enabled: false
  http:
  https:
  noproxy:

pull_secret: ./pull-secret.json
ssh_key: /home/bzhai/.ssh/id_rsa.pub

```
## Generate ISO

```shell
#./sno-iso.sh
You are going to download OpenShift installer 4.12.6
WARNING Capabilities: %!!(MISSING)s(*types.Capabilities=<nil>) is ignored 
INFO The rendezvous host IP (node0 IP) is 192.168.58.48 
INFO Extracting base ISO from release payload     
INFO Base ISO obtained from release and cached at /home/bzhai/.cache/agent/image_cache/coreos-x86_64.iso 
INFO Consuming Extra Manifests from target directory 
INFO Consuming Install Config from target directory 
INFO Consuming Agent Config from target directory 

------------------------------------------------
Next step: Go to your BMC console and boot the node from ISO: sno148/agent.x86_64.iso.

kubeconfig: sno148/auth/kubeconfig.
kubeadmin password: sno148/auth/kubeadmin-password.

------------------------------------------------

```

Or specify the config file and OCP version:

```shell
#./sno-iso.sh config-ipv6.yaml 4.12.4
```

Specify the config file only:

```shell
#./sno-iso.sh config-ipv6.yaml
```

## Boot node from ISO

Boot the node from the generated ISO, OCP will be installed automatically.

We also have a helper script to boot the node from ISO and trigger the installation automatically, assume you have an HTTP server to host the ISO image.


```shell
# ./sno-install.sh 
Usage : ./sno-install.sh bmc_address username_password iso_image
Example : ./sno-install.sh 192.168.13.147 Administrator:dummy http://192.168.58.15/iso/agent-412.iso

```

Following is an example:
- BMC: 192.168.13.147
- Username and password to access BMC: Administrator:dummy
- ISO image location: http://192.168.58.15/iso/agent-412.iso

```shell
# ./sno-install.sh 192.168.13.148 Administrator:dummy http://192.168.58.15/iso/agent.x86_64.iso
Insert Virtual Media: http://192.168.58.15/iso/agent.x86_64.iso
204 https://192.168.13.148/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.InsertMedia
Virtual Media Status: 
{
  "@odata.context": "/redfish/v1/$metadata#VirtualMedia.VirtualMedia",
  "@odata.etag": "\"1679502491\"",
  "@odata.id": "/redfish/v1/Managers/Self/VirtualMedia/1",
  "@odata.type": "#VirtualMedia.v1_3_2.VirtualMedia",
  "Actions": {
    "#VirtualMedia.EjectMedia": {
      "target": "/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.EjectMedia"
    },
    "#VirtualMedia.InsertMedia": {
      "target": "/redfish/v1/Managers/Self/VirtualMedia/1/Actions/VirtualMedia.InsertMedia"
    }
  },
  "ConnectedVia": "URL",
  "Description": "Virtual Removable Media",
  "Id": "1",
  "Image": "http://192.168.58.15/iso/agent.x86_64.iso",
  "ImageName": "agent.x86_64.iso",
  "Inserted": true,
  "MediaStatus": "Mounted",
  "MediaTypes": [
    "CD"
  ],
  "Name": "VirtualMedia",
  "WriteProtected": true
}
Boot node from Virtual Media Once
204 https://192.168.13.148/redfish/v1/Systems/Self
Restart server.
{"@odata.context":"/redfish/v1/$metadata#Task.Task","@odata.id":"/redfish/v1/TaskService/Tasks/72","@odata.type":"#Task.v1_4_2.Task","Description":"Task for Computer Reset","Id":"72","Name":"Computer Reset","TaskState":"New"}202 https://192.168.13.148/redfish/v1/Systems/Self/Actions/ComputerSystem.Reset

------------
Node will be booting from virtual media mounted with http://192.168.58.15/iso/agent.x86_64.iso, check your BMC console to monitor the installation progress.

Once node booted from the ISO image, you can also monitoring the installation progress with command:
  curl --silent http://<sno-node-ip>:8090/api/assisted-install/v2/clusters |jq 

Enjoy!

```

To check installation progress:

```shell
# curl --silent http://192.168.58.48:8090/api/assisted-install/v2/clusters |jq .
[
  {
    "base_dns_domain": "outbound.vz.bos2.lab",
    "cluster_networks": [
      {
        "cidr": "10.128.0.0/14",
        "cluster_id": "3eae9ace-ff25-4d0e-bfd5-8e607d15e834",
        "host_prefix": 23
      }
    ],
    "connectivity_majority_groups": "{\"IPv4\":[],\"IPv6\":[]}",
    "controller_logs_collected_at": "0001-01-01T00:00:00.000Z",
    "controller_logs_started_at": "0001-01-01T00:00:00.000Z",
    "cpu_architecture": "x86_64",
    "created_at": "2023-03-22T16:35:07.710166Z",
    "deleted_at": null,
    "disk_encryption": {
      "enable_on": "none",
      "mode": "tpmv2"
    },
    "email_domain": "Unknown",
    "feature_usage": "{\"OVN network type\":{\"id\":\"OVN_NETWORK_TYPE\",\"name\":\"OVN network type\"},\"SNO\":{\"id\":\"SNO\",\"name\":\"SNO\"},\"Static Network Config\":{\"id\":\"STATIC_NETWORK_CONFIG\",\"name\":\"Static Network Config\"}}",
    "high_availability_mode": "None",
    "host_networks": null,
    "hosts": [],
    "href": "/api/assisted-install/v2/clusters/3eae9ace-ff25-4d0e-bfd5-8e607d15e834",
    "hyperthreading": "all",
    "id": "3eae9ace-ff25-4d0e-bfd5-8e607d15e834",
    "ignition_endpoint": {},
    "image_info": {
      "created_at": "2023-03-22T16:35:07.710166Z",
      "expires_at": "0001-01-01T00:00:00.000Z"
    },
    "install_completed_at": "0001-01-01T00:00:00.000Z",
    "install_started_at": "0001-01-01T00:00:00.000Z",
    "kind": "Cluster",
    "machine_networks": [
      {
        "cidr": "192.168.58.0/25",
        "cluster_id": "3eae9ace-ff25-4d0e-bfd5-8e607d15e834"
      }
    ],
    "monitored_operators": [
      {
        "cluster_id": "3eae9ace-ff25-4d0e-bfd5-8e607d15e834",
        "name": "console",
        "operator_type": "builtin",
        "status_updated_at": "0001-01-01T00:00:00.000Z",
        "timeout_seconds": 3600
      }
    ],
    "name": "sno148",
    "network_type": "OVNKubernetes",
    "ocp_release_image": "quay.io/openshift-release-dev/ocp-release@sha256:bd712a7aa5c1763870e721f92e19104c3c1b930d1a7d550a122c0ebbe2513aee",
    "openshift_version": "4.12.7",
    "platform": {
      "type": "none"
    },
    "progress": {},
    "pull_secret_set": true,
    "schedulable_masters": false,
    "schedulable_masters_forced_true": true,
    "service_networks": [
      {
        "cidr": "172.30.0.0/16",
        "cluster_id": "3eae9ace-ff25-4d0e-bfd5-8e607d15e834"
      }
    ],
    "ssh_public_key": "",
    "status": "insufficient",
    "status_info": "Cluster is not ready for install",
    "status_updated_at": "2023-03-22T16:35:07.709Z",
    "updated_at": "2023-03-22T16:35:12.046841Z",
    "user_managed_networking": true,
    "user_name": "admin",
    "validations_info": "{\"configuration\":[{\"id\":\"pull-secret-set\",\"status\":\"success\",\"message\":\"The pull secret is set.\"}],\"hosts-data\":[{\"id\":\"all-hosts-are-ready-to-install\",\"status\":\"success\",\"message\":\"All hosts in the cluster are ready to install.\"},{\"id\":\"sufficient-masters-count\",\"status\":\"failure\",\"message\":\"Single-node clusters must have a single control plane node and no workers.\"}],\"network\":[{\"id\":\"api-vip-defined\",\"status\":\"success\",\"message\":\"The API virtual IP is not required: User Managed Networking\"},{\"id\":\"api-vip-valid\",\"status\":\"success\",\"message\":\"The API virtual IP is not required: User Managed Networking\"},{\"id\":\"cluster-cidr-defined\",\"status\":\"success\",\"message\":\"The Cluster Network CIDR is defined.\"},{\"id\":\"dns-domain-defined\",\"status\":\"success\",\"message\":\"The base domain is defined.\"},{\"id\":\"ingress-vip-defined\",\"status\":\"success\",\"message\":\"The Ingress virtual IP is not required: User Managed Networking\"},{\"id\":\"ingress-vip-valid\",\"status\":\"success\",\"message\":\"The Ingress virtual IP is not required: User Managed Networking\"},{\"id\":\"machine-cidr-defined\",\"status\":\"success\",\"message\":\"The Machine Network CIDR is defined.\"},{\"id\":\"machine-cidr-equals-to-calculated-cidr\",\"status\":\"success\",\"message\":\"The Cluster Machine CIDR is not required: User Managed Networking\"},{\"id\":\"network-prefix-valid\",\"status\":\"success\",\"message\":\"The Cluster Network prefix is valid.\"},{\"id\":\"network-type-valid\",\"status\":\"success\",\"message\":\"The cluster has a valid network type\"},{\"id\":\"networks-same-address-families\",\"status\":\"success\",\"message\":\"Same address families for all networks.\"},{\"id\":\"no-cidrs-overlapping\",\"status\":\"success\",\"message\":\"No CIDRS are overlapping.\"},{\"id\":\"ntp-server-configured\",\"status\":\"success\",\"message\":\"No ntp problems found\"},{\"id\":\"service-cidr-defined\",\"status\":\"success\",\"message\":\"The Service Network CIDR is defined.\"}],\"operators\":[{\"id\":\"cnv-requirements-satisfied\",\"status\":\"success\",\"message\":\"cnv is disabled\"},{\"id\":\"lso-requirements-satisfied\",\"status\":\"success\",\"message\":\"lso is disabled\"},{\"id\":\"lvm-requirements-satisfied\",\"status\":\"success\",\"message\":\"lvm is disabled\"},{\"id\":\"odf-requirements-satisfied\",\"status\":\"success\",\"message\":\"odf is disabled\"}]}",
    "vip_dhcp_allocation": false
  }
]

```

## Day2 operations

Some CRs are not supported in installation phase including PerformanceProfile, those can/shall be done as day 2 operations once SNO is deployed.

```shell
#./sno-day2.sh
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.12.4    True        False         17m     Cluster version is 4.12.4

NAME                          STATUS   ROLES                         AGE   VERSION
sno148.outbound.vz.bos2.lab   Ready    control-plane,master,worker   40m   v1.25.4+a34b9e9

NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE   MESSAGE
authentication                             4.12.4    True        False         False      22m     
baremetal                                  4.12.4    True        False         False      28m     
cloud-controller-manager                   4.12.4    True        False         False      28m     
cloud-credential                           4.12.4    True        False         False      35m     
cluster-autoscaler                         4.12.4    True        False         False      28m     
config-operator                            4.12.4    True        False         False      36m     
console                                    4.12.4    True        False         False      24m     
control-plane-machine-set                  4.12.4    True        False         False      28m     
csi-snapshot-controller                    4.12.4    True        False         False      36m     
dns                                        4.12.4    True        False         False      6m29s   
etcd                                       4.12.4    True        False         False      32m     
image-registry                             4.12.4    True        False         False      27m     
ingress                                    4.12.4    True        False         False      35m     
insights                                   4.12.4    True        False         False      29m     
kube-apiserver                             4.12.4    True        False         False      27m     
kube-controller-manager                    4.12.4    True        False         False      29m     
kube-scheduler                             4.12.4    True        False         False      30m     
kube-storage-version-migrator              4.12.4    True        False         False      36m     
machine-api                                4.12.4    True        False         False      28m     
machine-approver                           4.12.4    True        False         False      28m     
machine-config                             4.12.4    True        False         False      35m     
marketplace                                4.12.4    True        False         False      35m     
monitoring                                 4.12.4    True        False         False      23m     
network                                    4.12.4    True        False         False      37m     
node-tuning                                4.12.4    True        False         False      49s     
openshift-apiserver                        4.12.4    True        False         False      6m23s   
openshift-controller-manager               4.12.4    True        False         False      27m     
openshift-samples                          4.12.4    True        False         False      28m     
operator-lifecycle-manager                 4.12.4    True        False         False      36m     
operator-lifecycle-manager-catalog         4.12.4    True        False         False      36m     
operator-lifecycle-manager-packageserver   4.12.4    True        False         False      30m     
service-ca                                 4.12.4    True        False         False      36m     
storage                                    4.12.4    True        False         False      36m     

NAME                                                      AGE
local-storage-operator.openshift-local-storage            36m
ptp-operator.openshift-ptp                                36m
sriov-network-operator.openshift-sriov-network-operator   36m

NAMESPACE                              NAME                                          DISPLAY                   VERSION               REPLACES   PHASE
openshift-local-storage                local-storage-operator.v4.12.0-202302280915   Local Storage             4.12.0-202302280915              Succeeded
openshift-operator-lifecycle-manager   packageserver                                 Package Server            0.19.0                           Succeeded
openshift-ptp                          ptp-operator.4.12.0-202302280915              PTP Operator              4.12.0-202302280915              Succeeded
openshift-sriov-network-operator       sriov-network-operator.v4.12.0-202302280915   SR-IOV Network Operator   4.12.0-202302280915              Succeeded


Applying day2 operations....
performanceprofile.performance.openshift.io/sno-performance-profile created
tuned.tuned.openshift.io/performance-patch created
configmap/cluster-monitoring-config created
operatorhub.config.openshift.io/cluster patched
console.operator.openshift.io/cluster patched
network.operator.openshift.io/cluster patched

Done.
```

## Validation

Check if all required tunings and operators are in placed: 

```shell
#./sno-ready.sh
NAME                          STATUS   ROLES                         AGE   VERSION
sno148.outbound.vz.bos2.lab   Ready    control-plane,master,worker   51m   v1.25.4+a34b9e9

Checking node:
 [+]Node is ready.

Checking all pods:
 [+]No failing pods.

Checking required machine config:
 [+]MachineConfig container-mount-namespace-and-kubelet-conf-master exits.
 [+]MachineConfig 02-master-workload-partitioning exits.
 [+]MachineConfig 04-accelerated-container-startup-master exits.
 [+]MachineConfig 05-kdump-config-master exits.
 [+]MachineConfig 06-kdump-enable-master exits.
 [+]MachineConfig 99-crio-disable-wipe-master exits.
 [-]MachineConfig disable-chronyd is not existing.

Checking machine config pool:
 [+]mcp master is updated and not degraded.

Checking required performance profile:
 [+]PerformanceProfile sno-performance-profile exits.
 [+]topologyPolicy is single-numa-node
 [+]realTimeKernel is enabled

Checking required tuned:
 [+]Tuned performance-patch exits.

Checking SRIOV operator status:
 [+]sriovnetworknodestate sync status is 'Succeeded'.

Checking PTP operator status:
 [+]Ptp linuxptp-daemon is ready.
No resources found in openshift-ptp namespace.
 [-]PtpConfig not exist.

Checking openshift monitoring.
 [+]Grafana is not enabled.
 [+]AlertManager is not enabled.
 [+]PrometheusK8s retention is not 24h.

Checking openshift console.
 [+]Openshift console is disabled.

Checking network diagnostics.
 [+]Network diagnostics is disabled.

Checking Operator hub.
 [+]Catalog community-operators is disabled.
 [+]Catalog redhat-marketplace is disabled.

Checking /proc/cmdline:
 [+]systemd.cpu_affinity presents: systemd.cpu_affinity=0,1,32,33
 [+]isolcpus presents: isolcpus=managed_irq,2-31,34-63
 [+]Isolated cpu in cmdline: 2-31,34-63 matches with the ones in performance profile: 2-31,34-63
 [+]Reserved cpu in cmdline: 0,1,32,33 matches with the ones in performance profile: 0-1,32-33

Checking RHCOS kernel:
 [+]Node is realtime kernel.

Checking kdump.service:
 [+]kdump is active.
 [+]kdump is enabled.

Checking chronyd.service:
 [-]chronyd is active.
 [-]chronyd is enabled.

Checking crop-wipe.service:
 [+]crio-wipe is inactive.
 [+]crio-wipe is not enabled.

Completed the checking.

```

## TODO

- Use redfish API to mount the ISO on BMC and boot the node
- Monitor installation progress

## Why not Ansible?
Not every user has ansible environment just in order to deploy a SNO.
