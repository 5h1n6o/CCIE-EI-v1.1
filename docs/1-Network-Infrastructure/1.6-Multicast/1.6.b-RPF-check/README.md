---
layout: default
title: 1.6.b-RPF-check
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.6.b Reverse Path Forwarding (RPF) Check

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.6 Multicast」における「1.6.b Reverse path forwarding (RPF) check」について、技術的深掘りと実装シナリオを詳細に整理しました。

---

## 📘 概要

**Reverse Path Forwarding (RPF) Check** は、IPマルチキャストルーティングにおけるループ防止とパケット転送の可否を決定するための最も基本的かつ重要なメカニズムです。ユニキャストルーティングが「宛先へのパス」を基準にパケットを転送するのに対し、マルチキャストは「送信元（Source）へのパス」を基準にして転送の正当性を判断します。

マルチキャストルータは、マルチキャストパケットを受信した際、そのパケットの **送信元IPアドレス** に基づいてRPFチェックを実行します。パケットが「自身のユニキャストルーティングテーブルに従って、その送信元へ到達するために使用するはずのインターフェイス（RPFインターフェイス）」から流入してきた場合のみ、RPFチェックをパス（成功）とし、パケットの複製と転送（フォワーディング）を継続します。もし、期待されるインターフェイス以外から流入した場合は、ループの可能性があると見なされ、パケットは即座に破棄（ドロップ）されます。

CCIE EIレベルでは、単一のユニキャストルーティングテーブルに依存しない **Multiprotocol BGP (MBGP)** や **Static Multicast Routes (mroute)** が混在する環境、および **GRE/DMVPNトンネル** を介した複雑なトポロジにおけるRPFの挙動を完璧に制御する能力が問われます。

---

## 🔑 要点

### 1. RPF インターフェイスの選出ロジック

ルータは以下の優先順位に従って、特定の送信元（Source）またはランデブーポイント（RP）に対するRPFインターフェイスを決定します。

1.  **最長一致（Longest Match）:** 静的マルチキャストルート（`ip mroute`）、MBGP、またはユニキャストRIBの中から、送信元アドレスに最も近く一致するプレフィックスを探します。
2.  **アドミニストレーティブ・ディスタンス（AD）:** 複数の情報源（例：EIGRPルート vs BGPマルチキャストルート）がある場合、AD値が最も低いものが優先されます。
3.  **メトリック:** 同一AD値の場合は、送信元へのメトリックが最も低いインターフェイスが選出されます。
4.  **タイブレーカー:** すべてが同一の場合、通常は隣接ルータのIPアドレスが高い方が選ばれる等の実装依存のルールがあります。

### 2. PIM モードによる RPF 対象の違い

使用している PIM (Protocol Independent Multicast) の動作モードによって、RPFをチェックする対象アドレスが異なります。

*   **PIM Dense Mode / PIM-SM (S,G) Entry:** マルチキャストトラフィックの **送信元（Source）** のIPアドレスに対してRPFチェックを行います。
*   **PIM Sparse Mode (*,G) Entry:** 共有ツリー上では、**ランデブーポイント（RP）** のIPアドレスに対してRPFチェックを行います。

### 3. RPF 情報を供給するデータベース

OSPFやEIGRPといったユニキャストルーティングプロトコル以外に、マルチキャスト専用のRPFトポロジを構築する手段があります。

*   **Static Mroute (`ip mroute`):** ユニキャストの経路とは無関係に、マルチキャスト専用のRPFインターフェイスを静的に定義します。
*   **Multiprotocol BGP (Address Family IPv4 Multicast):** BGPを利用してマルチキャスト専用のトポロジ情報を交換します。これはユニキャストの経路が非対称な場合や、特定のリンクをマルチキャスト専用にしたい場合に極めて有効です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、意図的にRPFチェックを失敗させる「非対称ルーティング」や「トンネル環境での不整合」がトラブルシューティングの主要なターゲットとなります。

### 1. トンネル越し（GRE/DMVPN）の RPF 失敗

