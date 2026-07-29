#!/bin/bash

###############################################
# 1.0 Network Infrastructure
###############################################

# 1.1 Switched campus
mkdir -p 1-Network-Infrastructure/1.1-Switched-campus/{1.1.a-Switch-administration,1.1.b-Layer-2-protocols,1.1.c-VLAN-technologies,1.1.d-EtherChannel,1.1.e-Spanning-Tree-Protocol}

# 1.2 Routing concepts
mkdir -p 1-Network-Infrastructure/1.2-Routing-concepts/{1.2.a-Administrative-distance,1.2.b-Static-routing,1.2.c-Policy-based-routing,1.2.d-VRF-Lite,1.2.e-VRF-aware-routing,1.2.f-Route-leaking,1.2.g-Route-filtering,1.2.h-Redistribution,1.2.i-Routing-protocol-authentication,1.2.j-BFD,1.2.k-L3-MTU}

# 1.3 EIGRP
mkdir -p 1-Network-Infrastructure/1.3-EIGRP/{1.3.a-Adjacencies,1.3.b-Best-path-selection,1.3.c-Operations,1.3.d-Named-Mode,1.3.e-Optimization}

# 1.4 OSPF
mkdir -p 1-Network-Infrastructure/1.4-OSPF/{1.4.a-Adjacencies,1.4.b-OSPFv3-AF-support,1.4.c-Network-types-area-types,1.4.d-Path-preference,1.4.e-Operations,1.4.f-Optimization}

# 1.5 BGP
mkdir -p 1-Network-Infrastructure/1.5-BGP/{1.5.a-Peer-relations,1.5.b-Path-selection,1.5.c-Routing-policies,1.5.d-AS-path-manipulations,1.5.e-Convergence,1.5.f-Other-features}

# 1.6 Multicast
mkdir -p 1-Network-Infrastructure/1.6-Multicast/{1.6.a-L2-multicast,1.6.b-RPF-check,1.6.c-PIM}


###############################################
# 2.0 Software Defined Infrastructure
###############################################

# 2.1 SD-Access
mkdir -p 2-Software-Defined-Infrastructure/2.1-SD-Access/{2.1.a-Underlay,2.1.b-Overlay,2.1.c-Fabric-design,2.1.d-Fabric-deployment,2.1.e-Fabric-border-handoff,2.1.f-Segmentation}

# 2.2 SD-WAN
mkdir -p 2-Software-Defined-Infrastructure/2.2-SD-WAN/{2.2.a-Controller-architecture,2.2.b-SD-WAN-underlay,2.2.c-OMP,2.2.d-Configuration-templates,2.2.e-Centralized-policies,2.2.f-Localized-policies}

# 2.3 Programmability
mkdir -p 2-Software-Defined-Infrastructure/2.3-Programmability/{2.3.a-YANG,2.3.b-NETCONF,2.3.c-RESTCONF,2.3.d-Telemetry}


###############################################
# 3.0 Transport Technologies and Solutions
###############################################

# 3.1 Static GRE
mkdir -p 3-Transport-Technologies-and-Solutions/3.1-Static-GRE/{3.1.a-GRE-tunnels,3.1.b-GRE-keepalive}

# 3.2 MPLS
mkdir -p 3-Transport-Technologies-and-Solutions/3.2-MPLS/{3.2.a-Operations,3.2.b-L3VPN}

# 3.3 DMVPN
mkdir -p 3-Transport-Technologies-and-Solutions/3.3-DMVPN/{3.3.a-Troubleshoot-DMVPN-Phase3-dual-hub}


###############################################
# 4.0 Infrastructure Security and Services
###############################################

# 4.1 Device security
mkdir -p 4-Infrastructure-Security-and-Services/4.1-Device-security/{4.1.a-Control-plane-policing,4.1.b-AAA}

# 4.2 Network security
mkdir -p 4-Infrastructure-Security-and-Services/4.2-Network-security/{4.2.a-Switch-security,4.2.b-Router-security,4.2.c-IPv6-security}

# 4.3 System management
mkdir -p 4-Infrastructure-Security-and-Services/4.3-System-management/{4.3.a-Device-management,4.3.b-SNMP,4.3.c-Logging}

# 4.4 QoS
mkdir -p 4-Infrastructure-Security-and-Services/4.4-QoS/{4.4.a-DiffServ,4.4.b-Classification,4.4.c-NBAR,4.4.d-Marking,4.4.e-Policing-shaping,4.4.f-Congestion-management,4.4.g-HQoS,4.4.h-MQC}

# 4.5 Network services
mkdir -p 4-Infrastructure-Security-and-Services/4.5-Network-services/{4.5.a-FHRP,4.5.b-Time-sync,4.5.c-DHCP,4.5.d-NAT}

# 4.6 Network optimization
mkdir -p 4-Infrastructure-Security-and-Services/4.6-Network-optimization/{4.6.a-IP-SLA,4.6.b-Tracking,4.6.c-FNF}

# 4.7 Network operations
mkdir -p 4-Infrastructure-Security-and-Services/4.7-Network-operations/{4.7.a-Traffic-capture,4.7.b-Troubleshooting-tools}


###############################################
# 5.0 Infrastructure Automation and Programmability
###############################################

# 5.1 Data encoding formats
mkdir -p 5-Infrastructure-Automation-and-Programmability/5.1-Data-encoding/{5.1.a-JSON,5.1.b-XML,5.1.c-YAML,5.1.d-Jinja}

# 5.2 Automation and scripting
mkdir -p 5-Infrastructure-Automation-and-Programmability/5.2-Automation-scripting/{5.2.a-EEM,5.2.b-Guest-shell}

# 5.3 Programmability
mkdir -p 5-Infrastructure-Automation-and-Programmability/5.3-Programmability/{5.3.a-vManage-API,5.3.b-DNAC-API,5.3.c-Telemetry}

echo "✔ 全ディレクトリ生成完了"

