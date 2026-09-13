---
layout: default
title: 1.6.b-RPF-check
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.6.b Reverse path forwarding check

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における IP マルチキャスト（および Unicast uRPF）の最重要ルーティング検証メカニズムである **Reverse Path Forwarding Check (RPF Check / RPF 検証)** について、Cisco IOS-XE 17.x（Catalyst 9000 シリーズ、Catalyst 8000v 等）の実装基準に 100% 準拠して詳細に解説します。

---

## 📘 概要

**Reverse Path Forwarding (RPF) Check** とは、ルータが受信したマルチキャストパケット（またはユニキャストパケット）の**送信元 IP アドレス（Source IP）** を参照し、「そのパケットが正しく想定通りのインターフェイス（Reverse Path）から到着したか」を判定するループ防止およびセキュリティ検証メカニズムです。

ユニキャストルーティングが**「宛先 IP アドレス（Destination IP）」** を見てパケットをどのインターフェイスから「送出すべきか（Forwarding）」を決めるのに対し、マルチキャストルーティングは**「送信元 IP アドレス（Source IP）」** を見てパケットがどのインターフェイスから「到着したか（Incoming）」を検証します。RPF Check に合格（Pass）したパケットのみがマルチキャストルーティングテーブル（mroute: OIL = Outgoing Interface List）に従って転送され、不合格（Fail）となったパケットは即座に破棄（Drop）されます。

### 主な利用目的と適用シーン

1. **マルチキャストトラフィックの永久ルーティングループ防止:**  
   マルチキャストパケットには TTL 以外のループ検出ヘッダー（AS_PATH や LSA のような機構）が存在しないため、RPF Check が存在しないとループトポロジー内でパケットが無限に増殖・ループします。

2. **マルチキャスト配送ツリー（SPT / Shared Tree）の正常構築:**  
   PIM Sparse-Mode において、(S,G) の SPT（Shortest Path Tree）構築や (*,G) の RPT（Rendezvous Point Tree）構築時、アップストリームネイバー（RPF Neighbor）を決定する基準となります。

3. **非対称ルーティング環境におけるマルチキャスト通信障害の補正 (Static Mroute):**  
   ユニキャスト経路とマルチキャスト経路が異なる物理パス（非対称パス）を通る場合、デフォルトの RPF Check は失敗します。`ip mroute` (Static Mroute) や MP-BGP を用いて RPF ネクストホップを手動補正します。

4. **セキュリティ向上 (Unicast RPF / uRPF):**  
   1.6.b の概念は 4.2.b (iii) Unicast Reverse Path Forwarding (uRPF Strict/Loose Mode) にも直結し、IP スプーフィング攻撃を水際で防止します。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 到着パケットの Source IP に対し、ユニキャスト RIB / MRIB を逆引きして「パケットが入ってくるべき正しい Ingress ポート」と「RPF Neighbor」を判定。 |
| **用途** | IP マルチキャストパケットのループ防止、PIM Join/Prune メッセージの送信先決定、uRPF による IP スプーフィング防止。 |
| **メリット** | トポロジー構造に関わらずマルチキャストループを 100% 防止可能。コントロールプレーンのオーバーヘッドを抑えてデータプレーンで即時破棄。 |
| **デメリット** | ユニキャスト経路が非対称（Asymmetric Routing）である場合、正しいマルチキャストパケットが誤って RPF Fail で破棄される。 |
| **対応機種** | Catalyst 9200/9300/9400/9500/9600, Catalyst 8000v, ISR 4000, ASR 1000 等（Cisco IOS-XE 全般）。 |
| **制限事項** | ECMP（等コストマルチパス）環境下において、デフォルトでは「最も高い IP アドレスを持つ RPF Neighbor」が単一選出され、マルチパスロードバランシングされない（`ip pim multipath` が必要）。 |
| **設計上の注意点** | GRE / DMVPN などのトンネル構成や、BGP / OSPF / EIGRP の経路再配送が絡むネットワークでは、RPF パスとユニキャストパスの不一致が多発するため事前の RPF 監査が必須。 |

