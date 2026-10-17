---
layout: default
title: 4.2.b-Router-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.2.b Router security features

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.2.b Router security features`（(i) IPv6 traffic filters, (ii) IPv4 access control lists, (iii) Unicast Reverse Path Forwarding [uRPF]）の完全学習メモ。

---

## 📘 概要

ルータセキュリティ機能は、エンタープライズネットワークおよび WAN エッジ/サービスプロバイダ境界において、不法トラフィックの遮断、送信元 IP アドレス偽装（IP スプーフィング）の防止、ネットワークリソースの保護、およびコントロールプレーン/データプレーンの完全性確保を実現する核心技術である。

* **IPv6 Traffic Filters (4.2.b (i)):**
  * **機能概要:** IPv6 パケットの送信元/宛先 IP アドレス、上位プロトコル（TCP, UDP, ICMPv6）、ヘッダーオプション、拡張ヘッダー（Routing Header, Fragment Header 等）に基づいてパケットをフィルタリングする。
  * **利用目的:** インターフェイス単位での Inbound/Outbound トラフィック制御、ICMPv6 パケットの厳格な制御、VTY アクセス制限。
  * **利用場面:** IPv6 WAN エッジ、デュアルスタック LAN 境界、および IPv6 インフラストラクチャ保護。

* **IPv4 Access Control Lists (4.2.b (ii)):**
  * **機能概要:** Standard / Extended / Named ACL、Time-Based ACL（時間限定）、Object-Group ACL（オブジェクトグループ化による集約）、Reflexive ACL（動的セッション追跡）を用いた IPv4 パケットのフィルタリング。
  * **利用目的:** ネットワーク境界でのアクセスポリシー適用、特定の通信プロトコル/ポートの制限、PBR (Policy-Based Routing) や CoPP、uRPF 例外用マッチング条件の提供。
  * **利用場面:** 企業キャンパス/WAN 境界、DMZ セグメンテーション、管理アクセス制限。

* **Unicast Reverse Path Forwarding - uRPF (4.2.b (iii)):**
  * **機能概要:** パケットを受信した際、そのパケットの「送信元 IP アドレス（Source IP）」に対する FIB (Forwarding Information Base) ルックアップを行い、逆方向パス（Reverse Path）の妥当性を検証することで IP スプーフィングを水際でドロップする。
  * **利用目的:** DoS/DDoS 攻撃対策、送信元 IP 偽装パケットの排除、BGP RTBH (Remotely Triggered Black Hole) との連携。
  * **利用場面:** ISP 接続境界、企業 WAN エッジ、リモートアクセス VPN 収容ルータ。

---

## 🔑 要点

| 機能 / 項目 | 特徴 | 用途 / 適用箇所 | メリット | デメリット / 制限事項 | 設計上の注意点 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **IPv6 Traffic Filter** | 名前付き IPv6 ACL のみサポート (`ipv6 traffic-filter`) | IPv6 インターフェイス (Inbound/Outbound) | 暗黙の NDP 許可ルールが組み込まれている | 番号付き ACL は非サポート。明示的 `deny any` 追加時に NDP 切断リスクあり | 末尾に `deny ipv6 any any` を書く場合、ICMPv6 NS/NA/RS/RA を明示許可する必要あり |
| **IPv4 ACL** | Standard / Extended / Named / Time-Based / Object-Group | IPv4 インターフェイス (`ip access-group`) | 細かい L3/L4 制御、時間・オブジェクト柔軟定義 | ルール増大による管理複雑化、ステートフル制御には上限あり | 評価順序は Top-Down 処理。頻度の高いルールを上位に配置 |
| **uRPF Strict モード** | 送信元 IP が FIB に存在し、かつ入力 I/F ＝ 戻り I/F であることを検証 | シングルホーム接続、対称ルーティング環境 | 送信元偽装を最も厳格にドロップ | 非対称ルーティング環境では正常パケットを誤ドロップする | 非対称パスが発生するマルチホーム環境では使用不可 |
| **uRPF Loose モード** | 送信元 IP が FIB（Null0 以外）に存在することのみを検証 | マルチホーム BGP 境界、非対称パス環境 | 非対称ルーティングに対応しつつ存在しない IP を遮断 | 同一ネットワーク内の送信元偽装（有効 IP の偽装）は防げない | デフォルトルートを有効経路とみなすには `allow-default` が必須 |
| **uRPF ACL 例外 (Pass)** | 指定した ACL で `permit` された送信元 IP は RPF チェック失敗でも通過 | 非対称パスが発生する特定の送信元 IP の救済 | 特定トラフィックのみ uRPF 検証から除外可能 | ACL 設定の誤りによるセキュリティホールの形成 | ACL 内の `permit` が「uRPF チェック免除（通過）」を意味する点に注意 |

---

## 🏗 動作原理

### 1. IPv4 ACL ＆ IPv6 Traffic Filter パイプライン

```text
[ パケット受信 (Ingress Interface) ]
         │
         ▼
