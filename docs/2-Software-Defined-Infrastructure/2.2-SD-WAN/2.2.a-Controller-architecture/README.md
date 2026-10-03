---
layout: default
title: 2.2.a-Controller-architecture
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.2.a Controller architecture

## 📘 概要

Cisco Catalyst SD-WAN（旧 Viptela SD-WAN）のコントローラアーキテクチャは、SDN（Software-Defined Networking）の基本思想である**「コントロールプレーン（制御面）」、「マネジメントプレーン（管理面）」、「オーケストレーションプレーン（初期認証・仲介面）」、「データプレーン（転送面）」**の完全な機能分離に基づき設計されている。

本項目（2.2.a）では、SD-WAN オーバーレイネットワーク全体の中核をなす 3 つのコントローラコンポーネントである **vManage（Management Plane）**、**vBond（Orchestration Plane）**、および **vSmart（Control Plane）** の内部アーキテクチャ、相互認証シーケンス、通信メカニズム、並びに高可用性（HA）設計について深掘りする。

### 1. 利用目的と役割の分離
* **vManage (Management Plane):** ネットワーク全体の集中設定管理、テンプレート適用（Feature/CLI/Device Templates）、ポリシープッシュ、障害・パフォーマンスモニタリング、アラーム解析、および REST API / Webhook を介した自動化インターフェースを提供する。
* **vBond Orchestrator (Orchestration Plane):** すべての WAN Edge デバイスおよびコントローラ（vManage / vSmart）が最初に接続するオーケストレータ。相互証明書認証（Chassis ID / Serial Number / Authorized Serial List）を実施し、NAT トラバーサル（STUN 機能）により IP アドレス変換状態を特定した後、接続すべき vSmart および vManage の IP リストを通知する。
* **vSmart (Control Plane):** SD-WAN 網の「脳（Brain）」として機能するコントロールプレーン・コントローラ。OMP（Overlay Management Protocol）を実行して vRoute（OMP ルート）、TLOC（Transport Location）ルート、および Service ルートを集約・計算する。セントラル制御ポリシー（Centralized Control Policy）およびデータポリシー（Centralized Data Policy）を評価・配信し、WAN Edge 間の IPsec キー（Diffie-Hellman セッションキー）を媒介して直列鍵交換を自動化する。

---
## 🔑 要点

| 項目 | vManage (Management Plane) | vBond (Orchestration Plane) | vSmart (Control Plane) |
| --- | --- | --- | --- |
| **主要役割** | 集中管理、GUI/API、テンプレート/ポリシー作成・配信 | 初期相互認証、NAT STUN 検出、制御プレーン仲介 | OMP ルーティング計算、ポリシー適用、IPsec 鍵配布 |
| **主要プロトコル** | HTTPS (TCP 443), NETCONF over SSH (TCP 830) | DTLS / TLS (UDP/TCP 12346 / 12346-12446) | OMP, DTLS / TLS (UDP/TCP 12346) |
| **認証方式** | Root CA 証明書, Enterprise/Cisco CA, RBAC | Root CA 証明書 ＋ Authorized Serial List (White-list) | Root CA 証明書 ＋ Organization-Name 一致 |
| **ステート保持** | 永久保持（CouchDB / ClickHouse / ES データベース） | 一時保持（コントロールコネクション成立後は切断） | リアルタイム制御保持（OMP テーブル / TLOC テーブル） |
| **高可用性 (HA)** | 3 ノード以上のクラスタ（Active/Active データベース複製） | 複数 vBond による DNS ラウンドロビン / FQDN 指定 | 複数 vSmart による OMP フルメッシュ / スケーラビリティ |
| **配置要件** | インターナル管理網 / クラウド (1:1 NAT / Private IP) | パブリック IP または 1:1 Static NAT が必須 | パブリック IP または Private IP (WAN 経由可達) |
| **制限事項** | クラスタ構成時は奇数ノード（最低 3 台）推奨 | 重複アクティブ制御コネクションを持たない（STUN 応答後解放） | データパケットの転送（Data Plane 処理）は行わない |

---
## 🏗 動作原理

### 1. コントローラ間および WAN Edge 相互接続アーキテクチャ

Cisco SD-WAN アーキテクチャでは、物理・仮想の WAN Edge ルータ（cEdge / vEdge）は互いに直接 IKE（Internet Key Exchange）ネゴシエーションを行わない。すべてコントロールプレーン（vSmart）を介して OMP 上で IPsec セッションキーおよび TLOC 情報を安全に交換し、データプレーン（IPsec ターミナル）を自動構築する。

