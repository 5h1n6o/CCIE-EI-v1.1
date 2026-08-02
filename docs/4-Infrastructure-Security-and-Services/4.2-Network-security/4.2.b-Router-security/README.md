---
layout: default
title: 4.2.b-Router-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.2.b ルータセキュリティ機能

Cisco IOS XE ルータにおけるセキュリティ機能は、コントロールプレーンの保護（CoPP等）と並び、データプレーンを通過するトラフィックを精査し、不正なアクセスやなりすましを防御するための重要なコンポーネントです,。本稿では、IPv4/IPv6 のトラフィックフィルタリング（ACL）および送信元偽装対策である uRPF について詳述します。

---

## 📘 概要

ルータセキュリティ機能の主目的は、ネットワークの境界（Edge）において許可されたトラフィックのみを転送し、潜在的な攻撃を最小限に抑えることにあります。

*   **IPv4/IPv6 トラフィックフィルタリング:** 送信元/宛先 IP、プロトコル、ポート番号などに基づいてパケットの転送可否を決定します。IPv4 では番号付きや名前付きの ACL が存在しますが、IPv6 では名前付き ACL のみがサポートされるといった違いがあります。
*   **Unicast Reverse Path Forwarding (uRPF):** 入力パケットの送信元 IP アドレスをルーティングテーブル（FIB）と照合し、正当な経路から届いているかを確認することで、IP スプーフィング（なりすまし）を防止します,。

---

## 🔑 要点

### 1. IPv4 Access Control Lists (ii)

IPv4 ACL はパケットフィルタリングの基本です。
*   **標準 ACL (Standard):** 送信元 IP アドレスのみをチェックします（1-99, 1300-1999）。
*   **拡張 ACL (Extended):** 送信元/宛先 IP、プロトコル、L4 ポート番号、TCP フラグ（established 等）をチェックします（100-199, 2000-2699）,。
*   **フラグメント処理:** <code>fragments</code> キーワードを使用することで、分割されたパケット（非初発フラグメント）を特定してドロップまたは許可できます,。
*   **時間制限 (Time-based):** <code>time-range</code> を定義し、特定の時間帯のみ有効な ACL を作成可能です,。

### 2. IPv6 Traffic Filters (i)

IPv6 における ACL は「トラフィックフィルタ」と呼ばれ、IPv4 とは一部挙動が異なります。
*   **名前付きのみ:** IPv6 では番号付き ACL は存在せず、すべて <code>ipv6 access-list</code> として定義します。
*   **暗黙の許可:** ACL の最後には <code>deny ipv6 any any</code> が存在しますが、その前に Neighbor Discovery（NS/NA）を維持するための **「暗黙の ICMPv6 許可（NDP 用）」** が含まれていることに注意が必要です。
*   **拡張ヘッダーのフィルタリング:** ルーティングヘッダーやホップバイホップヘッダーの有無に基づくフィルタリングが可能です。

### 3. Unicast Reverse Path Forwarding (uRPF) (iii)

送信元 IP の妥当性を検証する機能です。
*   **Strict Mode:** 送信元 IP への最適ルートが、パケットが **「届いたインターフェイス」** と一致することを条件とします。
*   **Loose Mode:** 送信元 IP がルーティングテーブル（FIB）に存在すれば、インターフェイスを問わず許可します。非対称ルーティング環境で使用されます。
*   **Allow-default:** デフォルトルートを有効な戻りパスとしてカウントさせるオプションです。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単純な許可/拒否だけでなく、以下の高度な制御が問われます。

### 1. ワイルドカードマスクによるビット単位の抽出

*   **課題:** 「第 3 オクテットが奇数の IP アドレスのみをブロックせよ」といった要件。
*   **対策:** <code>0.0.1.255</code> のようなマスクを使用し、特定のビット（この場合は最下位ビット 1）をマッチさせる技術が必要です,。

### 2. オブジェクトグループによる簡素化

*   大量のサーバー IP やポート番号を個別に記述せず、<code>object-group ip address</code> や <code>object-group service</code> でまとめて管理する手法が推奨されます,。

### 3. ACL の編集とシーケンス番号

*   既存の ACL の間にエントリを挿入する場合、<code>resequence</code> コマンドで番号を振り直すタスクが想定されます,。

### 4. uRPF の例外処理

*   uRPF を有効にしつつ、特定のサブネット（例：マルチキャストや正当な非対称パス）をドロップさせないための ACL 併用（ACL を使った uRPF チェックの例外）が問われることがあります。

---

## 🛠 設定・検証コマンド

### トラフィックフィルタリング