[ Inbound ACL / Traffic Filter 評価 ] ──(Match Deny)──► [ Packet Dropped (ACL Counter +1) ]
         │
     (Match Permit / Pass)
         ▼
[ uRPF Validation (有効化時) ] ──(RPF Failure)──► [ Packet Dropped (uRPF Counter +1) ]
         │
     (RPF Success)
         ▼
[ FIB Routing Lookup / Switching ]
         │
         ▼
[ Outbound ACL / Traffic Filter 評価 ] ──(Match Deny)──► [ Packet Dropped ]
         │
     (Match Permit)
         ▼
[ 送信 (Egress Interface) ]
```

### 2. uRPF Strict vs Loose 動作フロー

* **Strict モード (`reachable-via rx`):**
  1. 受信パケットの送信元 IP アドレス $S$ を抽出。
  2. FIB テーブルで $S$ 宛ての最適な送信インターフェイス $I_{FIB}$ を検索。
  3. パケットが実際に到着した物理/論理インターフェイス $I_{IN}$ と $I_{FIB}$ を比較。
  4. $I_{IN} == I_{FIB}$ の場合のみ通過許可。一致しない場合（非対称パス）は即座にドロップ。

* **Loose モード (`reachable-via any`):**
  1. 受信パケットの送信元 IP アドレス $S$ を抽出。
  2. FIB テーブルで $S$ 宛てのルートが存在するか確認。
  3. ルートが存在し、かつ出力インターフェイスが `Null0` でない場合は通過許可。到着ポートの一致は要求しない。

---

## ⚙ 動作シーケンス

### 1. IPv6 Traffic Filter 処理と NDP 動作シーケンス
1. インターフェイスで `ipv6 traffic-filter <ACL_NAME> in` を適用。
2. IPv6 パケットが到着すると、定義された ACL ルールを最上位（Sequence 10）から順に評価。
3. 一致するルールがあれば `permit` / `deny` アクションを実行。
4. **暗黙のシーケンス（Implicit Rules）の評価:**
   * 明示的な一致がない場合、IPv6 ACL の末尾には以下の暗黙のルールが隠されている:
     * `permit icmp any any neighbor-solicitation`
     * `permit icmp any any neighbor-advertisement`
     * `permit icmp any any router-solicitation`
     * `permit icmp any any router-advertisement`
     * `deny ipv6 any any`
5. **注意すべき落とし穴:** 明示的に `deny ipv6 any any log` などを末尾に記述すると、暗黙の NDP 許可ルールより前にログ付き deny が評価され、**NDP (ICMPv6) が遮断されて Neighbor が Down** する。

### 2. uRPF 評価と ACL 例外処理シーケンス
1. インターフェイスで `ip verify unicast source reachable-via rx 100` を適用。
2. パケットを受信すると、まず送信元 IP アドレスが ACL 100 にマッチするか評価。
3. ACL 100 で `permit` された送信元 IP アドレスの場合 ➔ **uRPF チェックをスキップ（通過）**。
4. ACL 100 で `deny` または未マッチの場合 ➔ 通常の uRPF (Strict/Loose) チェックを実行。
5. FIB 検索により RPF 検証に失敗した場合 ➔ パケットをドロップし、`show ip traffic` の `Drop` カウンタを加算。


---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
1. **IPv6 ACL の暗黙ルール破壊トラブル:** `deny ipv6 any any log-input` を設定したことで OSPFv3 / BGP IPv6 / NDP が切断される問題の解決。
2. **Time-Based ACL:** `time-range` オブジェクトを定義し、特定時間帯（例: 営業時間外）のみ通信をブロックするコンフィグ。
3. **uRPF と非対称ルーティング:** マルチホーム環境で Strict モードが設定されており通信が破棄されている障害に対し、Loose モードまたは `allow-default` へ変更するトラブルシュート。
4. **uRPF 例外 ACL の記述:** uRPF ACL 内の `permit` が「uRPF チェック免除（通過）」であることを正しく理解し、例外リストを作成する。
5. **IPv4/IPv6 拡張 ACL の条件判定:** `match-all +ack +syn` (TCP フラグ)、`fragments` (断片化パケット)、`ttl neq 254` 等の特殊条件の正確な記述。

### よくある設定ミス
* **IPv6 ACL での NDP 遮断:** 末尾に `deny ipv6 any any` を追加した際、`permit icmp any any` または NDP 明示許可を入れ忘れて IPv6 の隣接関係が全滅する。
* **uRPF での `allow-default` 忘れ:** Loose モードを適用した際、デフォルトルート経由でしか到達できない送信元 IP のパケットがすべてドロップされる。
* **uRPF ACL の `permit` と `deny` の混同:** uRPF 例外 ACL で「ブロックしたい IP」を `permit` に書いてしまい、全通過させてしまう誤り。

---

## 🛠 設定方法

### 1. IPv6 Traffic Filter ＆ Time-Based IPv4 ACL 設定例

```bash
! --- 1. 時間範囲 (Time-Range) の定義 ---
time-range OFFICE_HOURS
 periodic weekdays 09:00 to 18:00