```text
                       +-------------------------+
                       |   vManage (Management)  |
                       +------------+------------+
                                    |
            +-----------------------+-----------------------+
            | (NETCONF/HTTPS)                               | (NETCONF/HTTPS)
            v                                               v
+-----------+-----------+                       +-----------+-----------+
|  vBond (Orchestration)|                       |    vSmart (Control)    |
+-----------+-----------+                       +-----------+-----------+
            ^                                               ^
            | (Initial DTLS Auth & STUN)                    | (OMP Peering / DTLS)
            +-----------------------+-----------------------+
                                    |
                                    v
                        +-----------+-----------+
                        |  WAN Edge (Data Plane)|
                        +-----------------------+
```

### 2. NAT Traversal (STUN) メカニズム

WAN Edge がプライベート IP アドレス（NAT ルータ配下）に配置されている場合、vBond は STUN（Session Traversal Utilities for NAT）サーバとして動作する。
1. WAN Edge は UDP 12346（デフォルトソースポート）から vBond（Public IP: 12346）宛に DTLS パケットを送信する。
2. vBond は受信した UDP パケットの「アウターヘッダーの送信元 IP:Port（NAT 変換後の Public IP:Port）」を検知する。
3. vBond は検出した Reflexive Address（Public IP:Port）を payload に含めて WAN Edge へ返答する。
4. WAN Edge は自機の Reflexive TLOC アドレスを認識し、この Public IP:Port 情報を vSmart へ OMP TLOC ルートとして広告することで、NAT 越えの IPsec トンネル（Data Plane）を対向 WAN Edge と確立可能にする。

---
## ⚙ 動作シーケンス

### コントローラおよび WAN Edge オンボーディング（Bringup）シーケンス

```text
[WAN Edge Router]          [vBond Orchestration]          [vSmart Controller]          [vManage Management]
        |                             |                            |                            |
        |--- 1. DNS Lookup (vbond) -->|                            |                            |
        |                             |                            |                            |
        |--- 2. Transient DTLS ------>|                            |                            |
        |    (Chassis ID / Serial)    |                            |                            |
        |                             |-- 3. Verify Serial List ->|                            |
        |                             |   (Mutual Cert Auth)       |                            |
        |                             |                            |                            |
        |<-- 4. IP List Notification -|                            |                            |
        |    (vSmart & vManage IPs)   |                            |                            |
        |    & STUN Public IP/Port    |                            |                            |
        |                             |                            |                            |
        |=== 5. Disconnect Transient DTLS ========================>|                            |
        |                             |                            |                            |
        |-------------------------- 6. Permanent DTLS Connection ->|                            |
        |                            (OMP Session Established)     |                            |
        |                             |                            |                            |
        |------------------------------------------------------- 7. Permanent DTLS/NETCONF ---->|
        |                                                           (Configuration Push)        |
```

1. **ステップ 1 (DNS 解決):** WAN Edge は初期コンフィグまたは PnP / ZTP プロセスより `vbond system-ip` または FQDN（例: `vbond.example.com`）を得て IP アドレスを解決する。
2. **ステップ 2 (vBond との認証):** WAN Edge は vBond に対して 一時的な DTLS コネクション（UDP 12346）を開設し、デバイスの Chassis ID（MAC/UUID）および Client Certificate（TPM/SUDI または Enterprise Certificate）を提示する。
3. **ステップ 3 (シリアルリスト検証):** vBond は提示されたデバイス情報を、vManage から同期されている「Authorized Serial List（許可済みシリアルリスト / ホワイトリスト）」およびルート証明書（Root CA Chain）と照合する。
4. **ステップ 4 (情報応答):** 相互認証が成功すると、vBond は WAN Edge に対して接続すべき vSmart の IP リスト、vManage の IP リスト、並びに STUN により検出した WAN Edge の Reflexive Public IP/Port アドレスを応答する。
5. **ステップ 5 (一時接続の解放):** vBond は目的を果たしたため、WAN Edge との過渡的 DTLS コネクションを切断（Tear down）する。
6. **ステップ 6 (vSmart コントロールセッション確立):** WAN Edge は指定された vSmart に対して永続的な DTLS/TLS コネクションを確立する。相互認証成功後、両者間で OMP（Overlay Management Protocol）ピアリングが UP し、TLOC および OMP ルートの交換が開始される。
7. **ステップ 7 (vManage 管理セッション確立):** 同時に WAN Edge は vManage と永続的な DTLS コネクションを確立し、NETCONF over SSH を介してテンプレートコンフィグの取得およびインベントリ/統計情報の送信を開始する。

