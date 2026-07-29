#!/bin/bash

#---------------------------------------------
# README.md 自動生成関数
#---------------------------------------------
create_readme() {
  local dir="$1"
  local title="$2"

  cat <<EOF > "${dir}/README.md"
# ${title}

このページは CCIE Enterprise Infrastructure v1.1 Blueprint の  
「${title}」に対応する学習メモです。

## 目的
この項目では、Blueprint に記載されている技術要素を理解し、  
設定例・動作・トラブルシューティングを体系的に整理します。

## 内容
- Blueprint: ${title}
- ディレクトリ: ${dir}

## 学習メモ
（ここに内容を追加していきます）

EOF
}

#---------------------------------------------
# 1.0 Network Infrastructure
#---------------------------------------------
create_readme "1-Network-Infrastructure/1.1-Switched-campus/1.1.a-Switch-administration" "1.1.a Switch administration"
create_readme "1-Network-Infrastructure/1.1-Switched-campus/1.1.b-Layer-2-protocols" "1.1.b Layer 2 protocols"
create_readme "1-Network-Infrastructure/1.1-Switched-campus/1.1.c-VLAN-technologies" "1.1.c VLAN technologies"
create_readme "1-Network-Infrastructure/1.1-Switched-campus/1.1.d-EtherChannel" "1.1.d EtherChannel"
create_readme "1-Network-Infrastructure/1.1-Switched-campus/1.1.e-Spanning-Tree-Protocol" "1.1.e Spanning Tree Protocol"

create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.a-Administrative-distance" "1.2.a Administrative distance"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.b-Static-routing" "1.2.b Static routing"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.c-Policy-based-routing" "1.2.c Policy-based routing"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.d-VRF-Lite" "1.2.d VRF-Lite"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.e-VRF-aware-routing" "1.2.e VRF-aware routing"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.f-Route-leaking" "1.2.f Route leaking"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.g-Route-filtering" "1.2.g Route filtering"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.h-Redistribution" "1.2.h Redistribution"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.i-Routing-protocol-authentication" "1.2.i Routing protocol authentication"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.j-BFD" "1.2.j Bidirectional Forwarding Detection"
create_readme "1-Network-Infrastructure/1.2-Routing-concepts/1.2.k-L3-MTU" "1.2.k L3 MTU"

create_readme "1-Network-Infrastructure/1.3-EIGRP/1.3.a-Adjacencies" "1.3.a Adjacencies"
create_readme "1-Network-Infrastructure/1.3-EIGRP/1.3.b-Best-path-selection" "1.3.b Best path selection"
create_readme "1-Network-Infrastructure/1.3-EIGRP/1.3.c-Operations" "1.3.c Operations"
create_readme "1-Network-Infrastructure/1.3-EIGRP/1.3.d-Named-Mode" "1.3.d EIGRP named mode"
create_readme "1-Network-Infrastructure/1.3-EIGRP/1.3.e-Optimization" "1.3.e Optimization, convergence, and scalability"

create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.a-Adjacencies" "1.4.a Adjacencies"
create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.b-OSPFv3-AF-support" "1.4.b OSPFv3 address family support"
create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.c-Network-types-area-types" "1.4.c Network types, area types"
create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.d-Path-preference" "1.4.d Path preference"
create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.e-Operations" "1.4.e Operations"
create_readme "1-Network-Infrastructure/1.4-OSPF/1.4.f-Optimization" "1.4.f Optimization, convergence, and scalability"

create_readme "1-Network-Infrastructure/1.5-BGP/1.5.a-Peer-relations" "1.5.a IBGP and EBGP peer relations"
create_readme "1-Network-Infrastructure/1.5-BGP/1.5.b-Path-selection" "1.5.b Path selection"
create_readme "1-Network-Infrastructure/1.5-BGP/1.5.c-Routing-policies" "1.5.c Routing policies"
create_readme "1-Network-Infrastructure/1.5-BGP/1.5.d-AS-path-manipulations" "1.5.d AS path manipulations"
create_readme "1-Network-Infrastructure/1.5-BGP/1.5.e-Convergence" "1.5.e Convergence and scalability"
create_readme "1-Network-Infrastructure/1.5-BGP/1.5.f-Other-features" "1.5.f Other BGP features"