! --- 2. IPv4 時間限定 & オブジェクトグループ ACL ---
object-group network OG_ADMINS
 host 10.1.1.10
 host 10.1.1.11

ip access-list extended ACL_IPV4_IN
 remark --- Allow Admin Access anytime ---
 permit ip object-group OG_ADMINS any
 remark --- Allow User Web Access only during Work Hours ---
 permit tcp 10.1.2.0 0.0.0.255 any eq www time-range OFFICE_HOURS
 permit tcp 10.1.2.0 0.0.0.255 any eq 443 time-range OFFICE_HOURS
 remark --- Explicit Deny with Log ---
 deny ip 10.1.2.0 0.0.0.255 any log-input
 permit ip any any

! --- 3. IPv6 Traffic Filter (NDP 明示保護付き) ---
ipv6 access-list ACL_IPV6_IN
 remark --- Protect ICMPv6 NDP (NS, NA, RS, RA) ---
 permit icmp any any neighbor-solicitation
 permit icmp any any neighbor-advertisement
 permit icmp any any router-solicitation
 permit icmp any any router-advertisement
 remark --- Restrict Management SSH ---
 permit tcp 2001:DB8:1::/64 any eq 22
 remark --- Explicit Deny with Log (Safely configured) ---
 deny ipv6 any any log-input

! --- 4. インターフェイスへの適用 ---
interface GigabitEthernet0/0/1
 ip access-group ACL_IPV4_IN in
 ipv6 traffic-filter ACL_IPV6_IN in
```

### 2. uRPF Strict / Loose ＆ ACL 例外設定例

```bash
! --- 1. uRPF 例外用 ACL の作成 (uRPFチェック失敗時でも許可する送信元IP) ---
ip access-list standard ACL_URPF_PASS
 permit 192.168.100.0 0.0.0.255

! --- 2. uRPF Strict モード (ACL 例外付き) ---
interface GigabitEthernet0/0/2
 description --- Single-Homed LAN Interface ---
 ip verify unicast source reachable-via rx ACL_URPF_PASS

! --- 3. uRPF Loose モード (デフォルトルート許容) ---
interface GigabitEthernet0/0/3
 description --- Multi-Homed ISP WAN Interface ---
 ip verify unicast source reachable-via any allow-default
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 主な確認項目 |
| :--- | :--- | :--- |
| **IPv4 ACL 確認** | <code>show ip access-lists [NAME]</code> | ヒットカウント (matches)、シーケンス番号、適用条件 |
| **IPv6 ACL 確認** | <code>show ipv6 access-list [NAME]</code> | ヒットカウント、ICMPv6/NDP マッチ条件 |
| **uRPF 状態確認** | <code>show ip interface &lt;Type/Num&gt;</code> | `IP verify unicast source reachable-via...` の設定モード |
| **uRPF ドロップ数** | <code>show ip traffic \| section Drop</code> | `unicast RPF` ドロップカウンタの増加確認 |
| **FIB 到達性確認** | <code>show ip cef &lt;IP_ADDR&gt;</code> | uRPF が参照する FIB 経路および出力インターフェイス |
| **uRPF 詳細カウンタ** | <code>show ip interface &lt;Type/Num&gt; \| include verification</code> | ドロップ数および Suppression カウンタ |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IPv6 ACL 適用後に BGPv6 / OSPFv3 ネイバーが Down** | ACL 末尾の `deny` により ICMPv6 NDP (NS/NA) が遮断された | <code>show ipv6 neighbors</code><br><code>show ipv6 access-list</code> | ACL 冒頭に `permit icmp any any neighbor-solicitation` および `neighbor-advertisement` を明示追加 |
| **uRPF Strict 設定後、正常な WAN 通信が半数ドロップ** | 非対称ルーティングが発生しており、戻りポート不一致で RPF チェック失敗 | <code>show ip route</code><br><code>show ip traffic</code> | Loose モード (`reachable-via any`) に変更するか、FIB 経路を対称化 |
| **uRPF Loose 有効化後もデフォルトルート経由の通信が落ちる** | `allow-default` キーワードが欠落している | <code>show ip interface Gi0/0</code> | `ip verify unicast source reachable-via any allow-default` に変更 |
| **uRPF 例外 ACL を追加したが通信が救済されない** | uRPF 用 ACL 内で対象 IP を `deny` と書いてしまった | <code>show ip access-lists</code> | uRPF 例外リストでは、uRPF チェックをバイパス（通過）させたい IP を `permit` で指定する |

