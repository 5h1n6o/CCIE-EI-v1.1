---
layout: default
title: 4.1.a-Control-plane-policing
parent: 4.1-Device-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.1.a Control plane policing and protection

---

## 📘 概要

Control Plane Policing (CoPP) および Control Plane Protection (CPPr) は、Cisco IOS XE ルータの Control Plane (CPU / Route Processor) を過剰なデータ通信や大量のパケットフラッディング、過度な負荷状態から防護するためのハードウェア／ソフトウェアセキュリティ機能である。

ネットワークルータにおける処理は、データプレーン (Data Plane)、コントロールプレーン (Control Plane)、マネジメントプレーン (Management Plane) の3つに分類される。データプレーンのパケットは CEF (Cisco Express Forwarding) によって ASIC / Hardware TCAM 上で高速に転送されるが、ルータ宛てのパケット (BGP, OSPF, EIGRP, BFD, SSH, SNMP, NTP 等) や CEF で直接処理できない例外パケット (IP Options, TTL 期限切れ, ARP 未解決パケット等) は、CPU (Control Plane) へ Punt (転送) される。

CoPP / CPPr は、この CPU 宛て Punt パケットに対して MQC (Modular QoS CLI) の Class-Map および Policy-Map を適用し、パケット分類・レート制限 (Policing)・ドロップ判定をハードウェア／ソフトウェアの境界で実行することにより、過度な CPU 負荷の上昇やコントロールプレーンの枯渇を防止する。

利用場面：
- 企業ネットワークコア／ディストリビューションおよび WAN 境界ルータにおける過剰トラフィック保護
- 外部からの ICMP / TCP SYN 大量送信時におけるルーティングプロトコル (BGP / OSPF / EIGRP) や BFD セッションの維持
- 不正なスキャンやパケット作成による CPU 枯渇防止
- 制御通信と管理通信の帯域分離および帯域制限

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | ルータ CPU 宛て Punt トラフィックに対して MQC (Class-Map / Policy-Map) を適用し、レート制限 (Policing) またはドロップを実行 |
| **用途** | CPU 負荷上昇防止、Control Plane 枯渇防止、Routing / BFD / SSH 通信の保護 |
| **メリット** | 大量パケット発生時でも重要ルーティングプロトコルや管理アクセスを維持可能。ハードウェア (QFP/TCAM) レベルで初期ポリシングが可能 |
| **デメリット** | 設定誤り (例: ACL でのプロトコル指定漏れ) により、正常な制御通信がドロップされ、BGP/OSPF セッションダウンを誘発するリスクがある |
| **対応機種** | Cisco Catalyst 9000 シリーズ (Cat9300 / Cat9400 / Cat9500 / Cat9600), ISR 4000, Catalyst 8000 (C8200 / C8300 / C8500 / C8000v) など IOS XE 全機種 |
| **制限事項** | CoPP は Control Plane への `input` 方向のみサポート (`output` は不可)。ACL 内の `permit` は「CoPP 評価対象」、`deny` は「CoPP 評価外 (class-default へ流す)」を意味する |
| **設計上の注意点** | 必須制御プロトコル (BGP, OSPF, EIGRP, BFD, LDP) を網羅した Class-Map を最優先で定義し、明確にポリシング範囲から除外または十分な帯域を与えること |

---

## 🏗 動作原理

Cisco IOS XE における Control Plane へのパケット処理フローは以下の通りである。

```
[ Physical / Logical Interface ]
               │
               ▼
   [ Data Plane (CEF / TCAM) ]
               │
               ├──────────────────────────┐ (Transit Packet: 他宛て通信)
               │                          │
               ▼ (Punt Packet: CPU 宛て)  ▼
      [ CoPP / CPPr Pipeline ]    [ Hardware Switching / Egress ]
               │
      ┌────────┴────────┐
      │  MQC Class-Map  │ (ACL / Protocol / DSCP Matching)
      └────────┬────────┘
               │
      ┌────────┴────────┐
      │ MQC Policy-Map  │ (Police Rate-Limit / Conform / Exceed / Drop)
      └────────┬────────┘
               │
               ▼
[ Control Plane / CPU Processor ] (BGP / OSPF / SSH / ARP Process)
```

CPPr (Control Plane Protection) では、さらに Control Plane を以下の 3 つの論理サブインターフェイスに分割して個別にポリシングを行う。