---

## 🏗 動作原理

### 1. マルチキャスト RPF Check の基本フロー

```text
[ Multicast Source ] S = 10.1.1.100
        │
        ▼
   (Gi0/1: 10.1.1.1)
┌────────────────────────────────────────────────────────┐
│ Router R1                                              │
│ 1. パケット受領: Src=10.1.1.100, Dst=239.1.1.1          │
│ 2. RPF Check 実行:                                      │
│    - Lookup Unicast RIB for 10.1.1.100                │
│    - Next-Hop Interface = Gi0/1                        │
│ 3. 比較: パケット到着ポート(Gi0/1) == RPF Port(Gi0/1) ?  │
└────────────────────────────────────────────────────────┘
        │
        ├───────────────────────┬───────────────────────┐
     [ PASS ]                [ FAIL ]               [ FAIL ]
  Arrived on Gi0/1        Arrived on Gi0/2       Arrived on Gi0/3
        │                       │                       │
        ▼                       ▼                       ▼
  パケットを OIL へ転送   パケットを即時破棄     パケットを即時破棄
  (Forward Packet)       (RPF Drop Count +1)    (RPF Drop Count +1)
```

### 2. PIM Sparse-Mode における RPF の二重性 ((S,G) vs (*,G))

* **(*,G) RPT (Shared Tree) の RPF Check:**  
  * 対象アドレス: **RP (Rendezvous Point) の IP アドレス**  
  * ルータは RP の IP アドレスに対してユニキャスト RIB を参照し、RP に向かうインターフェイスを Incoming Interface、そのネクストホップルータを **RPF Neighbor** とみなします。
* **(S,G) SPT (Shortest Path Tree) の RPF Check:**  
  * 対象アドレス: **マルチキャスト送信元 (Source) の IP アドレス**  
  * ルータは送信元ホストの IP アドレスに対してユニキャスト RIB を参照し、送信元に向かうインターフェイスを Incoming Interface、そのネクストホップルータを **RPF Neighbor** とみなします。

---

## ⚙ 動作シーケンス