---

## ⚠ 制限事項

* **IPv6 ACL の番号指定非対応:** IPv6 ACL は名前付き（Named）のみサポートされ、番号付き（1-199等）は設定不可。
* **uRPF とプロセススウィッチング:** uRPF は **Cisco Express Forwarding (CEF)** の存在を前提とする。`no ip cef` 環境では動作しない。
* **Tunnel インターフェイスでの uRPF 制限:** GRE や DMVPN トンネルインターフェイスでの uRPF 適用時は、カプセル化オーバーヘッドや VRF バインド構造に注意が必要。

---

## 🔄 他技術との関連

* **BGP RTBH (Remotely Triggered Black Hole):** Loose モード uRPF と連携し、攻撃元 IP を `Null0` へルーティングすることで全エッジルータで自動ドロップさせる。
* **CoPP (Control Plane Policing):** CoPP 内の MQC で IPv4/IPv6 ACL を参照し、CPU 宛て不法パケットを抑制する。
* **PBR (Policy-Based Routing):** PBR の `match ip address` で ACL を指定し、特定トラフィックの経路を強制変更する。

---

## 🧩 比較表

| 項目 | IPv4 Access List | IPv6 Traffic Filter |
| :--- | :--- | :--- |
| **適用コマンド** | <code>ip access-group &lt;NAME&gt; &lt;in\|out&gt;</code> | <code>ipv6 traffic-filter &lt;NAME&gt; &lt;in\|out&gt;</code> |
| **識別子** | 番号付き (1-199) / 名前付き | 名前付きのみ |
| **暗黙のルール** | `deny ip any any` のみ | NDP (NS/NA/RS/RA) 許可 ➔ `deny ipv6 any any` |
| **フラグメント処理** | `fragments` キーワード | `fragments` または Extension Header 識別 |

| 項目 | uRPF Strict モード | uRPF Loose モード |
| :--- | :--- | :--- |
| **設定コマンド** | <code>ip verify unicast source reachable-via rx</code> | <code>ip verify unicast source reachable-via any</code> |
| **検証条件** | 送信元 IP 存在 ＋ **到着ポートの一致** | 送信元 IP 存在（ポート問わず） |
| **推奨環境** | アクセス層、シングルホーム WAN | マルチホーム WAN、BGP RTBH 連携 |
| **非対称パス耐性** | なし（ドロップ） | あり（許可） |

---

## 💡 ベストプラクティス

1. **IPv6 ACL には必ず明示的な NDP 許可を配置する:** 将来のルール追加やログ出力設定による事故を防ぐため、冒頭に ICMPv6 NS/NA/RS/RA の許可エントリを明記する。
2. **マルチホーム WAN エッジでは uRPF Loose ＋ `allow-default` を使用する:** 非対称パケットの誤破棄を防ぎつつ、存在しないスプーフィング IP を水際で遮断する。
3. **ACL の先頭に頻出許可ルールを配置する:** Top-Down 評価のため、トラフィック量の多いルールを上位に配置して CPU/TCAM 負荷を軽減する。


---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: IPv4 Extended ACL ＋ Time-Based 制御構成

* **問題:** 営業時間（平日 09:00〜18:00）内のみ、社内サブネット 10.1.10.0/24 から外部 Web サーバー（TCP 80/443）へのアクセスを許可し、営業時間外は拒否せよ。ただし、管理者ホスト（10.1.10.254）は常時アクセス可能とすること。
* **要件:**
  * `time-range` オブジェクト名: `WORK_HOURS`
  * ACL 名: `ACL_WEB_TIME_RESTRICT`
  * 物理ポート Gi0/0/1 の Inbound に適用すること。

