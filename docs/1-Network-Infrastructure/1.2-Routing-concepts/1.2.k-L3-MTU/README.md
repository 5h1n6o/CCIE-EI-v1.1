# 1.2.k L3 MTU

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験において、IPデータプレーン転送・カプセル化オーバーヘッド・動的ルーティング隣接関係（OSPF/BGP等）の安定稼働を左右する重要基盤技術である **L3 MTU (Layer 3 Maximum Transmission Unit)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**L3 MTU (Layer 3 Maximum Transmission Unit)** とは、IPレイヤ（ネットワーク層）において、単一のパケット（IPヘッダー ＋ L4ヘッダー ＋ ペイロード）としてインターフェイスから送出または受信可能な **「最大IPパケットサイズ（バイト単位）」** を定義するパラメータです [21, 1.1.a (iii), 1.2.k]。

デフォルトのイーサネット環境における L3 MTU は **1500 バイト** です。L3 MTU を超えるサイズのパケットがインターフェイスに到達した場合、IPヘッダー内の **DF Bit (Don't Fragment Bit)** の状態およびルータの転送制御ポリシーに従って **「IPフラグメンテーション（パケット分割）」** または **「ICMP Type 3 Code 4 (Fragmentation Needed) によるパケット破棄・通知」** が行われます。

### 主な利用目的と適用シーン
1. **オーバーヘッドカプセル化環境におけるフラグメンテーション防止:** GRE, IPsec, VXLAN, MPLS L3VPN, SD-Access (VXLAN + LISP) などのトンネリング技術導入時、カプセル化ヘッダー追加に伴うパケット長超過とCPU主導のフラグメンテーション（またはスループット劇的低下）を防ぐ。
2. **ルーティングプロトコル隣接関係の正常確立:** OSPF や IS-IS などのリンクステートルーティングプロトコルにおいて、データベース同期パケット（OSPF DBDパケットなど）の送受信時に両端の L3 MTU不整合によるネゴシエーション停止（ExStart/Exchangeステートでのハング）を防ぐ [21, 1.2.k, 1.4.a]。
3. **Path MTU Discovery (PMTUD) と TCP MSS 調整:** 経路上の最小 MTU を動的に検知し、エンドツーエンドの TCP 通信において `ip tcp adjust-mss` を用いて MSS (Maximum Segment Size) を事前に小さく書き換えることで、Path 全体でのフラグメント発生を未然に遮断する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **定義** | 該当インターフェイス上で処理・送信可能な最大の L3 IP パケットサイズ（デフォルト: 1500 bytes） |
| **制御コマンド** | <code>ip mtu &lt;bytes&gt;</code> (IP固有MTU) / <code>mtu &lt;bytes&gt;</code> (インターフェイスL3 MTU) / <code>ipv6 mtu &lt;bytes&gt;</code> [21, 1.2.k] |
| **主な用途** | カプセル化（GRE/IPsec/VXLAN/MPLS）時のオーバーヘッド補正、OSPF/BGP/ISIS ネイバーの安定確立、TCP MSS書き換え |
| **メリット** | トンネルオーバーヘッドを考慮したジャンボフレーム化によりフラグメンテーション（CPU処理負荷）を全排除し、スループット最大化 |
| **デメリット** | 経路上の1台でも L3 MTU / IP MTU 設定にミスマッチがあると、DFビット付きパケット（Path MTU DiscoveryパケットやHTTPS通信等）がサイレントドロップ（ブラックホール化） |
| **対応機種** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v / ISR / ASR / CSR1000v などの全 Cisco IOS-XE デバイス |
| **制限事項** | <code>ip mtu</code> はインターフェイスの物理/論理 <code>mtu</code>（L3 Interface MTU）を超える値を設定できない（<code>ip mtu</code> $\le$ <code>mtu</code>）。 |
| **設計上の注意点** | L2 MTU（スイッチフレームサイズ） $\ge$ L3 MTU (IPパケットサイズ) + L2/カプセル化ヘッダー（18B＋α）を死守すること。 |

---

## 🏗 動作原理

L3 MTU とパケット処理（フラグメンテーション vs PMTUD）の内部判定ロジックを示します。

```text
[ インターフェイスへIPパケットが到着 (サイズ: Packet_Size) ]
                           │
                           ▼
          ＜ Packet_Size  >  L3 MTU ? ＞
                       /       \
                     (No)     (Yes)
                      /         \
                     ▼           ▼
             [ 通常転送 ]    ＜ DF Bit (Don't Fragment) == 1 ? ＞
                            /                         \
                          (No)                       (Yes)
                          /                             \
                         ▼                               ▼
            [ IPフラグメンテーション実行 ]         [ パケットをドロップ ]
            - パケットをL3 MTUサイズに分割               │
            - CPU/ASICで各片にIPヘッダー付与             ▼
            - 送出                              [ ICMP Type 3 Code 4 送信 ]
                                                - "Fragmentation Needed and DF Set"
                                                - パケット送信元へ Next-Hop MTU を通知
```

### 1. IP Fragmentation（IP分割処理）
* パケットサイズが送出インターフェイスの L3 MTU を超え、かつ **DF Bit = 0** の場合、ルータはパケットを L3 MTU に収まる複数のフラグメントに分割します。
* 各フラグメントには元の IP ヘッダー情報が複写され、`Flags (MF: More Fragments)` および `Fragment Offset` フィールドが更新されます。
* 再構築（Reassembly）は途中のルータではなく、**最終宛先ホスト** で行われます。

### 2. Path MTU Discovery (PMTUD) と ICMP Type 3 Code 4
* 送信元ホストは通常、IPヘッダーの **DF Bit = 1** に設定してパケットを送出します。
* 途中のルータで L3 MTU 超過が発生すると、パケットは破棄され、送信元へ **ICMP Destination Unreachable - Fragmentation Needed (Type 3, Code 4)** が返送されます。このICMPパケット内に「送出不可となったインターフェイスの L3 MTU 値」が含まれており、送信元ホストは送信パケットサイズをその MTU に合致するよう動的に縮小します。

### 3. 各種プロトコル・カプセル化のオーバーヘッド一覧

| カプセル化・ヘッダー種類 | 追加オーバーヘッド (バイト) | 1500B イーサネットでの推奨 IP MTU / TCP MSS |
| :--- | :--- | :--- |
| **IPv4 Header** | 20 bytes | IP MTU 1500 ➔ TCP MSS 1460 ($1500 - 20 - 20$) |
| **IPv6 Header** | 40 bytes | IPv6 MTU 1500 ➔ TCP MSS 1440 ($1500 - 40 - 20$) |
| **802.1Q Tag (VLAN)** | 4 bytes (L2) | L2 MTU 1504 以上を確保 [21, 1.1.a (iii), 1.1.c (ii)] |
| **802.1ad (QinQ)** | 8 bytes (L2) | L2 MTU 1508 以上を確保 |
| **GRE Tunnel** | 24 bytes (20B IP + 4B GRE) | IP MTU 1476 ➔ <code>ip tcp adjust-mss 1436</code> |
| **IPsec Tunnel Mode (ESP)** | 50〜60+ bytes (暗号アルゴリズムに依存) | IP MTU 1440 ➔ <code>ip tcp adjust-mss 1400</code> |
| **GRE + IPsec (VTI / DMVPN)** | 約 72〜76 bytes | IP MTU 1424 ➔ <code>ip tcp adjust-mss 1384</code> |
| **VXLAN (UDP/IP/VXLAN)** | 50 bytes (14B Ethernet + 20B IP + 8B UDP + 8B VXLAN) | アンダーレイ L3 MTU 1550 以上（または オーバーレイ MSS 1410） |
| **SD-Access (VXLAN + LISP + IPsec)** | 50〜100+ bytes | アンダーレイ L3 MTU 9000（Jumbo Frame）推奨 |

---

## ⚙ 動作シーケンス

### OSPF ネイバー確立時における L3 MTU チェックの動作シーケンス

OSPFv2 / OSPFv3 では、Database Description (DBD) パケット内に送出ポートの **L3 MTU 値** が記載されます [21, 1.2.k, 1.4.a]。

```text
[ Router A (MTU: 1500) ]                            [ Router B (MTU: 1400) ]
        │                                                     │
        │ ─── 1. Init / 2-Way (Hello Exchange) ─────────────► │ (2-Way 確立)
        │                                                     │
        │ ─── 2. DBD (Init, Seq=100, MTU=1500) ──────────────►│
        │                                                     │ Compare MTU:
        │                                                     │ Received MTU(1500) > Local MTU(1400)
        │                                                     │ ➔ DBD 破棄 / ExStart に固定
        │                                                     │
        │ ◄── 3. DBD (Init, Seq=200, MTU=1400) ───────────────│
        │ Compare MTU:                                        │
        │ Received MTU(1400) <= Local MTU(1500)               │
        │ ➔ 受け入れ可能だが、Bからの返答が来ない             │
        │                                                     │
  [ State: ExStart / Exchange ]                        [ State: ExStart / Exchange ]
  (DBD の再送が繰り返され、フルアジャセンシー (FULL) に到達できずタイムアウトを繰り返す)
```

1. **Hello ネゴシエーション:** Hello パケットには MTU 値は含まれないため、`2-Way` ステートまでは正常に完了します。
2. **DBD パケット交換 (ExStart / Exchange):**
   * Router A は `MTU=1500` と記載された DBD を送信。
   * Router B は自身の L3 MTU (1400) より大きい `MTU=1500` を受信するため、この DBD パケットを無視・破棄します。
3. **アジャセンシー停止:** Router B からの応答が途絶えるため、両ルータは **`ExStart`** または **`Exchange`** ステートでハングし、`FULL` ステートに移行できません [21, 1.2.k, 1.4.a]。
4. **回避策:** 両端の L3 MTU を一致させるか、インターフェイス配下で **`ip ospf mtu-ignore`** を設定して DBD 内の MTU チェックをバイパスします [21, 1.2.k, 1.4.a]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、L3 MTU は単独で問われるだけでなく、**DMVPN, IPsec, SD-Access, OSPF, BGP, GRE などの各種トピックに複合トラブルとして潜み**、受験者の得点を阻む主要原因となります [21, 1.1.a (iii), 1.2.k, 1.4.a, 1.5.a, 3.3.a]。

### 1. 「L3 MTU」 vs 「IP MTU」 vs 「L2 MTU (System MTU)」のコマンド概念の完全区別
* **`mtu <bytes>` (Interface L3 MTU):** 
  * インターフェイス配下で設定。L3のIPパケットサイズ上限を決定します [21, 1.2.k]。
  * `ip mtu` が未設定の場合、この `mtu` 値が自動的に IP MTU として継承されます。
* **`ip mtu <bytes>` (IP MTU Override):**
  * IPレイヤ固有の最大パケットサイズを明示的に指定します [21, 1.2.k]。
  * 条件: **`ip mtu` の値は `mtu` (Interface L3 MTU) 以下でなければなりません**（`ip mtu` $>$ `mtu` となる設定はCLIで却下されます）。
* **`system mtu <bytes>` / `mtu <bytes>` (Switch L2 Frame Size):**
  * Catalyst スイッチ等で L2 フレーム全体（Destination MAC + Source MAC + Type + Payload + FCS）の長さを制御 [21, 1.1.a (iii)]。

### 2. OSPF `ExStart` ハングと `ip ospf mtu-ignore` の作法
* **出題パターン:**
  「R1 と R2 間で OSPFv2 ネイバーが確立せず、`ExStart` 状態を繰り返している。R1 側の物理 MTU（1500）を変更することなく、かつ OSPF ネイバーを `FULL` 状態に復旧させよ」 [21, 1.2.k, 1.4.a]
* **解法:**
  * 対向の R2 側の MTU が 1400 など小さくなっている、あるいはトンネルインターフェイス等で MTU 不一致が発生している。
  * R1 または R2（もしくは両方）の OSPF 処理インターフェイス配下で以下を設定する。
    ```bash
    interface GigabitEthernet1/0/1
     ip ospf mtu-ignore
    ```

### 3. TCP MSS 調整 (`ip tcp adjust-mss`) の計算式と設定適用場所
* **出題パターン:**
  「DMVPN / IPsec トンネル経由の Web (HTTPS) 通信において、小容量パケット（PINGやSSH）は通過するが、大容量のファイル転送やWebページ閲覧が途中でハングアップ（ブラックホール化）する。ルータ側でフラグメンテーションの発生を未然に防止する設定を追加せよ」 [21, 1.2.k, 3.3.a]
* **技術的計算根拠:**
  * イーサネット標準 L3 MTU = 1500 bytes
  * GRE + IPsec オーバーヘッド = 約 72 bytes ➔ トンネル IP MTU = $1500 - 72 = 1428$ bytes
  * TCP ヘッダー(20B) + IP ヘッダー(20B) = 40 bytes
  * 推奨 TCP MSS = $1428 - 40 = 1388$ バイト（安全値として `1360` や `1380` を指定）
* **適用コマンド:**
  ```bash
  interface Tunnel0
   ip mtu 1428
   ip tcp adjust-mss 1388
  ```
  *(※ `ip tcp adjust-mss` は、TCP SYN パケット内の MSS オプションフィールドを通過時にインラインで書き換えます)*

### 4. PMTUD (Path MTU Discovery) 阻害と ICMP Type 3 Code 4 ドロップ問題
* セキュリティ ACL や CoPP (Control Plane Policing) で誤って ICMP（特に ICMP Type 3 / Code 4）を全破棄（`deny icmp any any`）していると、PMTUD が機能せず、DFビット付き大容量パケットが静かに破棄される **「PMTUD Black Hole」** が発生します [21, 1.2.k, 4.1.a, 4.2.b (ii)]。
* **対策:** ACL で明示的に `permit icmp any any unreachable` を許可するか、`ip tcp adjust-mss` で強制的にMSSを縮小します。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における L3 MTU、IP MTU、OSPF MTU Ignore、TCP MSS 調整の実践的 CLI 設定例です。

### 1. 物理インターフェイスおよび SVI での L3 / IP MTU 設定

```bash
# 物理ルーテッドポートでの L3 MTU / IP MTU の設定
interface GigabitEthernet1/0/1
 description ROUTED_UPLINK_TO_CORE
 no switchport
 # インターフェイス L3 MTU をジャンボフレーム（9000B）に変更
 mtu 9000
 # IP MTU を明示的に指定（mtu 以下である必要あり）
 ip mtu 9000
 ip address 10.1.12.1 255.255.255.252
exit

# VLAN SVI での L3 MTU 調整
interface Vlan100
 description DATA_VLAN_SVI
 ip address 192.168.100.1 255.255.255.0
 ip mtu 1500
exit
```

### 2. GRE / IPsec トンネルインターフェイスでの MTU / MSS 最適化設定

```bash
# DMVPN / IPsec VTI トンネルインターフェイス
interface Tunnel10
 description DMVPN_SPOKE_TUNNEL
 ip address 172.16.1.10 255.255.255.0
 tunnel source GigabitEthernet1/0/1
 tunnel mode gre multipoint
 
 # トンネルオーバーヘッド（GRE 24B + IPsec 52B = 76B）を考慮した IP MTU 調整
 ip mtu 1424
 
 # TCP SYN パケットの MSS を書き換え (1424 - 40 = 1384 バイト)
 ip tcp adjust-mss 1384
exit
```

### 3. OSPF MTU 不一致チェック無効化 (`ip ospf mtu-ignore`)

```bash
# OSPFv2 インターフェイスでの MTU チェック無視設定
interface GigabitEthernet1/0/2
 ip address 10.1.23.1 255.255.255.0
 ip ospf 1 area 0
 # DBD パケット内の MTU チェックをバイパスし、ExStart ハングを防止
 ip ospf mtu-ignore
exit

# OSPFv3 (IPv6) インターフェイスでの MTU チェック無視設定
interface GigabitEthernet1/0/2
 ospf 100 ipv6 area 0
 ospf 100 ipv6 mtu-ignore
exit
```

### 4. IPv6 MTU 設定および Path MTU Discovery

```bash
interface GigabitEthernet1/0/3
 no switchport
 ipv6 address 2001:db8:1::1/64
 # IPv6 の最小標準 MTU は 1280 バイト。1500バイトに明示指定
 ipv6 mtu 1500
exit
```

---

## 🔍 検証コマンド

L3 MTU、IP MTU、ICMP エラー統計、OSPF ステートを確認するためのコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **特定インターフェイスの L3 MTU、IP MTU、TCP MSS 調整値の確認** | <code>show interfaces GigabitEthernet1/0/1</code><br><code>show ip interface GigabitEthernet1/0/1</code> |
| **IPv6 インターフェイスの IPv6 MTU 値の確認** | <code>show ipv6 interface GigabitEthernet1/0/1</code> |
| **OSPF インターフェイス配下での <code>mtu-ignore</code> の有効化状態確認** | <code>show ip ospf interface GigabitEthernet1/0/1</code> [21, 1.2.k, 1.4.a] |
| **OSPF ネイバーのステート（ExStart/Exchange ハングの有無）確認** | <code>show ip ospf neighbor</code> [21, 1.4.a] |
| **IP フラグメンテーション処理・ドロップカウント・ICMP 送信統計の確認** | <code>show ip traffic</code> |
| **特定サイズ・DFビット付与での Ping 疎通検証（Path MTU の実測）** | <code>ping 10.1.1.2 size 1472 df-bit</code> |
| **IPv6 パケットの Path MTU キャッシュテーブルの確認** | <code>show ipv6 pmtu</code> |
| **OSPF DBD パケット交信ログのデバッグ** | <code>debug ip ospf adj</code> / <code>debug ip ospf packet</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **OSPF ネイバーが `ExStart` または `Exchange` ステートのまま停止し、`FULL` に移行しない。** | 接続する両端のインターフェイス間で **L3 MTU（または `ip mtu`）の値が不一致**（例: 片側 1500B、もう片側 1400B） [21, 1.2.k, 1.4.a]。 | `show ip ospf neighbor`<br>`show ip interface <int>`<br>`debug ip ospf adj` | 1. 両端の `ip mtu` を同じ値に統一する。<br>2. 物理条件で統一できない場合、該当ポートで `ip ospf mtu-ignore` を設定する [21, 1.2.k, 1.4.a]。 |
| **ICMP Ping（小容量）は通るが、HTTPS 閲覧や SCP/SFTP ファイル転送が途中でハングアップする。** | **PMTUD ブラックホール。** トンネル等で L3 MTU を超過した DF=1 パケットが発生しているが、途中のルータで ICMP Type 3 Code 4 が ACL/CoPP でブロックされ、送信元がサイズを小さくできない [21, 1.2.k, 4.1.a, 4.2.b (ii)]。 | `ping <IP> size 1500 df-bit`<br>`show ip interface <int>` | 1. 経路上の ACL / CoPP で `icmp unreachable` を許可する。<br>2. トンネル/対向インターフェイスで `ip tcp adjust-mss 1360` 等を設定し、SYN 時に MSS を強制縮小する。 |
| **`ip mtu 1600` コマンドを設定しようとすると CLI でエラーが発生して拒否される。** | インターフェイスの L3 MTU（`mtu`）がデフォルトの 1500 バイトのままになっており、**`ip mtu` が Interface `mtu` を超過**している [21, 1.2.k]。 | `show interfaces <int>` | 先に物理/論理インターフェイス側で `mtu 1600`（以上）を設定してから、`ip mtu 1600` を設定する。 |
| **ルータの CPU 使用率（Process: IP Input）が異常高騰し、パケット遅延が発生する。** | **大量のパケットが IP フラグメンテーション処理**されており、ASIC ハードウェア転送から CPU ソフトウェア処理（Punt）へ切り替わっている [21, 1.2.k, 4.1.a]。 | `show processes cpu sorted`<br>`show ip traffic` (fragmentation カウント) | トンネルおよびコア網の MTU をジャンボフレーム（9000B）化するか、`ip tcp adjust-mss` を適用してフラグメントの発生自体をゼロにする。 |
| **BGP セッションが短時間で切断と接続を繰り返す（Flapping）。** | BGP の Path MTU Discovery が有効な環境で、大容量の BGP Update パケットが途中の MTU 制限リンクでドロップされている [21, 1.2.k, 1.5.a]。 | `show ip bgp neighbors`<br>`show ip route` | BGP 隣接設定で `neighbor <IP> transport path-mtu-discovery` を点検するか、トランスポートパスの MTU を正常化する。 |

---

## ⚠ 制限事項

### 1. `ip mtu` と `mtu` の包含関係ルール
* Cisco IOS-XE において、`ip mtu` はインターフェイスの `mtu`（L3 Interface MTU）を超える値を指定できません（`ip mtu` $\le$ `mtu`） [21, 1.2.k]。

### 2. ハードウェア（ASIC）とスイッチポートの L2 MTU 制限
* Catalyst 9000 シリーズなどのスイッチドポート（`switchport` モード）では、個別の L3 IP MTU は指定できず、グローバルまたはポート単位の L2 Frame MTU（`mtu <bytes>`）に従います [21, 1.1.a (iii)]。

### 3. IPv6 における最小 MTU 規定 (RFC 8200)
* **IPv6 の最小必至 MTU は 1280 バイト** です。IPv6 インターフェイスの MTU を 1280 未満に設定することは RFC 仕様上禁止されており、Cisco CLI でも拒否されます。また、IPv6 では途中のルータによる IP フラグメンテーションは完全に廃止されており、**フラグメンテーションは送信元ホストでのみ実行** されます。

---

## 🔄 他技術との関連

* **OSPF (v2/v3):**
  DBD パケット内で L3 MTU を相互検証します。不一致時は `ExStart` / `Exchange` ステートでハングするため、`ip ospf mtu-ignore` または MTU 統一が必須です [21, 1.2.k, 1.4.a]。
* **BGP (Border Gateway Protocol):**
  BGP セッションは TCP (Port 179) 上で動作します。`ip tcp path-mtu-discovery` または `neighbor <IP> transport path-mtu-discovery` を使用することで、BGP UPDATE パケットの最適サイズを動的調整します [21, 1.2.k, 1.5.a]。
* **GRE / IPsec / DMVPN / VXLAN:**
  カプセル化ヘッダーによる追加オーバーヘッド（24B〜76B+）が発生するため、`ip mtu` の低減および `ip tcp adjust-mss` のバインドがトラフィックブラックホール防止の絶対要件となります [21, 1.2.k, 3.3.a]。
* **CoPP (Control Plane Policing) & ACL:**
  Path MTU Discovery に不可欠な ICMP Type 3 Code 4 (Destination Unreachable - Fragmentation Needed) パケットを遮断しないようポリシールールを設計する必要があります [21, 1.2.k, 4.1.a, 4.2.b (ii)]。

---

## 🧩 比較表

### L2 MTU vs L3 MTU (Interface MTU) vs IP MTU vs TCP MSS

| パラメータ | 該当階層 | 測定対象範囲 | デフォルト値 (Ethernet) | 制御コマンド |
| :--- | :--- | :--- | :--- | :--- |
| **L2 MTU (System MTU)** | Layer 2 | L2フレーム全体（L2 Header ＋ L3 Packet ＋ FCS） | 1518 / 1522 (VLAN) bytes | `system mtu` / `mtu` [21, 1.1.a (iii)] |
| **L3 MTU (Interface MTU)** | Layer 3 | L3 IPパケット全体（IP Header ＋ Payload） | 1500 bytes | `mtu <bytes>` [21, 1.2.k] |
| **IP MTU** | Layer 3 (IP) | IPレイヤ固有の最大パケット長 | 1500 bytes (L3 MTU継承) | `ip mtu <bytes>` [21, 1.2.k] |
| **IPv6 MTU** | Layer 3 (IPv6) | IPv6レイヤ固有の最大パケット長（最小1280B） | 1500 bytes | `ipv6 mtu <bytes>` [21, 1.2.k] |
| **TCP MSS** | Layer 4 (TCP) | TCP固有の純粋なデータペイロード長 | 1460 bytes ($1500 - 20 - 20$) | `ip tcp adjust-mss <bytes>` [21, 1.2.k] |

---

## 💡 ベストプラクティス

1. **エンタープライズコア・アンダーレイ網の「Jumbo Frame (9000B)」化:**
   キャンパスのコア・ディストリビューションスイッチ、および SD-Access / VXLAN アンダーレイ網全体で L2/L3 MTU を **9000 バイト**（ジャンボフレーム）に統一拡大します。これにより、カプセル化オーバーヘッドによるパケット溢れを完全にゼロ化します [21, 1.1.a (iii), 1.2.k]。
2. **DMVPN / IPsec エッジでの `ip tcp adjust-mss 1360` の一律適用:**
   WAN エッジルータや DMVPN トンネルインターフェイスにおいて、標準で `ip mtu 1400` および `ip tcp adjust-mss 1360` を適用し、エンドユーザーの端末設定に依存することなく TCP 通信のハング障害を未然防止します [21, 1.2.k, 3.3.a]。
3. **OSPF トンネル接続ポートでの `ip ospf mtu-ignore` の予防的設定:**
   異なるメディア（GRE、VTI、仮想インターフェイス等）を跨いで OSPF アジャセンシーを形成する場合、MTU 不一致による不意の `ExStart` 停滞を防ぐため、トンネルインターフェイス配下に `ip ospf mtu-ignore` を明示的に構成します [21, 1.2.k, 1.4.a]。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI 実技試験レベルを意識した、省略なしの厳格な10の完全 CLI ラボシナリオです。

### 1. 【基本】物理ルーテッドポートの L3 MTU および IP MTU 調整
**【問題】**
R1 の `GigabitEthernet1/0/1`（ルーテッドポート）において、L3 MTU を `9000` バイトに拡大し、さらに IP MTU を `8900` バイトに個別に指定してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/1
 description UPLINK_TO_CORE
 no switchport
 # インターフェイス L3 MTU を先に拡大
 mtu 9000
 # IP MTU を mtu 以下の値で個別に設定
 ip mtu 8900
 ip address 10.1.12.1 255.255.255.252
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip interface GigabitEthernet1/0/1
# 出力内に「MTU is 8900 bytes」が表示されていることを確認します。
```

---

### 2. 【OSPF】ExStart ハングの解消 (`ip ospf mtu-ignore`)
**【問題】**
R1 (MTU 1500) と R2 (MTU 1400) 間で OSPFv2 ネイバーが `ExStart` ステートでハングしています。R1 の物理 MTU を変更することなく、R1 の `GigabitEthernet1/0/2` 上で OSPF ネイバーを `FULL` に復旧させてください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/2
 ip ospf mtu-ignore
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
# R2 とのネイバー状態が「FULL/DR」または「FULL/BDR」に遷移したことを確認します。
```

---

### 3. 【GRE トンネル】IP MTU および TCP MSS の最適化
**【問題】**
R1 の GRE トンネル `Tunnel0`（ソース: `Gi1/0/1`, 宛先: `10.1.24.2`）において、GRE オーバーヘッド（24B）を考慮して IP MTU を `1476` に設定し、通過する TCP SYN パケットの MSS を `1436` バイトに自動調整してください。

**【R1 設定】**
```bash
R1# configure terminal
interface Tunnel0
 ip address 172.16.1.1 255.255.255.0
 tunnel source GigabitEthernet1/0/1
 tunnel destination 10.1.24.2
 # IP MTU 調整
 ip mtu 1476
 # TCP MSS 調整 (1476 - 40 = 1436)
 ip tcp adjust-mss 1436
exit
R1# end
```

**【検証方法】**
```bash
R1# show interface Tunnel0
# 「MTU 1476 bytes」を確認。また PC からトンネル経由で大容量 Web 通信を実施しログを検証。
```

---

### 4. 【DMVPN + IPsec】IPsec VTI トンネルの MTU / MSS 複合設定
**【問題】**
R1 の IPsec VTI トンネル `Tunnel1` において、暗号化オーバーヘッド（約72B）に対応するため IP MTU を `1428` に設定し、TCP MSS を `1388` バイトに調整してください。また、OSPF の MTU チェック無視を設定してください。

**【R1 設定】**
```bash
R1# configure terminal
interface Tunnel1
 ip address 10.255.1.1 255.255.255.0
 tunnel source GigabitEthernet1/0/1
 tunnel destination 10.1.45.5
 tunnel mode ipsec ipv4
 tunnel protection ipsec profile IPSEC_PROFILE
 ip mtu 1428
 ip tcp adjust-mss 1388
 ip ospf mtu-ignore
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip interface Tunnel1
# IP MTU が 1428 バイト、TCP MSS 調整が有効であることを確認します。
```

---

### 5. 【IPv6】IPv6 MTU 調整と Path MTU Discovery
**【問題】**
R1 の `GigabitEthernet1/0/3` において、IPv6 アドレス `2001:db8:100::1/64` を設定し、IPv6 MTU を明示的に `1400` バイトに変更してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/3
 no switchport
 ipv6 address 2001:db8:100::1/64
 ipv6 mtu 1400
exit
R1# end
```

**【検証方法】**
```bash
R1# show ipv6 interface GigabitEthernet1/0/3
# 「IPv6 MTU is 1400 bytes」と表示されることを確認します。
```

---

### 6. 【Ping 検証】DF ビット付き指定サイズ Ping による Path MTU 測定
**【問題】**
R1 から対向ルータ `10.1.12.2` に対し、DF ビット（Don't Fragment）を立てた状態でパケットサイズ `1472` バイト（IPヘッダー20B＋ICMPヘッダー8Bを含め全体で1500B）の Ping 検証を実行してください。

**【R1 特権EXEC実行】**
```bash
R1# ping 10.1.12.2 size 1472 df-bit
```

**【検証方法】**
```bash
# 応答率が 100% (!!!!!) で返ることを確認します。
# もし MTU が不足している場合は「M」（Fragmentation Needed）または「.」で失敗します。
```

---

### 7. 【BGP】BGP Path MTU Discovery の有効化
**【問題】**
R1 の BGP プロセス 65001 において、iBGP ネイバー `10.1.1.2` とのセッションで TCP Path MTU Discovery を有効化し、BGP UPDATE パケットの最大サイズを動的に最適化してください。

**【R1 設定】**
```bash
R1# configure terminal
router bgp 65001
 neighbor 10.1.1.2 remote-as 65001
 neighbor 10.1.1.2 update-source Loopback0
 # BGP ネイバー単位で Transport PMTUD を有効化
 neighbor 10.1.1.2 transport path-mtu-discovery
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.1.2
# 「Transport Path MTU Discovery is enabled」が含まれていることを確認します。
```

---

### 8. 【OSPFv3】IPv6 OSPFv3 インターフェイスでの MTU Ignore 設定
**【問題】**
R1 の `GigabitEthernet1/0/4` 上で動作する IPv6 OSPFv3 (Process 100) において、対向との MTU 不一致による ExStart ハングを防ぐため、`mtu-ignore` を設定してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/4
 ospf 100 ipv6 area 0
 ospf 100 ipv6 mtu-ignore
exit
R1# end
```

**【検証方法】**
```bash
R1# show ospfv3 interface GigabitEthernet1/0/4
# 「Suppress MTU mismatch detection is enabled」を確認します。
```

---

### 9. 【VRF-Aware】VRF 内インターフェイスでの MTU / MSS 個別調整
**【問題】**
VRF `RED` に属する sub-interface `GigabitEthernet1/0/1.100` において、IP MTU を `1400`、`ip tcp adjust-mss` を `1360` に設定してください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition RED
 address-family ipv4
exit

interface GigabitEthernet1/0/1.100
 encapsulation dot1Q 100
 vrf forwarding RED
 ip address 192.168.10.1 255.255.255.0
 ip mtu 1400
 ip tcp adjust-mss 1360
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip interface GigabitEthernet1/0/1.100
# VRF RED 内で IP MTU 1400 bytes および TCP MSS 1360 が適用されていることを確認。
```

---

### 10. 【CoPP / ACL】ICMP Unreachable (Type 3 Code 4) 許可 ACL の作成
**【問題】**
Path MTU Discovery (PMTUD) が正常に動作するよう、R1 のインバウンド ACL `PROTECT_IN` において、ICMP Destination Unreachable パケットを明示的に許可するルールを追加してください。

**【R1 設定】**
```bash
R1# configure terminal
ip access-list extended PROTECT_IN
 # PMTUD に不可欠な ICMP Type 3 (Unreachable) を許可
 permit icmp any any unreachable
 permit ip any any
exit

interface GigabitEthernet1/0/1
 ip access-group PROTECT_IN in
exit
R1# end
```

**【検証方法】**
```bash
R1# show ip access-lists PROTECT_IN
# ICMP unreachable エントリにマッチカウントが加算されることを確認します。
```

---

## ❓ 想定試験問題

CCIE EI 実技試験および Diagnostic セクションに対応するハイレベルな想定問題群です。

### 1. 【トラブルシューティング：OSPF ExStart ハングと MTU 不一致の特定】
**問題:** 
R1 と R2 は `GigabitEthernet1/0/1` で直結されており、OSPFv2 エリア 0 が構成されています。両ルータで `show ip ospf neighbor` を実行したところ、ステートが `ExStart/DR` のまま数分間変動せず、`FULL` に移行しません。
両ルータの `GigabitEthernet1/0/1` の設定は以下の通りです。

```text
[R1]
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0

[R2]
interface GigabitEthernet1/0/1
 mtu 1400
 ip address 10.1.12.2 255.255.255.0
 ip ospf 1 area 0
```
R1 の物理 MTU（1500）を変更することなく、この問題を解決して OSPF ネイバーを `FULL` に遷移させるための**根本原因の技術的説明**および**最小限の追加コマンド**を答えなさい。

**解答・解説:**
* **根本原因:**
  R2 側で `mtu 1400` が設定されているため、R2 の L3 IP MTU は 1400 バイトになります。一方、R1 の IP MTU はデフォルトの 1500 バイトです [21, 1.2.k]。
  OSPF は DBD (Database Description) パケット交換時（ExStart ステート）に、送信側の IP MTU 値を DBD ヘッダーに含めます [21, 1.2.k, 1.4.a]。R2 は R1 から届いた DBD 内の MTU (1500) が自身の MTU (1400) より大きいため、パケットを破棄します。その結果、DBD ネゴシエーションが完了せず `ExStart` ステートでハングします [21, 1.2.k, 1.4.a]。
* **追加コマンド (R1 または R2 側のインターフェイス配下):**
  ```text
  R1(config)# interface GigabitEthernet1/0/1
  R1(config-if)# ip ospf mtu-ignore
  ```
  *(※ R1 側で `ip ospf mtu-ignore` を設定することで、DBD 受信時の MTU チェックがバイパスされ、直ちに `FULL` ステートへ遷移します)* [21, 1.2.k, 1.4.a]

---

### 2. 【コンフィグ読解・設計：GRE トンネルにおける PMTUD ブラックホールと MSS 調整】
**問題:** 
以下のコンフィグが設定されたルータ R1 を経由して、LAN 上のクライアント PC がインターネット上の HTTPS サーバーへ接続を試みています。小容量の PING は成功しますが、ブラウザでの Web ページ読み込みが途中で永久に停止（ハングアップ）します。

```text
interface Tunnel0
 ip address 172.16.1.1 255.255.255.0
 tunnel source GigabitEthernet1/0/1
 tunnel destination 203.0.113.2

ip access-list extended OUTSIDE_IN
 deny icmp any any
 permit ip any any

interface GigabitEthernet1/0/1
 ip access-group OUTSIDE_IN in
```

この通信障害が発生している**2つの相互に連動する技術的原因**を指摘し、R1 上でこの障害を解消するための修正コマンドを提示せよ。

**解答・解説:**
* **技術的原因:**
  1. **パケット長超過:** クライアント PC からの TCP パケット（DF=1, 1500B）に GRE ヘッダー（24B）が付加されることでパケットサイズが 1524 バイトとなり、送出ポートの MTU (1500) を超過する [21, 1.2.k]。
  2. **ICMP 遮断（PMTUD ブラックホール）:** R1 が送信元 PC へ向けて ICMP Type 3 Code 4 (Fragmentation Needed) を返送しようとする、あるいは途中の ISP ルータからの ICMP 通知がインバウンド ACL `OUTSIDE_IN` の `deny icmp any any` によって破棄されているため、PC 側で Path MTU を縮小できずブラックホール化している [21, 1.2.k, 4.2.b (ii)]。
* **修正・対策コマンド:**
  1. ACL で ICMP Unreachable を許可する:
     ```text
     R1(config)# ip access-list extended OUTSIDE_IN
     R1(config-ext-nacl)# 5 permit icmp any any unreachable
     ```
  2. Tunnel0 インターフェイスで TCP MSS を強制制御する:
     ```text
     R1(config)# interface Tunnel0
     R1(config-if)# ip mtu 1476
     R1(config-if)# ip tcp adjust-mss 1436
     ```

---

### 3. 【Design：SD-Access / VXLAN アンダーレイ網における MTU 設計評価】
**問題:** 
企業ネットワークにおいて Cisco SD-Access (Software-Defined Access) ファブリックを導入予定です。ファブリックエッジとファブリックコントロールプレーン間のアンダーレイ（Underlay）網において、パケットのフラグメンテーションを全排除し、マルチキャスト/ユニキャスト転送パフォーマンスを極限まで高めるための **アンダーレイ L2/L3 MTU 設計基準** について説明せよ [21, 1.1.a (iii), 1.2.k, 1.6.c]。

**解答・解説:**
* **SD-Access オーバーヘッド構造:**
  SD-Access のオーバーレイパケットは、元のイーサネットフレームに対して **VXLAN ヘッダー (8B) ＋ UDP ヘッダー (8B) ＋ Outer IP ヘッダー (20B) ＋ Outer Ethernet ヘッダー (14B) ＋ LISP / SGT オプション (約8B〜16B)**、計約 50〜64 バイト以上の追加カプセル化オーバーヘッドが発生します。
* **設計基準（ベストプラクティス）:**
  1. **アンダーレイ全ルータ・スイッチでの Jumbo Frame (9100B 以上) の統一設定:** アンダーレイの物理インターフェイス、L3 ルーテッドポート、および Port-Channel の L2/L3 MTU を一律 **9100 バイト**（Catalyst 9000 シリーズ推奨値）に設定します [21, 1.1.a (iii), 1.2.k]。
  2. **1500 バイト固定網におけるフォールバック:** アンダーレイ網でジャンボフレームが許可されない場合は、ファブリックエッジ配下の端末接続 SVI やルータで `ip tcp adjust-mss 1400` 以下を設定し、オーバーレイ上での MTU 超過を防止します [21, 1.2.k]。

---

## 🔗 参考リソース

### Cisco ソフトウェア設定ガイド（Configuration Guide）
* [**Cisco Catalyst 9300 Series Switches: Interface and Hardware Component Configuration Guide, Cisco IOS XE 17.x - Configuring System MTU**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/int_hw/b_17x_int_hw_9300_cg/m_configuring_system_mtu.html)
  * Catalyst 9000 シリーズにおける System MTU、L2/L3 MTU の設定と仕様リファレンス。
* [**Cisco IOS XE 17.x IP Routing: OSPF Configuration Guide - OSPF Support for Unlimited MTU**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/17-x/iro-17-x-book.html)
  * OSPF における DBD パケット MTU チェック動作および `ip ospf mtu-ignore` の公式ドキュメント。

### テクニカルノート・ホワイトペーパー
* [**Resolve IP Fragmentation, MTU, MSS, and PMTUD Issues with GRE and IPsec**](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/13725-56.html)
  * GRE / IPsec カプセル化時における MTU、MSS、PMTUD、フラグメンテーションの動作原理とトラブルシューティングの決定版解説。

---

## 📝 **補足（Notes）**

### L3 MTU トラブルシューティングクイック診断フロー

```text
[ 症 状 : 大容量通信のハング / OSPF ExStart 停滞 ]
                           │
                           ▼
          ＜ トラブルの種別は？ ＞
         /                       \
   (OSPF Neighbor)            (Data Traffic)
        /                           \
       ▼                             ▼
 [ show ip ospf neighbor ]     [ ping <IP> size 1472 df-bit ]
       │                             │
       ├─ ExStart/Exchange           ├─ 応答なし / ドロップ
       │                             │
       ▼                             ▼
 [ 両端の ip mtu を比較 ]       [ カプセル化オーバーヘッド計算 ]
 (1500 vs 1400 等の差を発見)   (GRE: -24B, IPsec: -52B等)
       │                             │
       ▼                             ▼
 [ ip ospf mtu-ignore ]        [ ip tcp adjust-mss 1360 ]
 を適用して即時復旧            をトランク/トンネルポートにバインド
```

* **最終点検リスト:**
  * [ ] 物理インターフェイスの `mtu`（L3 Interface MTU）と `ip mtu` の整合性が保たれているか？（`ip mtu` $\le$ `mtu`）
  * [ ] DMVPN / GRE / IPsec トンネルインターフェイスに `ip tcp adjust-mss`（推奨 1360〜1380B）が構成されているか？ [21, 1.2.k, 3.3.a]
  * [ ] ACL や CoPP で ICMP Type 3 Code 4 (Fragmentation Needed) が誤って遮断されていないか？ [21, 1.2.k, 4.1.a, 4.2.b (ii)]
  * [ ] OSPF ネイバーで `ExStart` ハングが発生した際、`ip ospf mtu-ignore` を迅速に適用できるか？ [21, 1.2.k, 1.4.a]

---