create_readme "1-Network-Infrastructure/1.6-Multicast/1.6.a-L2-multicast" "1.6.a Layer 2 multicast"
create_readme "1-Network-Infrastructure/1.6-Multicast/1.6.b-RPF-check" "1.6.b Reverse path forwarding check"
create_readme "1-Network-Infrastructure/1.6-Multicast/1.6.c-PIM" "1.6.c PIM"


###############################################
# 2.0 Software Defined Infrastructure
###############################################

create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.a-Underlay" "2.1.a Underlay"
create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.b-Overlay" "2.1.b Overlay"
create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.c-Fabric-design" "2.1.c Fabric design"
create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.d-Fabric-deployment" "2.1.d Fabric deployment"
create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.e-Fabric-border-handoff" "2.1.e Fabric border handoff"
create_readme "2-Software-Defined-Infrastructure/2.1-SD-Access/2.1.f-Segmentation" "2.1.f Segmentation"

create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.a-Controller-architecture" "2.2.a Controller architecture"
create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.b-SD-WAN-underlay" "2.2.b SD-WAN underlay"
create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.c-OMP" "2.2.c Overlay Management Protocol (OMP)"
create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.d-Configuration-templates" "2.2.d Configuration templates"
create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.e-Centralized-policies" "2.2.e Centralized policies"
create_readme "2-Software-Defined-Infrastructure/2.2-SD-WAN/2.2.f-Localized-policies" "2.2.f Localized policies"

create_readme "2-Software-Defined-Infrastructure/2.3-Programmability/2.3.a-YANG" "2.3.a YANG"
create_readme "2-Software-Defined-Infrastructure/2.3-Programmability/2.3.b-NETCONF" "2.3.b NETCONF"
create_readme "2-Software-Defined-Infrastructure/2.3-Programmability/2.3.c-RESTCONF" "2.3.c RESTCONF"
create_readme "2-Software-Defined-Infrastructure/2.3-Programmability/2.3.d-Telemetry" "2.3.d Telemetry"


###############################################
# 3.0 Transport Technologies and Solutions
###############################################

create_readme "3-Transport-Technologies-and-Solutions/3.1-Static-GRE/3.1.a-GRE-tunnels" "3.1.a GRE tunnels"
create_readme "3-Transport-Technologies-and-Solutions/3.1-Static-GRE/3.1.b-GRE-keepalive" "3.1.b GRE keepalive"

create_readme "3-Transport-Technologies-and-Solutions/3.2-MPLS/3.2.a-Operations" "3.2.a MPLS operations"
create_readme "3-Transport-Technologies-and-Solutions/3.2-MPLS/3.2.b-L3VPN" "3.2.b MPLS L3VPN"

create_readme "3-Transport-Technologies-and-Solutions/3.3-DMVPN/3.3.a-Troubleshoot-DMVPN-Phase3-dual-hub" "3.3.a Troubleshoot DMVPN Phase 3 with dual hub"


###############################################
# 4.0 Infrastructure Security and Services
###############################################

create_readme "4-Infrastructure-Security-and-Services/4.1-Device-security/4.1.a-Control-plane-policing" "4.1.a Control plane policing and protection"
create_readme "4-Infrastructure-Security-and-Services/4.1-Device-security/4.1.b-AAA" "4.1.b AAA"

create_readme "4-Infrastructure-Security-and-Services/4.2-Network-security/4.2.a-Switch-security" "4.2.a Switch security features"
create_readme "4-Infrastructure-Security-and-Services/4.2-Network-security/4.2.b-Router-security" "4.2.b Router security features"
create_readme "4-Infrastructure-Security-and-Services/4.2-Network-security/4.2.c-IPv6-security" "4.2.c IPv6 infrastructure security features"