```
                    ┌──► Host Subinterface (ルータ自身の IP 宛て: SSH, BGP, SNMP, OSPF)
                    │
[ Control Plane ] ──┼──► Transit Subinterface (ルータを経由する例外: IP Options, TTL=1)
                    │
                    └──► CEF-Exception Subinterface (CEF 例外: ARP, Glean, ICMP Redirect)
```

---

## ⚙ 動作シーケンス

パケット受信から Control Plane 処理までのシーケンス：

1. **パケット受信**: 物理／論理ポートで IP パケットを受信。
2. **CEF 判定**: データプレーンの CEF / TCAM が宛先 IP を検索。
   - ルータ自身の IP 宛て、マルチキャスト宛て（OSPF: 224.0.0.5/6、EIGRP: 224.0.0.10）、または CEF 例外（TTL=1、ARP 未解決、IP Options）の場合は **Punt** と判定。
3. **CoPP 評価 Pipeline 入力**: パケットが CPU に転送される直前に `control-plane` にバインドされた Service Policy が評価される。
4. **Class-Map マッチング**:
   - 定義された順番に Class-Map (ACL や Match 属性) を評価。
   - ACL の `permit` に該当したパケットは当該 Class-Map にマッチ。
   - ACL の `deny` に該当したパケットは次の Class-Map へパス（最終的に `class-default` へ）。
5. **Policy-Map アクション実行**:
   - **Conform-action**: 設定されたポリシング帯域（bps / pps）以内であれば `transmit`（CPU への引き渡し許可）。
   - **Exceed-action / Violate-action**: 超過分は `drop`（廃棄）または `policed-dscp` 等でマークダウン。
6. **CPU 処理**: Conform したパケットのみが Cisco IOS XE ソフトウェアプロセス（BGP Router Process, OSPF Process, SSH Daemon 等）へ渡される。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
- **CoPP の基本構文**: `access-list` ➔ `class-map` ➔ `policy-map` ➔ `control-plane` ➔ `service-policy input <POLICY>`
- **CPPr のサブインターフェイスバインド**:
  - `control-plane host`
  - `control-plane transit`
  - `control-plane cef-exception`
- **CoPP 用 Access-List の特殊動作の理解**:
  - `permit` ＝ 「CoPP ポリシーで一致させる（ポリシングを適用する）」
  - `deny` ＝ 「この Class-Map では評価せず、後続の Class-Map または class-default に流す」
- **プロトコル漏れ防止**: BGP (TCP 179), OSPF (IP Protocol 89), EIGRP (IP Protocol 88), BFD (UDP 3784/3785), LDP (TCP/UDP 646), ICMP, SSH (TCP 22), SNMP (UDP 161) の適切な記述。

### ラボ試験で設定させられそうな内容
1. BGP、OSPF、BFD をドロップさせず優先保護しつつ、ICMP トラフィックを 8000 bps に制限する CoPP の設定。
2. SSH/TELNET 管理通信を特定管理サブネットからのみ許可し、それ以外の管理通信を CoPP でドロップ。
3. CPPr を使用して、ルータ宛ての ARP パケット (CEF-Exception) および TTL 期限切れパケット (Transit) に対する個別のポリシング設定。
4. CoPP 設定後に OSPF や BGP のネイバー切断が発生しないことの検証およびトラブルシューティング。


---

## 🛠 設定方法