---
## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprintで重要なポイント
* **Organization-Name の完全一致:** 全コントローラ（vManage, vBond, vSmart）および WAN Edge 間で `organization-name` の文字列が 1 文字でも異なると、DTLS 相互認証が即座に拒否される（`CRTTMO` / `AUTHFAIL`）。
* **証明書チェーン（Certificate Chain）の順序:** エンタープライズ Root CA（Enterprise CA）を使用する場合、Root CA 証明書および中間 CA（Intermediate CA）証明書がすべてのコントローラに正しくインストールされている必要がある。
* **vBond の Static 1:1 NAT 設定:** vBond が NAT ルータ配下に配置される場合、`system` コンフィグ配下で `vbond <Public-IP> local` および `host-name` の設定と、トランスポートインターフェースでの `nat-external` アプリケーション指定が必須となる。
* **vManage クラスタの奇数ノード構成要件:** CouchDB および ClickHouse データベースのクォーラム（Quorum）維持のため、vManage クラスタは最低 3 ノードの奇数で構成する必要がある。

### 2. ラボ試験で設定させられそうな内容
* GUI (vManage) を使用しない、CLI（`system` / `vpn 0`）からのコントローラ初期オンボーディング設定。
* Root CA 証明書のインストール（`request certificate installer`）。
* WAN Edge 用 Authorized Serial List (スマートライセンス / `serialFile.cci`) の vManage へのアップロードと vBond / vSmart への無効化・同期。
* コントローラ間コントロール接続におけるプロトコル変更（DTLS 優先から TLS への切り替え: `system controller-group-list` または `transport-protocol tls`）。

### 3. よくある設定ミス
* **時間同期（NTP）の欠落:** コントローラ間で NTP による時刻同期が取れていない場合、x.509 証明書の有効期限チェック（NotBefore / NotAfter）で失敗し、コントロールセッションが確立しない。
* **Tunnel-Interface 設定の忘れ:** コントローラの VPN 0 外部対向インターフェースで `tunnel-interface` コマンドを設定し忘れると、DTLS カプセル化パケットを受信拒否する。
* **`encapsulation ipsec` の未設定:** WAN Edge の tunnel-interface で `encapsulation ipsec` または `encapsulation gre` を明示しないと、コントロールコネクションが UP してもデータプレーン（TLOC）が構築されない。

### 4. showコマンドから状態を判断するポイント
* `show control connections`: 各コントローラおよび WAN Edge 間で DTLS/TLS 接続が `state = UP` になっているか確認。
* `show control local-properties`: 自機器の Certificate status（`INSTALLED`）、Chassis-ID、Serial-num、Organization-Name、および vBond IP が正しく認識されているか確認。
* `show control valid-vsmarts` / `show control valid-vended-edges`: コントローラが保持している有効な vSmart および WAN Edge のシリアル番号リストを確認。

---
## 🛠 設定方法

### 1. vManage 初期 CLI オンボーディングコンフィグ（CLI モード）

```bash
! --- vManage 1 システムコンフィグ ---
system
 host-name          vManage1
 system-ip          1.1.1.1
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346
!

! --- VPN 0 (Transport VPN) コンフィグ ---
vpn 0
 interface eth1
  ip address 192.168.1.1 255.255.255.0
  tunnel-interface
   encapsulation ipsec
   allow-service all
  !
  no shutdown
 !
 ip route 0.0.0.0 0.0.0.0 192.168.1.254
!

! --- VPN 512 (Management VPN) コンフィグ ---
vpn 512
 interface eth0
  ip address 10.1.1.1 255.255.255.0
  no shutdown
 !
 ip route 0.0.0.0 0.0.0.0 10.1.1.254
!
```

### 2. vBond Orchestrator 初期 CLI コンフィグ

```bash
! --- vBond システムコンフィグ ---
system
 host-name          vBond1
 system-ip          1.1.1.100
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346 local
!

! --- VPN 0 トランスポート & NAT トラバーサルコンフィグ ---
vpn 0
 interface GigabitEthernet1
  ip address 192.168.1.100 255.255.255.0
  tunnel-interface
   encapsulation ipsec
   allow-service all
  !
  no shutdown
 !
 ip route 0.0.0.0 0.0.0.0 192.168.1.254
!
```