```text
1. [パケット受信]
   マルチキャストパケット (Src: 10.1.1.100, Dst: 239.1.1.1) が Interface Gi0/2 に到着。

2. [MRIB / Unicast RIB ルックアップ]
   ルータは Src IP (10.1.1.100) に合致するロンゲストマッチ経路をユニキャスト RIB (または MRIB / Static Mroute) から検索。

3. [RPF インターフェイス & RPF Neighbor の決定]
   RIB 検索結果:
   - プレフィックス: 10.1.1.0/24
   - 出力インターフェイス: GigabitEthernet0/1
   - ネクストホップ IP: 10.1.12.1 (RPF Neighbor)

4. [RPF 適合判定 (RPF Check)]
   パケット受信用 Port (Gi0/2) と RIB 検索結果 Port (Gi0/1) を照合。
   -> 不一致 (Gi0/2 != Gi0/1) ⇒ RPF FAIL

5. [パケット破棄 & カウンタ加算]
   パケットを CEF / データプレーン階層で即座にドロップ。
   `show ip mroute count` の "RPF-failed" カウンタを +1 インクリメント。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、1.6.b RPF Check は「RPF チェックを設定しなさい」という直接的な設問ではなく、**「マルチキャスト通信が通らない障害のトラブルシューティング」** や **「非対称ルーティング環境で Static Mroute / MP-BGP を使用して RPF を正常化させなさい」** という形式で 100% 登場します。

### 1. 試験で狙われる定番障害パターンと対策

#### ① 非対称ルーティング（Asymmetric Routing）による RPF Fail
* **シナリオ:** R1 から R2 へのユニキャストは Path-A（Gi0/1）を通るが、戻りの通信やマルチキャスト送信元からのパケットが Path-B（Gi0/2）から届く。
* **現象:** `show ip mroute` を確認すると、`(10.1.1.100, 239.1.1.1)` の Incoming interface が `Gi0/1` になっているが、実際のパケットは `Gi0/2` から入ってくるため RPF Fail で破棄される。
* **解決策:**
  * **対策 A:** `ip mroute 10.1.1.100 255.255.255.255 GigabitEthernet0/2` を設定し、特定 Source に対する RPF インターフェイスを明示的に上書きする。
  * **対策 B:** MP-BGP (SAFI 2: Multicast) を導入し、マルチキャスト専用の RPF 経路を動的伝搬させる。

#### ② Equal-Cost Multipath (ECMP) 環境下での RPF Neighbor 固定化
* **シナリオ:** Source へのユニキャスト経路に 2 つの等コストパス（10.1.12.2 と 10.1.13.3）が存在する。
* **現象:** デフォルトでは、OSPF / EIGRP の ECMP であっても、EIGRP / OSPF のネクストホップ IP アドレスが最も大きいルータ（10.1.13.3）のみが単一の RPF Neighbor として選出される。他方のパスから届いたパケットは RPF Fail になる。
* **解決策:**
  * `ip pim multipath` (Classic Mode) または `address-family ipv4` 配下でマルチパスを有効化し、両方のパスからのマルチキャストパケットを受容できるようにする。

#### ③ Tunnel / DMVPN 環境における RPF Fail
* **シナリオ:** DMVPN (mGRE) 上で PIM Sparse-Mode を動作させているが、物理インターフェイスからパケットが届いてしまう。
* **現象:** Unicast RIB が Tunnel0 を向いているのに物理ポート Gi0/0 から届いた、あるいはその逆で RPF Fail になる。
* **解決策:** `ip mroute` で Tunnel インターフェイスを明示的に指定するか、`ip pim sparse-mode` を Tunnel および物理インターフェイスの適切な側に構成する。

---

## 🛠 設定方法

### 1. Static Mroute (`ip mroute`) による RPF 上書き設定

```bash
# 特定の送信元 (10.1.100.0/24) に対する RPF ネクストホップを Gi0/2 (10.1.25.2) に固定
R1(config)# ip mroute 10.1.100.0 255.255.255.0 10.1.25.2

# ディスタンス値を変更して Static Mroute をユニキャスト RIB より優先化 (デフォルト AD = 0)
R1(config)# ip mroute 10.1.100.0 255.255.255.0 GigabitEthernet0/2 10.1.25.2 5
```

### 2. ECMP 環境における PIM Multicast Multipath (RPF 拡張)

```bash
# 等コストマルチパス上で複数パスからの RPF チェック通過を許可
R1(config)# ip pim multipath
```

### 3. MBGP (MP-BGP SAFI 2) による RPF 経路の動的伝搬

```bash
router bgp 65000
 address-family ipv4 multicast
  neighbor 10.1.12.2 activate
  network 10.1.100.0 mask 255.255.255.0
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **特定の Source / RP に対する RPF 判定結果の確認** | <code>show ip rpf 10.1.100.100</code> |
| **mroute テーブルと Incoming Interface (RPF Port) の確認** | <code>show ip mroute 239.1.1.1</code> |
| **RPF Check エラー（破棄数）のリアルタイムカウント確認** | <code>show ip mroute count</code> |
| **設定されている Static Mroute 一覧の確認** | <code>show ip mroute static</code> |
| **PIM ネイバーおよび RPF 相手の確認** | <code>show ip pim neighbor</code> |
| **RPF チェック通過 / 破棄イベントのリアルタイムデバッグ** | <code>debug ip mroute 239.1.1.1</code> / <code>debug ip pim</code> |

### `show ip rpf` の出力読解例