```text
! 1. 制御プロトコル用・管理用・その他用の Access-List の定義
ip access-list extended ACL_COPP_ROUTING
 permit tcp any any eq bgp
 permit tcp any eq bgp any
 permit ospf any any
 permit eigrp any any
 permit udp any any eq 3784
 permit udp any any eq 3785
 permit tcp any any eq 646

ip access-list extended ACL_COPP_MGMT
 permit tcp 192.168.100.0 0.0.0.255 any eq 22
 permit udp 192.168.100.0 0.0.0.255 any eq 161

ip access-list extended ACL_COPP_ICMP
 permit icmp any any

! 2. Class-Map の定義
class-map match-all CM_COPP_ROUTING
 match access-group name ACL_COPP_ROUTING

class-map match-all CM_COPP_MGMT
 match access-group name ACL_COPP_MGMT

class-map match-all CM_COPP_ICMP
 match access-group name ACL_COPP_ICMP

! 3. Policy-Map の定義
policy-map PM_COPP
 class CM_COPP_ROUTING
  police 1000000 conform-action transmit exceed-action transmit
 class CM_COPP_MGMT
  police 256000 conform-action transmit exceed-action drop
 class CM_COPP_ICMP
  police 8000 conform-action transmit exceed-action drop
 class class-default
  police 64000 conform-action transmit exceed-action drop

! 4. Control Plane への適用
control-plane
 service-policy input PM_COPP
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **CoPP 全体ステータス確認** | <code>show policy-map control-plane</code> |
| **CPPr Host サブインターフェイス確認** | <code>show policy-map control-plane host</code> |
| **CPPr Transit サブインターフェイス確認** | <code>show policy-map control-plane transit</code> |
| **CPPr CEF-Exception 確認** | <code>show policy-map control-plane cef-exception</code> |
| **Punt パケット統計の確認** | <code>show platform software interface fp active status</code> |
| **QFP CPU ドロップ統計** | <code>show platform hardware qfp active statistics drop</code> |
| **Control Plane 転送状況のドロップ確認** | <code>show policy-map control-plane \| include drop</code> |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **CoPP 適用後 BGP/OSPF ネイバーがフラップする** | ACL で BGP や OSPF が漏れており `class-default` 等でドロップされている | <code>show policy-map control-plane</code> | ACL に `permit tcp any any eq bgp` や `permit ospf any any` を追加する |
| **BFD セッションが周期的にダウンする** | BFD 用ポート (UDP 3784/3785) が Class-Map に定義されておらずドロップ | <code>show policy-map control-plane</code> | ACL に `permit udp any any eq 3784` を追加し帯域確保する |
| **SSH 管理アクセスが拒否される** | 管理アクセス用 ACL のソース IP やポート (TCP 22) 指定誤り | <code>show access-lists ACL_COPP_MGMT</code> | 管理端末 IP を正確に ACL へ登録する |
| **CoPP ポリシー設定時にコマンドエラーが発生** | `service-policy output` を指定している | <code>show running-config \| section control-plane</code> | CoPP は `input` のみサポートするため `service-policy input` に変更する |

---

## ⚠ 制限事項

1. **方向制限**: CoPP は `control-plane` における `input` 方向のみサポート。`output` は適用不可。
2. **プラットフォーム依存**: IOS XE (Cat9k / ASR1k / ISR4k / C8k) では QFP や TCAM ハードウェアで処理される。
3. **ACL 記述の解釈**: ACL の `deny` ステートメントは「ドロップ」ではなく「当該 Class-Map での一致を見送り次以降の Class-Map へ引き渡す」動作となる。

---

## 🔄 他技術との関連

- **Routing Protocols (BGP / OSPF / EIGRP / LDP)**: CoPP の設定誤りはこれら全ルーティングプロトコルのセッション切断に直結する。
- **BFD (Bidirectional Forwarding Detection)**: ミリ秒単位の障害検知を行うため、CoPP でのドロップは即座にルーティングフラッピングを引き起こす。
- **Management Services (SSH, SNMP, NTP, TACACS+/RADIUS)**: 十分な帯域を CoPP で確保する必要がある。
- **Infrastructure Security (MPP, IP Source Guard, DAI)**: MPP や DAI / DHCP Snooping 等と組み合わせて多層防御を構築する。

---

## 🧩 比較表

| 項目 | CoPP (Control Plane Policing) | CPPr (Control Plane Protection) | MPP (Management Plane Protection) |
| :--- | :--- | :--- | :--- |
| **保護対象** | Control Plane 全体 (CPU 宛て全 Punt トラフィック) | Control Plane を Host / Transit / CEF-Exception に3分割保護 | Management Plane (SSH/SNMP 等の管理通信ポート制限) |
| **適用場所** | `control-plane` | `control-plane host` / `transit` / `cef-exception` | `control-plane` 内の `management-interface` |
| **設定手法** | MQC (Class-Map + Policy-Map) | MQC (サブインターフェイス別 Policy-Map) | インターフェイス限定バインド (`allow ssh in GigabitEthernet1`) |
| **粒度** | ルータ全体での一括ポリシング | 宛先／トラフィック種別ごとの個別ポリシング | 受信インターフェイス単位のアクセス制限 |

---

## 💡 ベストプラクティス

1. **制御プロトコルの絶対保護**: BGP、OSPF、EIGRP、BFD、LDP パケットはポリシングドロップされないよう、十分な帯域を与えるか `exceed-action transmit` に設定する。
2. **管理アクセスの明示的許可**: SSH (TCP 22) や SNMP (UDP 161) には許可された管理ネットワークからの通信のみをマッピングし、不正 IP からのアクセス試行を低帯域設定で drop する。
3. **class-default のドロップ調整**: 未知のトラフィックやスキャン通信を制限するため、`class-default` には適切なポリシングレート (例: 64 kbps 〜 256 kbps) を適用し `exceed-action drop` とする。
4. **段階的導入 (Monitor Mode)**: 本番環境に適用する際は、最初に `exceed-action transmit` とし、`show policy-map control-plane` でドロップ対象となるトラフィックを事前確認してから `exceed-action drop` に変更する。


---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: BGP & OSPF 優先保護 + ICMP レート制限 CoPP
- **問題**: BGP および OSPF トラフィックを保護し、ICMP パケットを 8000 bps に制限せよ。
- **要件**:
  - BGP (TCP 179) と OSPF は帯域超過時もドロップさせない。
  - ICMP 通信は 8000 bps を超えた場合ドロップする。
  - その他一般通信 (class-default) は 32000 bps で制限する。
- **設定例**:
```text
ip access-list extended ACL_ROUTING
 permit tcp any any eq bgp
 permit tcp any eq bgp any
 permit ospf any any