### 3. vSmart Control Plane 初期 CLI コンフィグ

```bash
! --- vSmart システムコンフィグ ---
system
 host-name          vSmart1
 system-ip          1.1.1.2
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346
!

! --- VPN 0 トランスポートコンフィグ ---
vpn 0
 interface eth1
  ip address 192.168.1.2 255.255.255.0
  tunnel-interface
   encapsulation ipsec
   allow-service all
  !
  no shutdown
 !
 ip route 0.0.0.0 0.0.0.0 192.168.1.254
!
```

---
## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| コントロール接続状態の確認 | `<code>show control connections</code>` |
| 自ルータの証明書および組織名確認 | `<code>show control local-properties</code>` |
| 有効な vSmart 一覧の確認 | `<code>show control valid-vsmarts</code>` |
| 有効な WAN Edge (White-list) 一覧確認 | `<code>show control valid-vended-edges</code>` |
| OMP ピアセッション状態の確認 | `<code>show omp peers</code>` |
| OMP 学習ルート（vRoute）の確認 | `<code>show omp routes</code>` |
| OMP TLOC 情報の確認 | `<code>show omp tlocs</code>` |
| インストール済み証明書のステータス確認 | `<code>show certificate installed</code>` |
| コントロールセッション履歴（切断理由） | `<code>show control connection-history</code>` |
| コントローラトラブルシューティングログ | `<code>show log /var/log/syslog</code>` |

---
## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| コントロール接続が確立せず `CRTTMO` エラーとなる | コントローラ間で `organization-name` が不一致 | `<code>show control local-properties</code>` | 全コントローラで `system organization-name` の文字列を完全一致させる |
| vBond との接続時 `BIDNXT` / `AUTHFAIL` が発生 | WAN Edge のシリアル番号が vManage の Authorized Serial List に未登録 | `<code>show control valid-vended-edges</code>` | vManage から最新の `serialFile.cci` をアップロードし、コントローラへ同期 |
| DTLS セッションが `CERT_FAIL` で切断される | ルート証明書（Root CA Chain）が未インストール、または時刻が不一致 | `<code>show certificate status</code>` <br> `<code>show clock</code>` | NTP を設定して時刻を合致させ、`request certificate installer` で Root CA を追加 |
| vBond 配下の WAN Edge が vSmart の IP を取得できない | vBond 上で `vbond <IP> local` の設定が漏れている | `<code>show control local-properties</code>` | vBond の `system` コンフィグで `local` キーワードを付与する |
| コントロール接続は UP するが OMP ピアが UP しない | vSmart と Edge 間で OMP プロトコルが無効化、または Site-ID 重複 | `<code>show omp peers</code>` | `omp no shutdown` を確認し、重複しない `site-id` を再割り当てする |

---
## ⚠ 制限事項

1. **vManage クラスタのクォーラム制約:**
   * vManage クラスタを組む場合、データベースの同期整合性を保つため、最小 3 台の奇数ノードが強く推奨される。2 ノード構成では 1 台障害時にスプリットブレインが発生し、書き込み不可となる。
2. **証明書タイプ変更時の全再オンボーディング:**
   * コントローラ群の証明書インフラ（例: Symantec から Private Root CA）を変更する場合、すべての WAN Edge とコントロールコネクションが一時切断されるため、計画停電窓での実施が必要。
3. **vBond のステートレス性制限:**
   * vBond は永続的な OMP ルーティングテーブルやネットワーク全体のトポロジー状態を保持しない。そのため、vBond 障害時でも既存の Edge-vSmart 間コントロール接続および WAN Edge 間 IPsec トンネルは維持される。

---
## 🔄 他技術との関連

* **Cisco SD-Access 統合 (2.1.e):** SD-WAN コントローラ（vManage）は SD-Access Catalyst Center と REST API 経由で連携し、SD-Access の Virtual Network (VN) を SD-WAN の Service VPN へ動的マッピングする。
* **PKI / Certificate Infrastructure:** X.509v3 証明書を用いた相互 TLS/DTLS 認証。EST（Enrollment over Secure Transport）または Manual SCEP による証明書自動更新。
* **NAT Traversal (STUN / TURN):** プライベート IP 環境に配置された WAN Edge が パブリック IP アドレスを動的検知し、IPsec トンネルを NAT 越しに自動構築する基盤技術。