```text
R1# show ip rpf 10.1.100.100
RPF information for ? (10.1.100.100)
  RPF interface: GigabitEthernet0/2                     <-- RPF インターフェイス
  RPF neighbor: ? (10.1.25.2)                           <-- RPF ネイバー IP
  RPF route/mask: 10.1.100.0/24                         <-- マッチした経路
  RPF type: mroute (static)                             <-- 決定要因 (static mroute)
  Doing distance-preferred lookups across IP unicast and mroute
  RPF topology: ipv4 multicast base
```

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **マルチキャストトラフィックが対向ルータに届いているが、それ以降に転送されない。** | 到着インターフェイスが RPF インターフェイスと一致しておらず、RPF Fail で破棄されている。 | <code>show ip rpf <Source-IP></code><br><code>show ip mroute count</code> | `ip mroute <Source-IP> <Mask> <Correct-Int>` を投入して RPF を正しく修正する。 |
| **`show ip rpf` の結果が "RPF neighbor: 0.0.0.0 (directly connected)" になる。** | 送信元 IP に対するユニキャスト経路が存在しない（Unicast Reachability 不在）。 | <code>show ip route <Source-IP></code> | IGP / Static ルートを設定し、Source IP へのユニキャスト可達性を確保する。 |
| **等コストマルチパス (ECMP) 環境で片方のリンクからのマルチキャストパケットのみドロップされる。** | デフォルトでは RPF は IP の大きい単一の RPF Neighbor のみを受容するため。 | <code>show ip rpf <Source-IP></code> | グローバルコンフィグで <code>ip pim multipath</code> を有効化する。 |
| **RPF Neighbor が PIM アジャセンシーを確立していない。** | パケットが届くインターフェイス上で `ip pim sparse-mode` が有効化されていない。 | <code>show ip pim interface</code><br><code>show ip pim neighbor</code> | 該当インターフェイスで <code>ip pim sparse-mode</code> を設定する。 |

---

## ⚠ 制限事項

1. **Unicast RIB 非依存動作の限界:**
   * RPF Check はデフォルトで Unicast RIB（ルーティングテーブル）に依存します。ユニキャストのルーティングが破綻している環境では、マルチキャストの RPF Check も自動的に破綻します。
2. **Static Mroute の優先度 (AD):**
   * `ip mroute` はデフォルトで AD=0 (最優先) となるため、ユニキャスト経路を変更してもマルチキャスト RPF パスは追従しません。

---

## 🔄 他技術との関連

* **EIGRP / OSPF / BGP:**
  ユニキャスト IGP/EGP が構築する RIB テーブルが、RPF Check の一次情報源として利用されます。
* **PIM Sparse-Mode:**
  Join / Prune メッセージは、RPF Check によって選出された RPF Neighbor に向かって送出されます。
* **uRPF (Unicast Reverse Path Forwarding):**
  1.6.b の RPF Check と同一の理論を用いて、セキュリティ面でユニキャスト IP スプーフィング攻撃を防止します (4.2.b (iii))。

---

## 🧩 比較表

### RPF Check 判定ソースの比較

| 判定ソース | 優先度 (デフォルト) | 設定方法 | 用途・特徴 |
| :--- | :--- | :--- | :--- |
| **Static Mroute (`ip mroute`)** | 最優先 (AD 0) | <code>ip mroute <Src> <Mask> <NH></code> | 非対称パスの局所的修正・手動制御 |
| **MP-BGP Multicast (SAFI 2)** | 第2位 (AD 20/200) | <code>address-family ipv4 multicast</code> | AS 間・ドメイン間での動的 RPF 経路共有 |
| **Unicast RIB (IGP/Static)** | 第3位 (AD 依拠) | 通常の IGP / IP Route | デフォルトの動作。ユニキャストパスと同一 |

---

## 💡 ベストプラクティス

1. **マルチキャスト導入前の `show ip rpf` 監査:**
   送信元ホスト (Source) および RP アドレスに対する RPF パスを事前検証し、非対称ルーティングが存在しないか確認する。
2. **等コスト冗長網での `ip pim multipath` 適用:**
   ECMP 構成をとるキャンパス/DC 網では、`ip pim multipath` を標準適用してロードバランシングと RPF Fail を防止する。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: 単一送信元に対する Static Mroute による RPF 修正