ip access-list extended ACL_ICMP
 permit icmp any any

class-map match-all CM_ROUTING
 match access-group name ACL_ROUTING

class-map match-all CM_ICMP
 match access-group name ACL_ICMP

policy-map PM_COPP_LAB1
 class CM_ROUTING
  police 1000000 conform-action transmit exceed-action transmit
 class CM_ICMP
  police 8000 conform-action transmit exceed-action drop
 class class-default
  police 32000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_LAB1
```
- **検証方法**:
  - 対向ルータから ping を実行。
  - <code>show policy-map control-plane class CM_ICMP</code> を実行し、`exceeded` カウンタが増加することを確認。

---

### サンプル 2: BFD 専用帯域確保 ＆ SSH 管理アクセス制限
- **問題**: BFD (UDP 3784/3785) を最高優先とし、SSH (TCP 22) を 192.168.1.0/24 からのみ許可せよ。
- **設定例**:
```text
ip access-list extended ACL_BFD
 permit udp any any eq 3784
 permit udp any any eq 3785

ip access-list extended ACL_SSH_ALLOW
 permit tcp 192.168.1.0 0.0.0.255 any eq 22

ip access-list extended ACL_SSH_DENY
 permit tcp any any eq 22

class-map match-all CM_BFD
 match access-group name ACL_BFD

class-map match-all CM_SSH_ALLOW
 match access-group name ACL_SSH_ALLOW

class-map match-all CM_SSH_DENY
 match access-group name ACL_SSH_DENY

policy-map PM_COPP_LAB2
 class CM_BFD
  police 512000 conform-action transmit exceed-action transmit
 class CM_SSH_ALLOW
  police 128000 conform-action transmit exceed-action drop
 class CM_SSH_DENY
  police 8000 conform-action drop exceed-action drop
 class class-default
  police 64000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_LAB2
```
- **検証方法**:
  - <code>show policy-map control-plane</code> でドロップ数とクラス評価状況を確認。

---

### サンプル 3: CPPr Host サブインターフェイスでの個別管理制限
- **問題**: CPPr を使用し、ルータ自身宛て (Host Subinterface) の SNMP (UDP 161) 通信を 64kbps に制限せよ。
- **設定例**:
```text
ip access-list extended ACL_SNMP
 permit udp any any eq 161

class-map match-all CM_SNMP
 match access-group name ACL_SNMP

policy-map PM_CPPR_HOST
 class CM_SNMP
  police 64000 conform-action transmit exceed-action drop

control-plane host
 service-policy input PM_CPPR_HOST
```
- **検証方法**:
  - <code>show policy-map control-plane host</code> を実行。

---

### サンプル 4: CPPr Transit サブインターフェイスによる IP Options / TTL 例外保護
- **問題**: Transit サブインターフェイスで TTL=1 および IP Options パケットの CPU 負荷を制限せよ。
- **設定例**:
```text
ip access-list extended ACL_TRANSIT_EXCEPTIONS
 permit ip any any option any-options
 permit ip any any ttl eq 1

class-map match-all CM_TRANSIT_EXCEPTIONS
 match access-group name ACL_TRANSIT_EXCEPTIONS

policy-map PM_CPPR_TRANSIT
 class CM_TRANSIT_EXCEPTIONS
  police 32000 conform-action transmit exceed-action drop

control-plane transit
 service-policy input PM_CPPR_TRANSIT