---
## 🧩 比較表

### コントローラコンポーネント役割比較

| 比較項目 | vManage (Management) | vBond (Orchestrator) | vSmart (Control) |
| --- | --- | --- | --- |
| **主要プレーン** | Management Plane | Orchestration Plane | Control Plane |
| **主用データストア** | CouchDB / ClickHouse | なし (Stateless) | RAM (OMP Routing Table) |
| **制御対象プロトコル** | NETCONF / REST API / HTTPS | DTLS (STUN) | OMP / DTLS / TLS |
| **障害時の影響** | 構成変更・モニタリング不可（データ転送は継続） | 新規 Edge オンボーディング不可（既存通信は影響なし） | 新しい経路変更の即時追従不可（既存 IPsec トンネルは維持） |
| **冗長化方式** | Active/Active Cluster (最少 3 ノード) | DNS Round-Robin (複数 FQDN/IP) | OMP Multi-vSmart (Scale-out) |

---
## 💡 ベストプラクティス

1. **コントローラの二重化および地理的分散配置:**
   * vSmart および vBond は異なるデータセンターまたはアベイラビリティゾーンに分散配置し、DNS FQDN を用いて vBond アドレス（`vbond.example.com`）を冗長定義する。
2. **NTP 設定の先頭化:**
   * すべてのコントローラのプロビジョニング手順において、証明書インストール前に必ず信頼できる NTP サーバへの同期を完了させる。
3. **コントロールプレーンの TLS 切り替え:**
   * コントローラ間（vManage - vSmart - vBond）のコントロールセッションは、不安定な WAN 回線環境下では UDP ベースの DTLS から TCP ベースの TLS へ変更することで、再送制御による接続安定性を向上させる。

---
## 📝 ラボ学習・設定サンプル例

### Lab 01: コントローラ Organization-Name 及び System 設定

* **問題:** vManage1、vBond1、および vSmart1 の初期セットアップにおいて、組織名（Organization-Name）「`CCIE-EI-SDWAN-LAB`」を定義し、システム IP および Site-ID を正しくアタッチしなさい。
* **要件:**
  1. Organization-Name: `CCIE-EI-SDWAN-LAB`
  2. Site-ID: `100`
  3. vManage1 System IP: `1.1.1.1`
  4. vSmart1 System IP: `1.1.1.2`
  5. vBond1 System IP: `1.1.1.100` (Port 12346)
* **設定例:**

```bash
! --- vManage1 ---
system
 host-name          vManage1
 system-ip          1.1.1.1
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346
!

! --- vSmart1 ---
system
 host-name          vSmart1
 system-ip          1.1.1.2
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346
!

! --- vBond1 ---
system
 host-name          vBond1
 system-ip          1.1.1.100
 site-id            100
 organization-name  "CCIE-EI-SDWAN-LAB"
 vbond 192.168.1.100 port 12346 local
!
```

* **検証方法:**
  各コントローラで `show control local-properties` を実行し、`organization-name` が一致していることを確認する。

```bash
vManage1# show control local-properties | include organization-name
organization-name        CCIE-EI-SDWAN-LAB
```

---

### Lab 02: Enterprise Root CA 証明書インストールフロー

* **問題:** vManage1 上で作成した CSR（Certificate Signing Request）を自作 Enterprise Root CA で署名し、Root CA チェーンとともにインストールしなさい。
* **要件:**
  1. Root CA ファイル: `rootCA.pem`
  2. 署名済み証明書ファイル: `vmanage.crt`
  3. CLI コマンドにより認証局チェーンを正常にバインドすること。
* **設定例:**

```bash
! --- vManage 上での Root CA インストール手順 ---
! 1. Root CA のインストール
request certificate installer install /vmanage-storage/rootCA.pem

! 2. 署名済み vManage 証明書のインストール
request certificate installer install /vmanage-storage/vmanage.crt
```

* **検証方法:**

```bash
vManage1# show certificate installed
vManage1# show certificate status
```

---

### Lab 03: vBond パブリック Static 1:1 NAT 設定