マルチキャストをトンネル経由で通そうとする際、ユニキャストのベストパスが物理インターフェイスを指していると、トンネル経由で届いたマルチキャストパケットはRPF失敗となります。
*   **対策:** `ip mroute` を使用して、送信元へのRPFがトンネルインターフェイスを向くように明示的に設定する必要があります。

### 2. MBGP によるトポロジ分離

「ユニキャストトラフィックは R1-R2 間の低速リンクを通るが、マルチキャストは R1-R3 間の高速リンクを通るようにせよ」という要件。
*   **対策:** MBGP (Address Family IPv4 Multicast) で R1-R3 間のネクストホップを広報します。OSPF等のユニキャストメトリックをいじる必要がないため、ネットワーク全体の安定性を損なわずにマルチキャストのみを誘導できます。

### 3. RPF チェックと ECMP (Equal-Cost Multi-Path)

送信元への等コストパスが複数ある場合、デフォルトでは1つのインターフェイスのみがRPFとして選ばれます。
*   **注意:** PIMの設定で `ip pim multipath` や `ip multicast multipath` コマンドが有効になっていない限り、負荷分散は行われません。ラボでの「特定のパスを通らない」という問題の切り分けに重要です。

### 4. BGP Default Route の挙動

BGPで 0.0.0.0/0 を学習している場合、マルチキャストルータはデフォルトではこれをRPFチェックの対象外とすることがあります（実装によりますが、明示的な許可が必要な場合があります）。スタティックのデフォルトルートとは挙動が異なる場合があるため注意が必要です。

---

## 🛠 設定・検証コマンド

### RPF 制御コマンド