```
- **検証方法**:
  - <code>show policy-map control-plane transit</code> を確認。

---

### サンプル 5: CPPr CEF-Exception サブインターフェイスでの ARP 例外ポリシング
- **問題**: CEF-Exception サブインターフェイスで ARP パケットを制限せよ。
- **設定例**:
```text
ip access-list extended ACL_ARP_PUNT
 permit arp any any

class-map match-all CM_ARP_PUNT
 match access-group name ACL_ARP_PUNT

policy-map PM_CPPR_CEF_EXCEPT
 class CM_ARP_PUNT
  police 80000 conform-action transmit exceed-action drop

control-plane cef-exception
 service-policy input PM_CPPR_CEF_EXCEPT
```
- **検証方法**:
  - <code>show policy-map control-plane cef-exception</code> を確認。

---

### サンプル 6: EIGRP & LDP 統合保護 CoPP
- **問題**: EIGRP (IP Protocol 88) と LDP (TCP 646) 通信を優先処理とし、その他のパケットを制限せよ。
- **設定例**:
```text
ip access-list extended ACL_EIGRP_LDP
 permit eigrp any any
 permit tcp any any eq 646
 permit tcp any eq 646 any
 permit udp any any eq 646

class-map match-all CM_EIGRP_LDP
 match access-group name ACL_EIGRP_LDP

policy-map PM_COPP_EIGRP_LDP
 class CM_EIGRP_LDP
  police 2000000 conform-action transmit exceed-action transmit
 class class-default
  police 16000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_EIGRP_LDP
```
- **検証方法**:
  - <code>show policy-map control-plane class CM_EIGRP_LDP</code> を確認。

---

### サンプル 7: NTP 認証通信専用 CoPP クラス保護
- **問題**: NTP 通信 (UDP 123) を専用クラスで保護し、帯域制限 64kbps を設定せよ。
- **設定例**:
```text
ip access-list extended ACL_NTP
 permit udp any any eq 123
 permit udp any eq 123 any

class-map match-all CM_NTP
 match access-group name ACL_NTP

policy-map PM_COPP_NTP
 class CM_NTP
  police 64000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_NTP
```
- **検証方法**:
  - <code>show policy-map control-plane class CM_NTP</code> を確認。

---

### サンプル 8: レート制限単位を pps (Packets Per Second) で指定する CoPP
- **問題**: ICMP パケットを 5 pps で制限せよ。
- **設定例**:
```text
ip access-list extended ACL_ICMP_PPS
 permit icmp any any

class-map match-all CM_ICMP_PPS
 match access-group name ACL_ICMP_PPS

policy-map PM_COPP_PPS
 class CM_ICMP_PPS
  police rate 5 pps conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_PPS
```
- **検証方法**:
  - ping 送信時のドロップ動作を確認。

---

### サンプル 9: CoPP での違反トラフィックの Logging 設定
- **問題**: `class-default` で帯域超過してドロップされたパケットログを取得せよ。
- **設定例**:
```text
policy-map PM_COPP_LOG
 class class-default
  police 32000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_LOG
```
- **検証方法**:
  - <code>show policy-map control-plane</code> を確認。

---

### サンプル 10: トラブルシューティング（CoPP ドロップ原因の切り分け）
- **問題**: CoPP 導入後に OSPF ネイバーがダウンした。原因を特定し修正せよ。
- **修正設定例**:
```text
ip access-list extended ACL_ROUTING_FIX
 permit ospf any any

class-map match-all CM_ROUTING_FIX
 match access-group name ACL_ROUTING_FIX

policy-map PM_COPP_FIX
 class CM_ROUTING_FIX
  police 1000000 conform-action transmit exceed-action transmit
 class class-default
  police 8000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP_FIX
```
- **検証方法**:
  - <code>show ip ospf neighbor</code> でネイバーが FULL に復帰することを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**問題**: あるルータで以下の CoPP 設定を投入したところ、BGP ネイバーが周期的に切断される現象が発生した。原因と修正箇所を答えよ。
```text
ip access-list extended ACL_CONTROL
 permit tcp any any eq bgp

class-map CM_CONTROL
 match access-group name ACL_CONTROL

policy-map PM_COPP
 class CM_CONTROL
  police 8000 conform-action transmit exceed-action drop
 class class-default
  police 8000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP
```
**解答・解説**:
- **原因**: ACL に `permit tcp any eq bgp any` (戻りパケット) が含まれておらず、さらに BGP 通信に対して 8 kbps という小さすぎる帯域が設定されているため。
- **修正**: ACL に BGP 両方向および BFD パケットを含め、ポリサーの `exceed-action` を `transmit` に設定するか十分な帯域を確保する。

---

### 問 2 (CPPr サブインターフェイス判定)
**問題**: ルータ宛ての SSH 管理通信と、ルータを経由するパケットのうち TTL=1 のパケットを個別にポリシングしたい。CPPr のどのサブインターフェイスを使用すべきか。
**解答・解説**:
- **SSH 通信 (ルータ自身宛て)**: `control-plane host` に適用。
- **TTL=1 通信 (ルータ経由例外パケット)**: `control-plane transit` に適用。

---

### 問 3 (Design / MQC 要件)
**問題**: CoPP で使用する Access-List 内で `deny` ステートメントを記述した場合の動作として正しいものを選べ。
A) 該当パケットは直ちにルータでドロップされる。  
B) 該当パケットは無制限に CPU へ許可される。  
C) 当該 Class-Map にはマッチせず、後続の Class-Map または class-default で評価される。  
D) 該当パケットは CEF データプレーンでハードウェア転送される。  
**解答・解説**:
- **正解**: **C**
- **解説**: CoPP 用の ACL において `deny` は「この Class-Map のポリシング対象から除外し、次以降のクラスへ引き渡す」動作となる。

---

### 問 4 (トラブルシューティング)
**問題**: 管理者が `control-plane` モード配下で `service-policy output PM_COPP` と入力したところコマンドが拒否された。理由を述べよ。
**解答・解説**:
- **理由**: CoPP は Control Plane への入力トラフィックを保護する機能であるため、`input` 方向のみサポートされている。

---

### 問 5 (実装・検証)
**問題**: CoPP によってドロップされたパケット数を確認するための最も適切な Verification コマンドを答えよ。
**解答・解説**:
- **コマンド**: `show policy-map control-plane`
- **解説**: 各 Class-Map ごとの `conformed` および `exceeded` / `dropped` パケット数がリアルタイムで表示される。

---

## 🔗 参考リソース

* Cisco Technical Notes: Control Plane Policing Implementation Guide
* Cisco IOS XE 17.x QoS Configuration Guide: Control Plane Policing
* Cisco Live BRKSEC-2011: Understanding and Deploying Control Plane Policing
* Cisco Validated Design (CVD): Infrastructure Security Design Guide

---

## 📝 補足（Notes）

### CoPP 導入時の注意点サマリー
1. **プロトコル完全性のチェック**: BGP, OSPF, EIGRP, ISIS, BFD, LDP, HSRP, VRRP, IGMP, PIM のうち自網で動いているものを漏れなく抽出すること。
2. **ACL の `permit` / `deny` ロジックの再確認**: ACL の `deny` ＝ ドロップではない点に注意。
3. **事前動作確認**: 設定直後は `police` の `exceed-action` を `transmit` または `policed-dscp` にし、本番環境での drop 影響がないか十分検証してから `exceed-action drop` に変更すること。


## 🔗 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKSEC-2001: Control Plane Protection**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001)
    *   CoPP と CPPr の深いアーキテクチャ解説。
*   [**BRKENT-2081: Troubleshooting Infrastructure Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081)
    *   CoPP によって正規のトラフィックがドロップされている場合の切り分け手法。
*   [**BRKCRT-1385: The CCIE in an SDN World - Security Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE試験で問われるセキュリティトピックの優先順位。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Security Configuration Guide: Control Plane Policing**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_plcshp/configuration/xe-17/qos-plcshp-xe-17-book/qos-plcshp-cpp.html)
*   [**Control Plane Protection Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_cp_prot/configuration/xe-16/sec-data-cp-prot-xe-16-book.html)

### テクニカルドキュメント・設定例
*   [**Control Plane Policing (CoPP) Implementation Best Practices**](https://www.cisco.com/c/en/us/support/docs/ip/access-lists/43503-contplane-policing.html)
    *   実環境でのホワイトリスト設計の推奨例。
*   [**CoPP Troubleshooting and Verification (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)

---

## 📝 補足
- この学習メモは、CCIE EI 試験においてデバイスの自己防衛機能をいかに論理的に構成するかを網羅しています。ラボ試験では、**`show policy-map control-plane`** を実行した際に、意図したクラスでパケットがカウントされ、かつドロップされるべきものがドロップされているかを確認する習慣をつけることが合格への近道です。