* **問題:** vBond1 がプライベート IP（`192.168.1.100`）で動いており、ルータでパピック IP（`203.0.113.100`）へ Static NAT されている環境において、NAT 外部アドレスを定義しなさい。
* **要件:**
  1. Internal IP: `192.168.1.100`
  2. External Public IP: `203.0.113.100`
  3. WAN Edge から正しく STUN 応答が返送されるように設定すること。
* **設定例:**

```bash
! --- vBond1 ---
system
 vbond 203.0.113.100 port 12346 local
!
vpn 0
 interface GigabitEthernet1
  ip address 192.168.1.100 255.255.255.0
  tunnel-interface
   encapsulation ipsec
   nat-external
   allow-service all
  !
 !
!
```

* **検証方法:**
  WAN Edge 側で `show control local-properties` を実行し、Reflexive アドレスが `203.0.113.100` として認識されているか確認する。

---

### Lab 04: WAN Edge Authorized Serial List (White-list) の vManage 同期

* **問題:** vManage1 にプロビジョニングファイル `serialFile.cci` を読み込み、vBond および vSmart へ無効化なしでシリアルリストを伝搬させなさい。
* **要件:**
  1. vManage CLI からシリアルリストファイルをロードすること。
  2. vSmart および vBond へ同期完了していることを確認すること。
* **設定例:**

```bash
! --- vManage1 CLI コマンド ---
request download-whitelist /vmanage-storage/serialFile.cci
request send-whitelist
```

* **検証方法:**

```bash
vSmart1# show control valid-vended-edges
vBond1# show control valid-vended-edges
```

---

### Lab 05: コントローラ間コントロールプロトコルの TLS 変更

* **問題:** 不安定な WAN 環境において、vManage1 と vSmart1 間のコントロールセッションプロトコルを UDP (DTLS) から TCP (TLS) へ変更しなさい。
* **要件:**
  1. 接続プロトコルとして TLS を指定すること。
  2. ポート番号 23456 を使用すること。
* **設定例:**

```bash
! --- vManage1 / vSmart1 ---
system
 controller-group-list 1
 transport-protocol tls
!
```

* **検証方法:**

```bash
vManage1# show control connections
! Protocol 列が "tls" と表示されていることを確認
```

---

### Lab 06: Multi-vSmart による OMP フルメッシュ接続とアフィニティグループ

* **問題:** 2 台の vSmart（vSmart1: `1.1.1.2`, vSmart2: `1.1.1.3`）を配置し、cEdge ルータが両方の vSmart と同時にコントロール接続を維持するよう設定しなさい。
* **要件:**
  1. cEdge ルータで最大 2 つの vSmart 接続（`max-controllers 2`）を許可すること。
* **設定例:**

```bash
! --- cEdge (WAN Edge) ---
system
 max-controllers 2
!
```

* **検証方法:**

```bash
cEdge1# show control connections | include vSmart
! 2 行の vSmart 接続が UP ステートで表示されることを確認
```

---

### Lab 07: コントローラでの NTP 同期設定

* **問題:** すべてのコントローラで NTP サーバ `10.1.1.254` への同期を設定し、タイムゾーンを UTC に統一しなさい。
* **要件:**
  1. NTP Server: `10.1.1.254` (VPN 512 または VPN 0)
  2. Timezone: `UTC`
* **設定例:**

```bash
! --- vManage / vSmart / vBond 共通 ---
system
 clock timezone UTC
!
vpn 512
 ntp
  server 10.1.1.254
  vpn 512
  source eth0
 !
!
```

* **検証方法:**

```bash
vManage1# show clock
vManage1# show ntp status
```

---

### Lab 08: WAN Edge オンボーディング初期設定 (cEdge)

* **問題:** Catalyst 8000v (cEdge1) を CLI からオンボーディングするために必要な最小限のコントロールプレーンパラメータを設定しなさい。
* **要件:**
  1. Organization-Name: `CCIE-EI-SDWAN-LAB`
  2. vBond IP: `203.0.113.100`
  3. Tunnel Interface: GigabitEthernet1 (VPN 0)
* **設定例:**

```bash
! --- cEdge1 (Cisco IOS-XE SD-WAN) ---
system
 host-name cEdge1
 system-ip 10.255.255.1
 site-id 200
 organization-name "CCIE-EI-SDWAN-LAB"
 vbond 203.0.113.100 port 12346
!
sdwan
 interface GigabitEthernet1
  tunnel-interface
   encapsulation ipsec
   color biz-internet
   allow-service all
  !
 !
!
interface GigabitEthernet1
 vrf forwarding 0
 ip address 192.0.2.1 255.255.255.0
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 192.0.2.254
```