| 目的 | コマンド |
| :--- | :--- |
| **静的RPFルートの設定** | <code>ip mroute [送信元NW] [マスク] [RPF_INT&#124;次ホップIP]</code> |
| **MBGP AFの有効化** | <code>address-family ipv4 multicast</code> |
| **PIM負荷分散の有効化** | <code>ip multicast multipath</code> |
| **マルチキャスト境界の定義** | <code>ip multicast boundary [ACL]</code> |

### 検証・トラブルシューティングコマンド

| 目的 | コマンド |
| :--- | :--- |
| **RPF情報の直接確認 (最重要)** | <code>show ip rpf [送信元IP]</code> |
| **マルチキャスト経路詳細表示** | <code>show ip mroute [グループIP] [detail]</code> |
| **RPF失敗パケットの統計確認** | <code>show ip mroute count</code> |
| **隣接ルータ情報の確認** | <code>show ip pim neighbor</code> |
| **PIMインターフェイスの状態** | <code>show ip pim interface</code> |
| **MBGPで学習したRPFルート確認** | <code>show ip bgp ipv4 multicast</code> |
| **デバッグ (RPF/PIMイベント)** | <code>debug ip pim [group]</code> <br> <code>debug ip mrouting</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 基本的な Static Mroute による RPF 回復

**【問題内容】**
R1 は R3 からマルチキャストを受信しているが、R1 のユニキャストルートは R2 を向いている。R1-R3 間の直接リンクをマルチキャスト RPF として使用するように設定せよ。

**【設定例】**
```ios
! R1 側で設定
! 送信元 10.1.3.0/24 へのRPFを Gi0/3 インターフェイスに固定
ip mroute 10.1.3.0 255.255.255.0 GigabitEthernet0/3
```

---

### 2. MBGP を用いた非対称 RPF の構成

**【問題内容】**
ユニキャストは OSPF を使用し、マルチキャスト RPF 情報は BGP を使用して R1 と R2 の間で交換せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.12.2 remote-as 100
 address-family ipv4 multicast
  neighbor 10.1.12.2 activate
  network 10.1.1.0 mask 255.255.255.0
```

---

### 3. GRE トンネルを介した RPF 設定

**【問題内容】**
R1 と R4 の間に GRE トンネルを構築した。R4 背後のマルチキャストソース (10.4.4.4) からのパケットをトンネルインターフェイス経由で受け入れるように R1 を構成せよ。

**【設定例】**
```ios
! R1 側
interface Tunnel0
 ip pim sparse-mode
!
ip mroute 10.4.4.4 255.255.255.255 Tunnel0
```

---

### 4. PIM-SM (*,G) に対する RP への RPF 確認

**【問題内容】**
PIM Sparse-Mode 環境において、共有ツリー (*,G) が構築されない原因が RP (1.1.1.1) への RPF 失敗であることを確認し、修正せよ。

**【検証・設定】**
```ios
R2# show ip rpf 1.1.1.1
! 期待される出力がない、あるいは不正なIFを向いている場合
R2(config)# ip mroute 1.1.1.1 255.255.255.255 10.1.12.1
```

---

### 5. Distance 操作による RPF 選択の優先順位変更

**【問題内容】**
EIGRP で学習しているユニキャストパスよりも、Static mroute で設定したパスを優先して RPF として使用させよ。

**【設定例】**
```ios
! ip mroute のデフォルトADは 0 なので通常は最優先されるが
! 明示的に指定する場合
ip mroute 10.0.0.0 255.0.0.0 10.1.12.2 1  ! ADを 1 に設定
```

---

### 6. MBGP とユニキャスト再配送の使い分け

**【問題内容】**
OSPF ルートを BGP マルチキャストアドレスファミリーへ再配送し、BGP ネイバーへ RPF 情報として通知せよ。

**【設定例】**
```ios
router bgp 100
 address-family ipv4 multicast
  redistribute ospf 1
```

---

### 7. RPF 失敗時のデバッグ出力の解析

**【問題内容】**
マルチキャストパケットがドロップされている理由を debug コマンドで特定せよ。

**【検証】**
```ios
R1# debug ip mrouting
! 出力例: "MRT: RPF lookup failed for 10.1.1.100" 
! を確認し、show ip rpf 10.1.1.100 で不整合を特定する
```

---

### 8. マルチキャスト ECMP 負荷分散の設定

**【問題内容】**
2つの等コストパス（Gi0/1 と Gi0/2）を両方 RPF インターフェイスとして使用し、グループごとにパスを分散させよ。

**【設定例】**
```ios
ip multicast multipath
! または
ip pim multipath
```

---

### 9. VRF 環境における RPF 設定

**【問題内容】**
VRF「CUSTOMER_A」において、マルチキャスト RPF を静的に設定せよ。

**【設定例】**
```ios
ip mroute vrf CUSTOMER_A 192.168.10.0 255.255.255.0 172.16.1.1
```

---

### 10. DMVPN Phase 3 での RPF 解決

**【問題内容】**
DMVPN スポーク間で直接マルチキャストを転送させるため、NHS (Hub) への RPF 依存を解消する NHRP マッピングを確認せよ。

**【設定例】**
```ios
interface Tunnel0
 ip nhrp map multicast dynamic
! 検証
show ip rpf [Spoke_Loopback]
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKIPM-2264: IP Multicast Logic and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)
    *   RPFチェックのロジックと、失敗時の詳細なデバッグ手法が解説されています。
*   [**BRKENS-2001: Multicast Primer**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2001)
    *   RPFの基礎から、MBGPを用いた設計上のベストプラクティスまで。
*   [**BRKCCIE-3000: BGP and Multicast for the CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   CCIEラボ試験において、RPFの「ひねり」がどのように出題されるかに特化した内容です。

### Configuration ガイド
*   [IP Multicast: PPF Check Configuration (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-17/imc-pim-xe-17-book.html)
*   [Configuring Multiprotocol BGP for Multicast](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-multicast-bgp.html)。

### テクニカルノーツ・設定例
*   [Multicast Reverse Path Forwarding (RPF) Check FAQ](https://www.cisco.com/c/en/us/support/docs/ip/multicast/16450-mcast-rpf.html)
*   [Troubleshooting RPF Failures in Multicast Networks](https://www.cisco.com/c/en/us/support/docs/ip/multicast/13717-49.html)。

---

## 📝 補足

- この学習メモは、RPFチェックが単なる「セキュリティ機能」ではなく、マルチキャストにおける「正しい方向の定義」であることを強調しています。CCIE実技試験では、ユニキャストの経路変更がマルチキャストに波及する二次的なトラブル（Side effects）を迅速に発見し、`show ip rpf` で論理的な裏付けを取るプロセスが合否を分けます。