create_readme "4-Infrastructure-Security-and-Services/4.3-System-management/4.3.a-Device-management" "4.3.a Device management"
create_readme "4-Infrastructure-Security-and-Services/4.3-System-management/4.3.b-SNMP" "4.3.b SNMP"
create_readme "4-Infrastructure-Security-and-Services/4.3-System-management/4.3.c-Logging" "4.3.c Logging"

create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.a-DiffServ" "4.4.a Differentiated Services architecture"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.b-Classification" "4.4.b Classification, trust boundary"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.c-NBAR" "4.4.c NBAR"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.d-Marking" "4.4.d Marking DSCP values"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.e-Policing-shaping" "4.4.e Policing, shaping"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.f-Congestion-management" "4.4.f Congestion management and avoidance"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.g-HQoS" "4.4.g HQoS"
create_readme "4-Infrastructure-Security-and-Services/4.4-QoS/4.4.h-MQC" "4.4.h End-to-end Layer 3 QoS using MQC"

create_readme "4-Infrastructure-Security-and-Services/4.5-Network-services/4.5.a-FHRP" "4.5.a First-Hop Redundancy Protocols"
create_readme "4-Infrastructure-Security-and-Services/4.5-Network-services/4.5.b-Time-sync" "4.5.b Time synchronization protocols"
create_readme "4-Infrastructure-Security-and-Services/4.5-Network-services/4.5.c-DHCP" "4.5.c DHCP on Cisco devices"
create_readme "4-Infrastructure-Security-and-Services/4.5-Network-services/4.5.d-NAT" "4.5.d IPv4 Network Address Translation"

create_readme "4-Infrastructure-Security-and-Services/4.6-Network-optimization/4.6.a-IP-SLA" "4.6.a IP SLA"
create_readme "4-Infrastructure-Security-and-Services/4.6-Network-optimization/4.6.b-Tracking" "4.6.b Tracking objects and lists"
create_readme "4-Infrastructure-Security-and-Services/4.6-Network-optimization/4.6.c-FNF" "4.6.c Flexible NetFlow"

create_readme "4-Infrastructure-Security-and-Services/4.7-Network-operations/4.7.a-Traffic-capture" "4.7.a Traffic capture"
create_readme "4-Infrastructure-Security-and-Services/4.7-Network-operations/4.7.b-Troubleshooting-tools" "4.7.b Troubleshooting tools"


###############################################
# 5.0 Infrastructure Automation and Programmability
###############################################

create_readme "5-Infrastructure-Automation-and-Programmability/5.1-Data-encoding/5.1.a-JSON" "5.1.a JSON"
create_readme "5-Infrastructure-Automation-and-Programmability/5.1-Data-encoding/5.1.b-XML" "5.1.b XML"
create_readme "5-Infrastructure-Automation-and-Programmability/5.1-Data-encoding/5.1.c-YAML" "5.1.c YAML"
create_readme "5-Infrastructure-Automation-and-Programmability/5.1-Data-encoding/5.1.d-Jinja" "5.1.d Jinja"

create_readme "5-Infrastructure-Automation-and-Programmability/5.2-Automation-scripting/5.2.a-EEM" "5.2.a EEM applets"
create_readme "5-Infrastructure-Automation-and-Programmability/5.2-Automation-scripting/5.2.b-Guest-shell" "5.2.b Guest shell"

create_readme "5-Infrastructure-Automation-and-Programmability/5.3-Programmability/5.3.a-vManage-API" "5.3.a Interaction with vManage API"
create_readme "5-Infrastructure-Automation-and-Programmability/5.3-Programmability/5.3.b-DNAC-API" "5.3.b Interaction with Cisco DNA Center API"
create_readme "5-Infrastructure-Automation-and-Programmability/5.3-Programmability/5.3.c-Telemetry" "5.3.c Deploy and verify model-driven telemetry"

echo "✔ 全 README.md 自動生成完了"