* **設定例:**
```bash
! 1. 時間範囲の定義
time-range WORK_HOURS
 periodic weekdays 09:00 to 18:00

! 2. 拡張 ACL の定義
ip access-list extended ACL_WEB_TIME_RESTRICT
 remark --- Allow Admin Always ---
 permit ip host 10.1.10.254 any
 remark --- Allow User Web Access only during Work Hours ---
 permit tcp 10.1.10.0 0.0.0.255 any eq www time-range WORK_HOURS
 permit tcp 10.1.10.0 0.0.0.255 any eq 443 time-range WORK_HOURS
 remark --- Explicit Deny with Log ---
 deny ip 10.1.10.0 0.0.0.255 any log-input
 permit ip any any

! 3. インターフェイス適用
interface GigabitEthernet0/0/1
 ip access-group ACL_WEB_TIME_RESTRICT in
```

* **検証方法:**
  * `show time-range` を実行し、現在の時刻における `Active` / `Inactive` ステータスを確認。
  * 営業時間外に 10.1.10.10 から Web アクセスを試行し、ドロップされることおよび `show ip access-lists` のヒットカウント増加を確認。

---

### ラボ 2: Object-Group を活用した階層的 IPv4 アクセス制御

* **問題:** 複数の管理者 IP（10.1.1.10, 10.1.1.11）から管理サーバー群（172.16.1.100, 172.16.1.101）に対する SSH (22), HTTPS (443), SNMP (161) アクセスのみを許可する効率的な ACL を構築せよ。
* **要件:**
  * ネットワークオブジェクトグループ `OG_ADMINS` および `OG_SERVERS` を作成すること。
  * サービスオブジェクトグループ `OG_MGMT_PORTS` を作成すること。
  * ACL 名: `ACL_MGMT_ACCESS`

* **設定例:**
```bash
! 1. ネットワークオブジェクトグループの定義
object-group network OG_ADMINS
 host 10.1.1.10
 host 10.1.1.11

object-group network OG_SERVERS
 host 172.16.1.100
 host 172.16.1.101

! 2. サービスオブジェクトグループの定義
object-group service OG_MGMT_PORTS
 tcp eq 22
 tcp eq 443
 udp eq 161

! 3. ACL の作成
ip access-list extended ACL_MGMT_ACCESS
 permit object-group OG_MGMT_PORTS object-group OG_ADMINS object-group OG_SERVERS
 deny ip any object-group OG_SERVERS log
 permit ip any any

! 4. インターフェイス適用
interface GigabitEthernet0/0/1
 ip access-group ACL_MGMT_ACCESS in
```

* **検証方法:**
  * `show object-group` でグループメンバーを確認。
  * `show ip access-lists ACL_MGMT_ACCESS` でオブジェクトグループが展開されてマッチしているか確認。

---

### ラボ 3: IPv6 Traffic Filter による NDP 保護 ＆ Web 制限

* **問題:** IPv6 ネットワーク 2001:DB8:100::/64 からの通信において、Web サーバー（2001:DB8:100::80）宛ての HTTP/HTTPS 通信のみを許可し、その他の通信をログ付きでドロップせよ。ただし、IPv6 近隣探索（NDP）が破棄されないよう完全保護せよ。
* **要件:**
  * ACL 名: `ACL_IPV6_WEB_ONLY`
  * NDP パケット（NS, NA, RS, RA）を明示許可すること。

* **設定例:**
```bash
ipv6 access-list ACL_IPV6_WEB_ONLY
 remark --- Explicitly Permit IPv6 NDP Messages ---
 permit icmp any any neighbor-solicitation
 permit icmp any any neighbor-advertisement
 permit icmp any any router-solicitation
 permit icmp any any router-advertisement
 remark --- Permit Web Traffic ---
 permit tcp 2001:DB8:100::/64 host 2001:DB8:100::80 eq www
 permit tcp 2001:DB8:100::/64 host 2001:DB8:100::80 eq 443
 remark --- Deny All Other Traffic with Logging ---
 deny ipv6 any any log-input

interface GigabitEthernet0/0/1
 ipv6 traffic-filter ACL_IPV6_WEB_ONLY in
```

* **検証方法:**
  * `show ipv6 neighbors` で近隣キャッシュが正常に維持されていることを確認（NDP が機能している証拠）。
  * 端末から 2001:DB8:100::80 へ Ping を送信し、ドロップされることおよびログが出力されることを確認。

---

### ラボ 4: Unicast RPF Strict モード ＋ ACL 例外 (Pass) 構成

* **問題:** インターフェイス Gi0/0/2 において uRPF Strict モードを有効化し、送信元 IP スプーフィングを防御せよ。ただし、非対称パス経由で到着する特定の運用テスト端末（10.99.99.1）のパケットは uRPF ドロップから救済（Pass）させよ。
* **要件:**
  * 例外用 ACL 名: `ACL_URPF_EXCEPT`