* **要件:** R1 から Source (10.1.100.50) へのユニキャスト経路は Gi0/1 を向いているが、マルチキャストパケットは Gi0/2 から届く。`ip mroute` を使用して Gi0/2 (10.1.12.2) を RPF インターフェイスとして定義せよ。

**【R1】**
```bash
configure terminal
!
ip mroute 10.1.100.50 255.255.255.255 10.1.12.2
end
```

**【検証方法】**
```bash
R1# show ip rpf 10.1.100.50
# RPF interface: GigabitEthernet0/2, RPF type: mroute (static) を確認
```

---

### Scenario 2: ECMP 環境での PIM Multipath 有効化
* **要件:** R1-R2 間に 2 つの等コストリンク (Gi0/1: 10.1.12.2, Gi0/2: 10.1.22.2) が存在する。両方のリンクからのマルチキャストパケットを RPF Check 通過させよ。

**【R1】**
```bash
configure terminal
!
ip pim multipath
end
```

**【検証方法】**
```bash
R1# show ip rpf 10.1.100.1
# Multipath が有効化されていることを確認
```

---

### Scenario 3: Administrative Distance を指定した Floating Static Mroute
* **要件:** Source (172.16.1.0/24) への RPF チェックにおいて、通常は Unicast RIB を使用し、Unicast RIB がダウンした時のみ Gi0/3 (10.1.35.3) を RPF Neighbor とする Back-up Mroute (AD 150) を構成せよ。

**【R1】**
```bash
configure terminal
!
ip mroute 172.16.1.0 255.255.255.0 10.1.35.3 150
end
```

**【検証方法】**
```bash
R1# show ip mroute static
```

---

### Scenario 4: MP-BGP (SAFI 2) による RPF 専用経路の配信
* **要件:** R1 と R2 間で MP-BGP IPv4 Multicast アドレスファミリーを構成し、192.168.10.0/24 網をマルチキャスト RPF 専用ルートとして送出せよ。

**【R1】**
```bash
router bgp 65001
 neighbor 10.1.12.2 remote-as 65001
 !
 address-family ipv4 multicast
  neighbor 10.1.12.2 activate
  network 192.168.10.0 mask 255.255.255.0
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip rpf 192.168.10.1
# RPF type: BGP multicast を確認
```

---

### Scenario 5: GRE トンネル経由の RPF 修正
* **要件:** R1-R3 間の GRE トンネル (Tunnel0) を介してマルチキャスト RPF チェックを通過させよ。

**【R1】**
```bash
configure terminal
!
interface Tunnel0
 ip address 172.16.13.1 255.255.255.0
 tunnel source GigabitEthernet0/1
 tunnel destination 10.1.23.3
 ip pim sparse-mode
!
ip mroute 10.3.3.0 255.255.255.0 Tunnel0
end
```

**【検証方法】**
```bash
R1# show ip rpf 10.3.3.3
# RPF interface: Tunnel0 を確認
```

---

### Scenario 6: RP (Rendezvous Point) に対する RPF Check 検証
* **要件:** PIM Sparse-Mode における RP (10.2.2.2) への RPF チェックが Gi0/2 を通るように Static Mroute を設定せよ。

**【R1】**
```bash
configure terminal
!
ip mroute 10.2.2.2 255.255.255.255 GigabitEthernet0/2
end
```

**【検証方法】**
```bash
R1# show ip rpf 10.2.2.2
```

---

### Scenario 7: VRF 環境での Static Mroute 構成 (Multi-Tenant)
* **要件:** VRF `TENANT_A` 内の送信元 (10.10.1.0/24) に対する Static Mroute を構成せよ。

**【R1】**
```bash
configure terminal
!
ip mroute vrf TENANT_A 10.10.1.0 255.255.255.0 GigabitEthernet0/1.100 10.10.12.2
end
```

**【検証方法】**
```bash
R1# show ip rpf vrf TENANT_A 10.10.1.50
```

---

### Scenario 8: PIM Dense Mode における RPF ドロップ監査
* **要件:** R1 で発生している RPF ドロップパケットをリアルタイムデバッグにより監査せよ。