| 目的 | コマンド |
| :--- | :--- |
| **名前付き IPv4 拡張 ACL 作成** | <code>ip access-list extended [NAME]</code> |
| **ACL エントリの定義** | <code>[permit&#124;deny] [proto] [src] [dst] eq [port]</code> |
| **フラグメントの拒否** | <code>deny ip any any fragments</code> |
| **IPv4 ACL の適用** | <code>(config-if)# ip access-group [NAME] [in&#124;out]</code> |
| **IPv6 ACL の作成** | <code>ipv6 access-list [NAME]</code> |
| **IPv6 トラフィックフィルタ適用** | <code>(config-if)# ipv6 traffic-filter [NAME] [in&#124;out]</code> |

### Unicast RPF

| 目的 | コマンド |
| :--- | :--- |
| **Strict Mode 有効化** | <code>(config-if)# ip verify unicast source reachable-via rx</code> |
| **Loose Mode 有効化** | <code>(config-if)# ip verify unicast source reachable-via any</code> |
| **デフォルトルートを許容** | <code>(config-if)# ip verify unicast source ... allow-default</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **ACL ヒット数の確認** | <code>show access-lists [NAME]</code> |
| **IPv6 ACL ヒット数確認** | <code>show ipv6 access-list</code> |
| **uRPF 統計情報の確認** | <code>show ip interface [ID] &#124; include verify</code> |
| **ACL シーケンス番号変更** | <code>ip access-list resequence [NAME] [START] [INC]</code> |

---

## 🧪 ラボ学習・設定サンプル例

ソース資料（iPexpert, Narbik 等）のタスクに基づく実戦的な実装例です。

### 1. 第3オクテットが奇数のネットワークのフィルタリング

**【問題】** 10.1.x.0 のうち、x が奇数のルートのみを R9 で遮断せよ。
```ios
ip access-list standard ACL_ODD_OCTET
 deny 10.1.1.0 0.0.254.255  ! 奇数ビット(1)をチェック
 permit any
!
interface Ethernet0/0
 ip access-group ACL_ODD_OCTET in
```

---

### 2. 全ての IPv4 フラグメントパケットの遮断

**【問題】** セキュリティポリシーに基づき、ルータを通過する分割されたパケットをすべて破棄せよ。
```ios
ip access-list extended BLOCK_FRAGS
 5 deny ip any any fragments
 10 permit ip any any
!
interface GigabitEthernet1
 ip access-group BLOCK_FRAGS in
```

---

### 3. 時間制限付き HTTP アクセス制御

**【問題】** 勤務時間（月-金 9:00-17:00）のみ、特定のサーバー (172.16.1.10) への Web アクセスを許可せよ。
```ios
time-range WORK_HOURS
 periodic weekdays 09:00 to 17:00
!
ip access-list extended ACL_WEB_RESTRICT
 permit tcp any host 172.16.1.10 eq 80 time-range WORK_HOURS
 deny tcp any host 172.16.1.10 eq 80
 permit ip any any
```

---

### 4. IPv6 拡張ヘッダー（Routing Header）の拒否

**【問題】** 送信元で経路を指定する IPv6 Routing Extension Header を含むパケットを拒否せよ。
```ios
ipv6 access-list V6_SEC_FILTER
 deny ipv6 any any routing
 permit ipv6 any any
!
interface Ethernet0/1
 ipv6 traffic-filter V6_SEC_FILTER in
```

---

### 5. uRPF Strict Mode の実装（デフォルトルート許容）

**【問題】** 偽装パケットを防止するため Strict モードを有効にせよ。ただし、デフォルトルートのみを持つ送信元も許可すること。
```ios
interface GigabitEthernet2
 ip verify unicast source reachable-via rx allow-default
```

---

### 6. オブジェクトグループを用いた DNS フィルタリング

**【問題】** 複数の DNS サーバーへの通信をオブジェクトグループを使って 1 行で許可せよ。
```ios
object-group ip address DNS_SERVERS
 host 8.8.8.8
 host 8.8.4.4
!
ip access-list extended ACL_DNS_POLICY
 permit udp any object-group DNS_SERVERS eq 53
```

---

### 7. IPv6 Neighbor Discovery の維持

**【問題】** IPv6 ACL を適用しつつ、OSPFv3 と Neighbor Discovery が正常に動作するようにせよ（明示的設定例）。
```ios
ipv6 access-list ALLOW_CORE_V6
 permit icmp any any nd-na
 permit icmp any any nd-ns
 permit ospf any any
 deny ipv6 any any log-input
```

---

### 8. ACL のシーケンス番号リシーケンス

**【問題】** ACL "MGMT" の番号がバラバラなため、10番開始、10番刻みに整理せよ。
```ios
ip access-list resequence MGMT 10 10
!
! 検証
show access-lists MGMT
```

---

### 9. 特定 MAC アドレスのレイヤ 3 フィルタリング

**【問題】** 特定の攻撃者 MAC (0001.0012.2222) からの IP 通信を遮断せよ。
```ios
! 注意: これは PACL または VACL での実装が一般的
mac access-list extended BLOCK_MAC
 deny host 0001.0012.2222 any
 permit any any
!
vlan access-map VMAP_MAC 10
 match mac address BLOCK_MAC
 action forward
```

---

### 10. uRPF Loose Mode による非対称ルーティング対応

**【問題】** 複数のプロバイダーと接続している境界ルータで、戻りパスが異なる可能性がある環境でスプーフィング対策を行え。
```ios
interface Ethernet0/0
 ip verify unicast source reachable-via any
```

---

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