* **設定例:**
```bash
! 1. uRPF 例外用 ACL の作成 (permit された IP が uRPF 免除)
ip access-list standard ACL_URPF_EXCEPT
 permit host 10.99.99.1

! 2. インターフェイスへの uRPF Strict 適用
interface GigabitEthernet0/0/2
 ip verify unicast source reachable-via rx ACL_URPF_EXCEPT
```

* **検証方法:**
  * 10.99.99.1 から非対称パス経由でパケットを送出し、正常に通過することを確認。
  * その他の偽装送信元 IP パケットを送出し、`show ip interface Gi0/0/2` の `verification drops` が加算されることを確認。

---

### ラボ 5: Unicast RPF Loose モード ＋ BGP RTBH 統合

* **問題:** 対外 WAN 境界 Gi0/0/3 において、非対称ルーティングに対応可能な uRPF Loose モードを構成せよ。デフォルトルート経由の正常通信も許容すること。また、Null0 へルーティングされた攻撃元 IP（例: 192.0.2.123/32）が即座にドロップされることを検証せよ。
* **要件:**
  * `reachable-via any` および `allow-default` を使用すること。

* **設定例:**
```bash
! 1. WAN インターフェイスへの uRPF Loose 設定
interface GigabitEthernet0/0/3
 ip verify unicast source reachable-via any allow-default

! 2. ブラックホールルートの作成 (RTBH 連携)
ip route 192.0.2.123 255.255.255.255 Null0
```

* **検証方法:**
  * 送信元 IP 192.0.2.123 のパケットが Gi0/0/3 に到着した際、FIB ルックアップ結果が Null0 となるため uRPF ドロップされることを確認。
  * `show ip traffic` で `unicast RPF` ドロップ数が増加することを確認。

---

### ラボ 6: VRF-Aware Unicast RPF 構成

* **問題:** VRF `GUEST` がバインドされた サブインターフェイス Gi0/0/1.100 において、VRF テーブル内の経路情報を参照する uRPF Strict モードを有効化せよ。

* **設定例:**
```bash
interface GigabitEthernet0/0/1.100
 encapsulation dot1Q 100
 vrf forwarding GUEST
 ip address 10.200.1.1 255.255.255.0
 ip verify unicast source reachable-via rx
```

* **検証方法:**
  * `show ip interface Gi0/0/1.100` で VRF `GUEST` コンテキスト内で uRPF が有効化されていることを確認。
  * グローバルテーブルではなく VRF `GUEST` の FIB テーブルに基づいて RPF 検証が行われることを確認。

---

### ラボ 7: Reflexive ACL (IPv4 ステートフルフィルタリング) 構成

* **問題:** 内部 LAN（Gi0/0/1）から外部 WAN（Gi0/0/2）へ発生した TCP/ICMP 通信の戻りパケットのみを動的に許可し、外部からの未要求インバウンド通信を全ブロックせよ。
* **要件:**
  * 反射名: `REFLECT_SESSION`
  * Outbound ACL: `ACL_WAN_OUT`
  * Inbound ACL: `ACL_WAN_IN`

* **設定例:**
```bash
! 1. Outbound ACL (内部からの発信トラフィックを記録)
ip access-list extended ACL_WAN_OUT
 permit tcp any any reflect REFLECT_SESSION
 permit icmp any any echo reflect REFLECT_SESSION
 permit ip any any

! 2. Inbound ACL (動的セッションの評価とその他ブロック)
ip access-list extended ACL_WAN_IN
 evaluate REFLECT_SESSION
 deny ip any any log-input

! 3. インターフェイス適用
interface GigabitEthernet0/0/2
 ip access-group ACL_WAN_IN in
 ip access-group ACL_WAN_OUT out
```

* **検証方法:**
  * 内部から外部へ Ping / Telnet を実行し、疎通することを確認。
  * `show ip access-lists` を実行し、`Reflexive IP access list REFLECT_SESSION` に動的エントリが生成されていることを確認。

---

### ラボ 8: IPv6 Traffic Filter による Routing Extension Header (Type 0) 遮断

* **問題:** IPv6 セキュリティホールとなる Source Routing (Routing Extension Header Type 0) を含む全 IPv6 パケットをインターフェイス入口でドロップせよ。

* **設定例:**
```bash
ipv6 access-list ACL_BLOCK_RH0
 remark --- Block IPv6 Packets with Routing Extension Header ---
 deny ipv6 any any routing
 remark --- Allow NDP ---
 permit icmp any any neighbor-solicitation
 permit icmp any any neighbor-advertisement
 permit icmp any any router-solicitation
 permit icmp any any router-advertisement
 permit ipv6 any any

interface GigabitEthernet0/0/1
 ipv6 traffic-filter ACL_BLOCK_RH0 in
```