**【R1】**
```bash
R1# debug ip mroute detail
R1# debug ip pim 239.1.1.1
```

**【検証方法】**
```bash
# コンソール出力で "RPF failed" または "Drop" ログを確認
```

---

### Scenario 9: RPF ルックアップポリシーの変更 (`distance-preferred` vs `longest-match`)
* **要件:** Static Mroute と Unicast RIB が競合した際、常にディスタンス値（AD）が低い方を最優先して RPF 選定を行うよう動作を固定せよ。

**【R1】**
```bash
configure terminal
!
ip mroute distance-preferred
end
```

**【検証方法】**
```bash
R1# show ip rpf 10.1.100.1
```

---

### Scenario 10: RPF Fail トラブルシューティング演習
* **要件:** Host-A (10.1.1.100) から送出される 239.5.5.5 へのパケットが R1 で破棄される。RPF カウンタを確認し、Static Mroute で復旧させよ。

**【診断・復修手順】**
```bash
# 1. ドロップ状態の確認
R1# show ip mroute count
# 239.5.5.5 の RPF-failed カウンタがインクリメントされていることを確認

# 2. 現在の RPF ネイバー確認
R1# show ip rpf 10.1.1.100
# 想定と異なる Port (Gi0/1) を指していることを確認

# 3. 修正設定の投入
R1(config)# ip mroute 10.1.1.100 255.255.255.255 GigabitEthernet0/2

# 4. 復旧確認
R1# show ip mroute 239.5.5.5
# Forwarding 状態に遷移したことを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】非対称パスによる RPF ドロップ
**問題:**  
R1 において、マルチキャストグループ `239.10.10.10`（送信元 `10.1.50.5`）のレシーバーが Join しているにもかかわらず、動画ストリームが受領できません。`show ip mroute count` を実行すると RPF-failed カウンタが増加していました。ユニキャスト経路を変更することなく、R1 上でこの通信を正常化する最も適切なコンフィグを記述してください。

**解答・解説:**  
* **原因:** 送信元 `10.1.50.5` へのユニキャスト RIB 経路が指すポートと、実際にマルチキャストパケットが流入する物理ポートが異なっている（非対称ルーティング）。
* **修正コンフィグ:**
  ```text
  ip mroute 10.1.50.5 255.255.255.255 <パケットが届く実際の入力インターフェイス/ネクストホップIP>
  ```

---

### 2. 【コンフィグ読解】`ip pim multipath` の動作
**問題:**  
以下のコンフィグが投入されたルータ R1 の動作について正しい説明を選びなさい。
```text
ip pim multipath
```
A. PIM パケットが ECMP リンク上でラウンドロビン方式で送信される。  
B. 送信元 IP へのユニキャスト経路が等コストマルチパス (ECMP) である場合、複数リンクからの同一マルチキャストパケット受容（RPF チェック通過）が許可される。  
C. マルチキャストトラフィックが 2 つの等コストパスへ 50% ずつロードバランシングされて送出される。  
D. PIM Sparse-Mode が PIM Dense-Mode に自動切替される。

**解答・解説:**  
* **正解:** **B**
* **解説:** デフォルトの RPF Check では ECMP リンクが存在しても IP アドレスの大きい単一の RPF Neighbor のみが選ばれますが、`ip pim multipath` を有効化することで、ECMP 構成上の複数の RPF パスからのパケット受容が許可されます。

---

## 🔗 参考リソース

* [Cisco Systems: IP Multicast Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book.html)
* [Cisco Command Reference: ip mroute / show ip rpf](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/command/imc-cr-book.html)
* [Cisco Live: BRKMRT-2101 - Multicast Routing Architecture and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **RPF Check 簡易確認フロー:**
  `パケット受信` ➔ `Src IP の Unicast RIB 検索` ➔ `受信 Port == RIB 出力 Port ?`
  - **YES** ➔ [PASS] OIL (Outgoing Interface List) へ転送
  - **NO** ➔ [FAIL] 即刻破棄 (RPF-failed +1)


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