* **検証方法:**

```bash
cEdge1# show sdwan control connections
cEdge1# show sdwan control local-properties
```

---

### Lab 09: コントローラ間コントロールセッションの履歴診断

* **問題:** 切断されたコントロールセッションの原因を調査するため、コントロール接続履歴（Connection History）を確認しなさい。
* **要件:**
  1. 過去の切断理由コード（Tear down reason）を特定すること。
* **設定例・実行コマンド:**

```bash
vManage1# show control connection-history
```

* **検証方法:**
  出力結果の `RX TR REASON` または `TX TR REASON` 列を確認し、`CRTTMO` (Certificate Timeout / Mismatch) や `BIDNXT` (Board ID Not Found) などの要因を特定する。

---

### Lab 10: vManage クラスタノード同期状態の確認

* **問題:** 3 ノード構成の vManage クラスタにおいて、データベース（CouchDB / Application Server）の動相同期ステータスを検証しなさい。
* **要件:**
  1. クラスタ内のすべての vManage ノードが `Replicated` および `In Sync` であることを確認すること。
* **設定例・実行コマンド:**

```bash
vManage1# show cluster status
vManage1# show nms application-server status
```

* **検証方法:**
  全ノードのステータスが `REPLICATED` になっていることを確認する。

---
## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
以下の `cEdge1` において、`show sdwan control connections` を実行したところ、`vBond` との接続は成立しているが `vSmart` および `vManage` とのコントロール接続が全く確立しない。コンフィグ上の原因として最も可能性が高いものを 1 つ選べ。

```bash
system
 host-name cEdge1
 system-ip 10.1.1.1
 site-id 10
 organization-name "CCIE-LAB-ORG"
 vbond 203.0.113.100 port 12346
!
sdwan
 interface GigabitEthernet1
  tunnel-interface
   color public-internet
   allow-service all
  !
 !
!
```

* A) `vbond` コマンドで `local` キーワードが欠落しているため。
* B) `tunnel-interface` 配下で `encapsulation ipsec` が指定されていないため。
* C) `organization-name` にダブルクォーテーションが含まれているため。
* D) `site-id` が vSmart と異なっているため。

**正解: B**  
**解説:**  
`tunnel-interface` 配下で `encapsulation ipsec`（または `encapsulation gre`）が定義されていない場合、cEdge は vBond との過渡的 DTLS コネクションは確立できるものの、データ/コントロール用のトンネルカプセル化形式が確定しないため、vSmart や vManage との永続的なコントロール接続をオープンできない。

---

### 問 2 (トラブルシューティング)
新規オンボーディング中の WAN Edge において、`show control connection-history` を実行したところ、以下のエラーコードが記録され、接続が失敗していた。

```text
PEER TYPE   PEER IP        ERROR CODE   REASON
-----------------------------------------------------------------------
vbond       203.0.113.100  ERR_BIDNXT   Board ID not found in white-list
```

このエラーを解消するための適切な対処方法はどれか。

* A) WAN Edge ルータ上で `system organization-name` を修正する。
* B) vManage 上で Root CA 証明書を再インストールする。
* C) vManage 上で Authorized Serial List（`serialFile.cci`）を最新化し、コントローラ群へ同期する（`send-whitelist`）。
* D) vBond 上で `nat-external` 設定を追加する。

**正解: C**  
**解説:**  
`ERR_BIDNXT` (Board ID Next) は、提示された WAN Edge の Chassis ID / Serial Number が vBond/vSmart の保持する許可済みリスト（White-list / Authorized Serial List）内に存在しないことを意味する。vManage から最新のシリアルリストを同期することで解消する。

---

### 問 3 (Design)
Cisco SD-WAN コントローラアーキテクチャの設計において、vBond Orchestrator をプライベート IP アドレス空間（NAT ルータの背面）に配置する場合の必須設計要件として正しいものを 2 つ選べ。

* A) vBond の `system` コンフィグにおいて `vbond <Public-IP> port 12346 local` を指定する。
* B) vBond と vSmart の間で OMP ピアリングを常時確立する。
* C) 外側のルータで vBond のプライベート IP に対する 1:1 Static NAT を設定し、トンネルポートで `nat-external` を有効化する。
* D) vBond の VPN 512 インターフェース上で STUN サービスを有効化する。
* E) vBond 上で最低 3 ノードの CouchDB クラスタを構成する。