* **検証方法:**
  * `show ipv6 access-list ACL_BLOCK_RH0` で `deny ipv6 any any routing` のマッチカウントを確認。

---

### ラボ 9: uRPF ドロップパケットの Logging ＆ カウンタ追跡

* **問題:** インターフェイス Gi0/0/1 で uRPF Strict モードを有効化し、uRPF チェックに違反してドロップされた全パケットの送信元 MAC / IP 情報を Syslog に記録せよ。

* **設定例:**
```bash
! 1. 例外用 ACL に deny アクション ＋ log-input を指定するアプローチ
ip access-list standard ACL_LOG_URPF_DROP
 deny any

! 2. インターフェイス設定
interface GigabitEthernet0/0/1
 ip verify unicast source reachable-via rx
```

* **検証方法:**
  * 偽装パケット送信時に `%SEC-6-IPACCESSLOGP` 相当のログが出力されるか、または `show ip interface` でドロップ数を確認。

---

### ラボ 10: デュアルスタック (IPv4/IPv6) 統合ルータセキュリティ構成

* **問題:** WAN 境界ルータの Gi0/0/0 インターフェイスにおいて、IPv4 拡張 ACL、IPv6 Traffic Filter、および uRPF Loose モードを同時に適用し、包括的な境界セキュリティを実現せよ。

* **設定例:**
```bash
! --- IPv4 ACL ---
ip access-list extended ACL_WAN_IPV4_IN
 deny ip 10.0.0.0 0.255.255.255 any log-input
 deny ip 172.16.0.0 0.15.255.255 any log-input
 deny ip 192.168.0.0 0.0.255.255 any log-input
 permit ip any any

! --- IPv6 ACL ---
ipv6 access-list ACL_WAN_IPV6_IN
 permit icmp any any neighbor-solicitation
 permit icmp any any neighbor-advertisement
 permit icmp any any router-solicitation
 permit icmp any any router-advertisement
 deny ipv6 2001:DB8:BAD::/48 any log-input
 permit ipv6 any any

! --- Interface Configuration ---
interface GigabitEthernet0/0/0
 ip access-group ACL_WAN_IPV4_IN in
 ipv6 traffic-filter ACL_WAN_IPV6_IN in
 ip verify unicast source reachable-via any allow-default
```

* **検証方法:**
  * `show ip access-lists`, `show ipv6 access-list`, `show ip interface Gi0/0/0` の各出力結果を検証。


---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** ルータ R1 の IPv6 インターフェイス Gi0/0/1 にて以下のコンフィグを適用した直後、対向ルータとの OSPFv3 隣接関係が `INIT/DROPPED` となり完全に切断された。
```bash
ipv6 access-list V6_SECURITY
 permit tcp any host 2001:DB8:1::100 eq www
 deny ipv6 any any log-input

interface GigabitEthernet0/0/1
 ipv6 traffic-filter V6_SECURITY in
```
**設問:** この切断障害の直接的原因と、OSPFv3 隣接関係を復旧させるための最小限のコンフィグ修正内容を答えよ。

* **解答:**
  * **原因:** IPv6 ACL の末尾に明示的な `deny ipv6 any any log-input` を記述したことにより、標準で処理される暗黙の NDP (ICMPv6 NS/NA) 許可ルールが評価されなくなり、OSPFv3 や L2 アドレス解決に必要な ICMPv6 近隣探査パケットがすべてドロップされたため。
  * **修正コマンド:**
```bash
ipv6 access-list V6_SECURITY
 sequence 5 permit icmp any any neighbor-solicitation
 sequence 6 permit icmp any any neighbor-advertisement
```

---

### 問 2 (Design / uRPF)
**シナリオ:** 企業 WAN エッジルータが 2 社の異なる ISP（ISP-A, ISP-B）と BGP でデュアルホーム接続されている。アウトバウンドトラフィックは ISP-A を優先利用するが、インバウンドトラフィックは ISP-B から受信する非対称パスが発生している。
**設問:** IP スプーフィング攻撃を防御するために WAN インターフェイスへ uRPF を導入する場合、Strict モードと Loose モードのどちらを選定すべきか。また、その技術的理由と必要なオプションコマンドを述べよ。

* **解答:**
  * **選定:** **Loose モード** を選定する。
  * **技術的理由:** Strict モードはパケットの「到着ポート」と「FIBの戻りポート」の一致を要求するため、非対称パス環境では正常なインバウンドトラフィックが誤ってドロップされる。Loose モードであれば、送信元 IP が FIB テーブル上に存在することのみを検証するため、非対称パスでも正常に通信を許可できる。
  * **必要なオプション:** デフォルトルート経由の到達性を RPF チェック対象として含めるため、**`allow-default`** オプションを指定する（`ip verify unicast source reachable-via any allow-default`）。

---

### 問 3 (トラブルシューティング / uRPF)
**シナリオ:** ルータの Gi0/0/2 インターフェイスで `ip verify unicast source reachable-via rx` を設定したところ、すべてのパケットが RPF チェックに失敗してドロップされた。`show ip route` では送信元 IP への経路が正常に存在している。
**設問:** uRPF が正常に動作していない根本的な原因として何が考えられるか。

* **解答:**
  * **原因:** ルータ上で **Cisco Express Forwarding (CEF)** が無効化されている（`no ip cef` 状態）。uRPF は CEF テーブル（FIB）を直接参照して動作するため、CEF が無効な環境では RPF 検証が機能せず全パケットがドロップされる。
  * **修復コマンド:** グローバルコンフィグモードで `ip cef` を有効化する。

---

### 問 4 (実装 / IPv4 ACL)
**シナリオ:** 172.16.10.0/24 サブネットからの ICMP 通信のみを拒否し、その他の全 IP 通信を許可するインバウンド ACL を作成し、Gi0/0/1 に適用せよ。
**設問:** 最小行数で構成されるコンフィグを記述せよ。

* **解答:**
```bash
ip access-list extended ACL_BLOCK_ICMP
 deny icmp 172.16.10.0 0.0.0.255 any
 permit ip any any

interface GigabitEthernet0/0/1
 ip access-group ACL_BLOCK_ICMP in
```

---

### 問 5 (コンフィグ読解 / uRPF ACL)
**シナリオ:** 以下のコンフィグが設定されたルータがある。
```bash
ip access-list standard ACL_EXCEPT
 permit host 192.168.50.10

interface GigabitEthernet0/0/1
 ip verify unicast source reachable-via rx ACL_EXCEPT
```
**設問:** 送信元 IP が 192.168.50.10 であるパケットが非対称パス（到着ポート不一致）で Gi0/0/1 に到着した場合、このパケットはドロップされるか、許可されるか。理由とともに答えよ。

* **解答:**
  * **判定:** **許可される（通過する）。**
  * **理由:** uRPF 設定コマンドで指定された ACL 内の `permit` ステートメントは、「uRPF チェックの免除（Pass）」を意味する。したがって、192.168.50.10 は RPF チェックが失敗してもドロップされずに通過する。

---

## 🔗 参考リソース

* Cisco Configuration Guide: Access Control Lists (Cisco IOS XE)
* Cisco Configuration Guide: IPv6 Traffic Filters and ACLs
* Cisco Technical Notes: Understanding Unicast Reverse Path Forwarding (uRPF)
* Cisco Live: BRKSEC-2001 - Router Security and Traffic Filtering Best Practices
* IETF RFC 3704: Ingress Filtering for Multihomed Networks (uRPF Specification)

---

## 📝 **補足（Notes）**

* **学習メモ:** IPv6 ACL の記述時は常に ICMPv6 (NDP) の存在を頭に置くこと。特に試験問題で「log を出力せよ」という要件がある場合、安易に `deny ipv6 any any log` を追加すると NDP が落ちる罠が頻出する。
* **図解注意点:** uRPF Strict と Loose の違いは「到着ポートをチェックするかどうか」に尽きる。
* **注意点:** uRPF ACL 例外機能の `permit` ＝ 「uRPF スキップ（通過）」という直感と逆の定義ルールを忘れないこと。




## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKSEC-2001: Layer 2 Security Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001) - ACL と uRPF の基礎となるセキュリティ設計。
*   [**BRKIPV-3134: IPv6 Security with First Hop Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPV-3134) - IPv6 独自のトラフィックフィルタ要件について。

### Configuration ガイド
*   [**Securing IPv4/IPv6 Access Control Lists**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg/m_acl_config.html)。
*   [**Configuring Unicast Reverse Path Forwarding**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_urpf/configuration/xe-17/sec-data-urpf-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**IP Access List Overview (Cisco Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/access-lists/26448-10.html)。
*   [**Understanding Unicast Reverse Path Forwarding (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/security-software/ios-firewall/13644-urpf.html)。

---

## 📝 補足
- この学習メモは、ルータにおける基本的なトラフィック制御と、IP アドレスの正当性を保証する技術を網羅しています。CCIE ラボ試験では、**IPv6 における暗黙の ICMPv6 許可の有無**や、**uRPF がルーティングテーブルの「どの」情報（FIB）を参照しているか**を意識した実装が合格のポイントとなります,。