**正解: A, C**  
**解説:**  
vBond を NAT 配下に配置する場合、WAN Edge がパブリック側からアクセスできるように 1:1 Static NAT を適用し、vBond 側の `system` コンフィグでパブリック IP を指定（`local` 付与）するとともに、VPN 0 トンネルインターフェースで `nat-external` を指定する必要がある。

---

### 問 4 (実装・検証)
コントローラ間認証において、エンタープライズ Root CA（Private CA）を使用する場合の検証コマンドとして、自機器に正しく Root CA チェーンがロードされていることを確認するための最も適切なコマンドはどれか。

* A) `show omp peers`
* B) `show certificate installed`
* C) `show control valid-vsmarts`
* D) `show sdwan reboot-history`

**正解: B**  
**解説:**  
`show certificate installed`（または `show certificate status`）を実行することで、自機器にインストールされている Root CA 証明書、コントローラ証明書、および有効期限（Expiration date）を確認できる。

---

### 問 5 (トラブルシューティング)
vSmart コントローラと cEdge ルータ間でコントロールセッション（DTLS）は `UP` となっているが、`show omp peers` の出力が空であり、オーバーレイ経路が全く学習されない。考えられる原因として最も適切なものはどれか。

* A) cEdge と vSmart 間で `organization-name` が不一致である。
* B) vManage 上で OMP プロトコルがシャットダウン（`omp shutdown`）されているか、または Site-ID 重複防止機能によって阻害されている。
* C) vBond がダウンしているため。
* D) WAN Edge 上で `nat-external` が設定されていないため。

**正解: B**  
**解説:**  
コントロール接続（DTLS）が `UP` になっているにもかかわらず OMP ピアが成立しない場合、DTLS 上で動作する OMP プロトコル自体の無効化（`shutdown`）、またはミスマッチ/設定不備が原因である。`organization-name` の不一致や vBond ダウンの場合は、そもそも DTLS コネクション自体が UP しない。

---
## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Controller Deployment Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/sdwan-agent-kb/sdwan-controller-deployment-guide.html)
* [Cisco Catalyst SD-WAN Control Plane and Onboarding Architecture Guide](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sdwan-bo-architecture-guide.html)
* [Cisco Live BRKKNO-2023: Deep Dive into Cisco SD-WAN Controller Architecture](https://www.ciscolive.com/)
* [Cisco Technical Notes: Troubleshooting SD-WAN Control Connections](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)
* [Cisco Catalyst SD-WAN Command Reference](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/command/reference/b_sdwan_cr.html)

---

## 📝 補足（Notes）

* **DTLS/TLS ポート番号のオフセット計算:**
  * vBond / vSmart / vManage のデフォルトポートは `12346`。
  * 同一 IP アドレス上で複数インスタンスを動かす場合、ポート番号は `12346`、`12356`、`12366` のように `+10` ずつ自動オフセットされる。
* **vBond のオーケストレーション動作における一時接続:**
  * WAN Edge が vBond に接続する際、確立される DTLS コネクションは一時的（Transient）なものである。`show control connections` を vBond 上で常時監視していても、正常オンボーディング完了後の WAN Edge はリストから消えるのが正常動作である。

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - コントロールコネクションと証明書のトラブル解決。
*   [**BRKENT-2296: Designing Cisco SD-WAN Controllers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2296) - コントローラの配置設計と冗長化。
*   [**BRKRST-2559: 3 Steps to Design Cisco SD-WAN On-Prem**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2559) - オンプレミス環境での構築手順。

### Configuration ガイド
*   [**Cisco SD-WAN Controller Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sd-wan-controller-deployment-guide.html)
*   [**Cisco SD-WAN Overlay Management Protocol (OMP) Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-routing-omp.html)

### テクニカルドキュメント・設定例
*   [**SD-WAN Control Connection Troubleshooting (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)
*   [**Organization Name and Certificate Validation in SD-WAN**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/215321-sd-wan-certificate-management-and-troubl.html)

---

## 📝 補足
- この学習メモは、SD-WAN の「心臓部」であるコントローラ群の動作を、CCIE ラボ試験での実技・トラブルシュート視点で整理したものです。特に **証明書の信頼（Certificate Trust）** と **OMP の正常性** を CLI で即座に判断できるようにすることが、試験合格の鍵となります。


