---
layout: default
title: 4.4.g-HQoS
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 7
---

# 4.4.g HQoS

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.0 Infrastructure Security and Services` 内の **`4.4.g HQoS (Hierarchical Quality of Service)`** に関する詳細な構造化学習メモ。

---

## 📘 概要

**HQoS (Hierarchical Quality of Service: 階層型 QoS)** とは、単一のインターフェイスに対して複数のポリシー（Policy-Map）を階層構造（ネスト構造）でネスト適用し、帯域制御（Shaping / Policing）とキューイング（LLQ / CBWFQ）やパケット破棄（WRED）を親クラス・子クラス間で独立かつ段階的に制御する QoS 設計アプローチである。

### 主な利用目的と適用場面
1. **WAN サブレート回線 (Sub-rate WAN) における平滑化と優先制御の両立:**
   * アクセス回線の物理クロック速度（例: 1Gbps）と、サービスプロバイダ（SP）との契約帯域（例: 100Mbps）が異なる環境。
   * 親ポリシーで全体帯域を 100Mbps にシェーピング（`shape average`）し、その内部（子ポリシー）で Voice を最優先処理（LLQ）しつつデータ通信を保証（CBWFQ）する。
2. **マルチテナント / サブインターフェイス (802.1Q) / DMVPN / SD-WAN 環境:**
   * 物理インターフェイス全体の帯域、VLAN 単位（Sub-interface）の帯域、特定のトンネル（DMVPN Spokes）ごとの帯域を多階層でシェーピングしながら、それぞれの内部でアプリケーション別の優先度制御を実施する場面。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 親ポリシー (Parent Policy) と子ポリシー (Child Policy) のネスト（階層化）構造による複合制御 |
| **用途** | WAN アクセスサブレート制御、VLAN/Sub-interface ごとの帯域制限、DMVPN Per-Tunnel QoS |
| **メリット** | 親の Shaper バッファ内で子クラスの Priority (LLQ) や CBWFQ を動作させ、SP 側での無分別ドロップを回避 |
| **デメリット** | 設定が複雑化し、CPU/ASIC 処理リソース消費が増加。親クラスでの Priority 指定などの設定制約が存在 |
| **対応機種** | Cisco ISR 4000/8000 シリーズ, Catalyst 8300/8500, Catalyst 9000 シリーズ (C3PL / HQoS 対応) |
| **制限事項** | 親ポリシー直下での `priority` 指定は不可（必ず子ポリシー内で定義）。3階層超のネスト制限 |
| **設計上の注意点** | `shape average` と `shape peak` のバースト挙動の違い、`bandwidth remaining percent` の分配計算 |

---

## 🏗 動作原理

HQoS は、**「全体（またはサブインターフェイス/トンネル）の集約帯域制御」** と **「その帯域内部でのアプリケーション別優先度制御」** を明確に切り離して段階処理する。

```
[ Ingress Packets ]
        ↓
  [ Classification ] (NBAR2 / DSCP / CoS / ACL)
        ↓
[ Parent Policy-Map ] (集約帯域制御: 例 100Mbps Shape Average)
  ├── [ Parent Shaper Token Bucket ]
  │         ↓ (バケット評価: 契約帯域超過時は Parent Shaping Queue へ蓄積)
  └── [ Child Policy-Map ] (クラス別スケジューリング)
        ├── [ Class: Voice ] ──► Priority Queue (LLQ: 厳格優先 ＋ 内蔵ポリサー)
        ├── [ Class: Video ] ──► CBWFQ (Bandwidth Remaining 30%)
        ├── [ Class: Data  ] ──► CBWFQ (Bandwidth Remaining 50% ＋ WRED)
        └── [ Class: Default] ──► Fair Queuing / FIFO (残余帯域)
        ↓
 [ Hardware Tx-Ring ] ──► [ Physical Wire Transmission ]
```

### 核心的ロジック
1. **親シェーパー (Parent Shaper):** 物理速度 (1Gbps) で送信されるパケットを、契約速度 (100Mbps) を超えないようにトークンバケットに従ってシェーピング制御。
2. **子スケジューラ (Child Scheduler):** 親シェーパーが送信を許可したトークン（帯域）の中で、子ポリシーの LLQ (Priority Queue) から優先的にパケットを取り出し、残りの帯域を CBWFQ (`bandwidth` / `bandwidth remaining percent`) に従って配分する。

---

## ⚙ 動作シーケンス

パケットが HQoS 適用インターフェイスを通過する際の下位パイプライン処理順序：

```
1. パケット到着 (Egress Interface)
   ↓
2. Class-Map 照合 (Child Policy 内の Class 条件にマッチング)
   ↓
3. Child Queue 投入
   - Priority クラス: Priority Queue (LLQ) へ投入
   - Normal クラス: それぞれの CBWFQ キューへ投入 (WRED 設定時は閾値判定)
   ↓
4. Parent Policy (Shaper) バケットチェック
   - トークンあり: 送信許可
   - トークンなし: Parent Shaping Queue 内で一時待機 (バッファリング)
   ↓
5. Child Scheduler 取り出し (パケット送信順序決定)
   - Priority Queue から優先取り出し (内蔵ポリサー制限内)
   - 残り帯域から CBWFQ 重み付けに従ってパケットを取り出し
   ↓
6. Hardware Tx-Ring 投入 ──► 物理回線へ送出
```


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において HQoS は、WAN サブレート構成、DMVPN ネットワーク、および 802.1Q サブインターフェイス環境で頻出する高難易度トピックである。

### Blueprint で重要なポイント
* **親ポリシーと子ポリシーの制限関係:**
  * 親ポリシー直下で `priority` コマンドを設定することは構造上禁止されている（`Configuration failed! Priority class not allowed in parent policy` エラーが発生）。`priority` は必ず子ポリシー内で定義し、親ポリシーには `shape average` や `shape peak` を指定してネストする。
* **`bandwidth` vs `bandwidth remaining percent`:**
  * HQoS の子ポリシーにおいて、絶対値（`bandwidth <kbps>`）を使うと親シェーパーの帯域変更時にミスマッチが発生しやすい。親シェーパーの帯域変動に追従させるため、子ポリシーでは **`bandwidth remaining percent`** を使用するのが CCIE ラボ試験のベストプラクティス。
* **DMVPN / NHRP Group 統合 Per-Tunnel HQoS:**
  * DMVPN Hub / Spoke ルータにおいて、Spoke ごとの契約帯域（例: Spoke-A=10Mbps, Spoke-B=20Mbps）に応じた HQoS ポリシーを NHRP グループ (`ip nhrp map group`) にアタッチして動的適用する構成。

### よくある設定ミス ＆ 落とし穴
1. **親ポリシーへの `priority` 直接記述:**
   ```bash
   ! ❌ 間違った構成 (エラー発生)
   policy-map PARENT
    class class-default
     priority 512              ! ← エラー! 親クラスで priority は不可
     shape average 10000000
   ```
   ```bash
   ! ⭕ 正しい構造
   policy-map CHILD
    class CM_VOICE
     priority 512
   policy-map PARENT
    class class-default
     shape average 10000000
     service-policy CHILD     ! ← 子ポリシーとしてネスト
   ```
2. **`bandwidth` の合計値が親シェーパー帯域を超過:**
   * 子クラスの `bandwidth` 絶対値の合計が親ポリシーの `shape average` 帯域を超えると、`service-policy` 適用時にコミットエラーが発生する。

---

## 🛠 設定方法

### 基本的な HQoS (2-Level HQoS) 設定手順
1. **子ポリシー (Child Policy-Map) の作成:**
   * アプリケーション分類 (Class-Map) に対する Priority Queue (LLQ) や CBWFQ (`bandwidth remaining percent`)、WRED (`random-detect`) を定義。
2. **親ポリシー (Parent Policy-Map) の作成:**
   * `class class-default` 内で親シェーパー (`shape average <bps>`) を定義し、内部で `service-policy <CHILD_NAME>` をネスト指定。
3. **物理 / 論理インターフェイスへのバインド:**
   * 送信インターフェイス（物理 I/F、Sub-interface、または Tunnel I/F）に `service-policy output <PARENT_NAME>` を適用。

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| HQoS 全体・階層別統計表示 | <code>show policy-map interface &lt;Interface&gt;</code> |
| 親シェーパーのバッファ・ドロップ表示 | <code>show policy-map interface &lt;Interface&gt; output class class-default</code> |
| 子クラスの LLQ / CBWFQ ドロップ表示 | <code>show policy-map interface &lt;Interface&gt; output &lt;PARENT&gt; &lt;CHILD_CLASS&gt;</code> |
| MQC ポリシー構造の事前確認 | <code>show policy-map &lt;Policy-Name&gt;</code> |
| DMVPN Per-Tunnel HQoS バインド確認 | <code>show ip nhrp group</code> / <code>show dmvpn</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| `service-policy` 適用時に CLI エラー発生 | 親ポリシー直下に `priority` が設定されている | `show policy-map` | `priority` コマンドを子ポリシー内に移動してネスト |
| WAN 回線上でパケットが不公平にドロップ | 親ポリシーでのシェーピング帯域が物理速度のまま | `show policy-map interface` | `shape average` で契約帯域（例: 100Mbps）を正確に指定 |
| 子クラスの Priority Queue でドロップ増加 | 親シェーパー帯域に対して LLQ 割り当てが超過 | `show policy-map interface` | 子クラスの `priority` 値の見直し、または入力帯域制限 |
| 子クラスの CBWFQ で設定コミット失敗 | `bandwidth` 絶対値の合計が親シェーパー帯域を超過 | `show policy-map` | `bandwidth remaining percent` による相対指定へ変更 |

---

## ⚠ 制限事項

1. **ネスト階層数の制限:**
   * Cisco IOS XE では、HQoS のネスト階層は最大 3 階層（3-Level HQoS: Grandparent ➔ Parent ➔ Child）までに制限される。
2. **親ポリシーにおける制約:**
   * 親ポリシーのクラスには `priority` コマンドを適用できない。また、親ポリシーの `class-default` 以外のカスタムクラスでのシェーピングにはハードウェアプラットフォーム固有の制限が存在する場合がある。

---

## 🔄 他技術との関連

* **DMVPN (Dynamic Multipoint VPN):** NHRP Group と連携し、Spoke ルータごとに異なる物理帯域に応じた Per-Tunnel HQoS を Hub ルータ側で動的アタッチ。
* **802.1Q Sub-interface:** 各 VLAN / サブインターフェイスに対して独立した親シェーパーを配置し、VLAN 間の帯域圧迫を抑止しつつ内部で HQoS 優先制御。
* **Overhead Accounting (`Account User-Defined`):** L2/L3 ヘッダーや IPsec カプセル化による追加バイト数を親シェーパーに算入し、実際の物理回線専有率と精密に一致させる。

---

## 🧩 比較表

| 比較項目 | Flat QoS (単一ポリシー) | Hierarchical QoS (HQoS) |
| :--- | :--- | :--- |
| **適用構造** | 1つの Policy-Map を直接アタッチ | 親 Policy 内に 子 Policy をネスト構造でバインド |
| **帯域制御** | クラスごとの Policing / Queueing のみ | 回線全体の Shaping ＋ 内部での Queueing/Policing |
| **サブレート対応** | 不可（回線速度超過時に SP 側でドロップ） | **対応可能**（親 Shaper で平滑化して SP ドロップを回避） |
| **拡張性** | 低い（VLAN や Tunnel ごとの集約制御不可） | **極めて高い**（物理 I/F ➔ Sub-interface ➔ App クラス制御） |

---

## 💡 ベストプラクティス

1. **子ポリシーでの帯域指定は `bandwidth remaining percent` を使用:**
   * 親シェーパーの帯域値を切り替えた場合でも、子クラスの帯域比率が自動修正され保守性が劇的に向上する。
2. **親シェーパーへの Overhead Accounting 付与:**
   * Ethernet ヘッダー (18-22 Bytes) や IPsec ヘッダーを算入するため `shape average <bps> Account User-Defined <Bytes>` を付加し、SP 側ポリサーでのミリ秒ドロップを回避する。
3. **LLQ 内蔵ポリサーの上限値意識:**
   * Priority クラスには必ず適切な帯域制限（例: `priority 512`）を設定し、音声トラフィック急増時にデータクラスが飢餓状態（Starvation）に陥るのを防ぐ。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: WAN サブレート回線向け基本 HQoS (Parent Shape Average ＋ Child LLQ/CBWFQ)

* **問題:** 1Gbps 物理インターフェイス GigabitEthernet0/0/1 上で、SP との 100Mbps 契約回線に適合させる HQoS を構成せよ。
* **要件:**
  * 親ポリシーで 100Mbps に平滑化（Shaping）すること。
  * 子ポリシー内で Voice (DSCP EF) を 10Mbps LLQ で最優先処理すること。
  * Video (DSCP AF41) に残余帯域の 40%、Data (DSCP AF31) に残余帯域の 40% を配分すること。
* **設定例:**
```bash
! 1. Class-Map の定義
class-map match-any CM_VOICE
 match dscp ef
class-map match-any CM_VIDEO
 match dscp af41
class-map match-any CM_DATA
 match dscp af31

! 2. 子ポリシー (Child Policy-Map) の定義
policy-map PM_CHILD_HQOS
 class CM_VOICE
  priority 10000
 class CM_VIDEO
  bandwidth remaining percent 40
 class CM_DATA
  bandwidth remaining percent 40
 class class-default
  fair-queue

! 3. 親ポリシー (Parent Policy-Map) の定義 (契約 100Mbps)
policy-map PM_PARENT_WAN
 class class-default
  shape average 100000000
  service-policy PM_CHILD_HQOS

! 4. インターフェイスへの適用
interface GigabitEthernet0/0/1
 service-policy output PM_PARENT_WAN
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` を実行し、Parent Class の Shaper 統計および Child Class の Priority/CBWFQ パケット数が正しくカウントされていることを確認。

---

### ラボ 2: Multi-Level LLQ ＋ CBWFQ を含む 2-Level HQoS 構成

* **問題:** 音声 (Level 1) とインタラクティブビデオ (Level 2) を個別の優先キューで処理する Multi-Level LLQ 構造の HQoS を構築せよ。
* **要件:**
  * 親ポリシーで 50Mbps にシェーピング。
  * 音声 (DSCP EF) に `priority level 1 5000` (5Mbps)、ビデオ (DSCP CS4) に `priority level 2 15000` (15Mbps) を割り当てること。
* **設定例:**
```bash
class-map match-any CM_VOICE_L1
 match dscp ef
class-map match-any CM_VIDEO_L2
 match dscp cs4
class-map match-any CM_CRITICAL
 match dscp af31

policy-map PM_CHILD_MULTILEVEL
 class CM_VOICE_L1
  priority level 1 5000
 class CM_VIDEO_L2
  priority level 2 15000
 class CM_CRITICAL
  bandwidth remaining percent 50
 class class-default
  fair-queue

policy-map PM_PARENT_50M
 class class-default
  shape average 50000000
  service-policy PM_CHILD_MULTILEVEL

interface GigabitEthernet0/0/2
 service-policy output PM_PARENT_50M
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/2` を実行し、`Priority Level 1` および `Priority Level 2` が独立した統計で追跡されていることを確認。

---

### ラボ 3: 802.1Q サブインターフェイス単位の HQoS 構成

* **問題:** 単一の物理ポート Gi0/0/3 上の 2 つの VLAN サブインターフェイス (VLAN 10: 契約 20Mbps, VLAN 20: 契約 30Mbps) に対して個別に HQoS を構成せよ。
* **要件:**
  * Gi0/0/3.10 (VLAN 10) に 20Mbps シェーピング ＋ 音声 2Mbps Priority。
  * Gi0/0/3.20 (VLAN 20) に 30Mbps シェーピング ＋ 音声 3Mbps Priority。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_CHILD_VLAN10
 class CM_VOICE
  priority 2000
 class class-default
  bandwidth remaining percent 100

policy-map PM_PARENT_VLAN10
 class class-default
  shape average 20000000
  service-policy PM_CHILD_VLAN10

policy-map PM_CHILD_VLAN20
 class CM_VOICE
  priority 3000
 class class-default
  bandwidth remaining percent 100

policy-map PM_PARENT_VLAN20
 class class-default
  shape average 30000000
  service-policy PM_CHILD_VLAN20

interface GigabitEthernet0/0/3.10
 encapsulation dot1Q 10
 service-policy output PM_PARENT_VLAN10

interface GigabitEthernet0/0/3.10
 encapsulation dot1Q 20
 service-policy output PM_PARENT_VLAN20
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/3.10` および `.20` を個別に確認し、それぞれの親シェーパーが正しく独立動作していることを検証。

---

### ラボ 4: DMVPN Phase 3 Per-Tunnel HQoS (NHRP Group バインド)

* **問題:** DMVPN Hub ルータにおいて、接続してくる Spoke の契約回線速度（Group SMALL=5Mbps, Group LARGE=20Mbps）に応じた Per-Tunnel HQoS を動的適用せよ。
* **要件:**
  * NHRP グループ `SMALL` 用に 5Mbps Shaper、`LARGE` 用に 20Mbps Shaper を定義。
  * それぞれの子ポリシーで Voice (DSCP EF) を優先制御すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_CHILD_DMVPN
 class CM_VOICE
  priority 1000
 class class-default
  fair-queue

policy-map PM_SPOKE_SMALL
 class class-default
  shape average 5000000
  service-policy PM_CHILD_DMVPN

policy-map PM_SPOKE_LARGE
 class class-default
  shape average 20000000
  service-policy PM_CHILD_DMVPN

interface Tunnel0
 ip nhrp map group SMALL service-policy output PM_SPOKE_SMALL
 ip nhrp map group LARGE service-policy output PM_SPOKE_LARGE
```
* **検証方法:**
  * `show ip nhrp group` および `show dmvpn` を実行し、Spoke ごとに該当する Per-Tunnel HQoS ポリシーが正しく紐付いていることを確認。

---

### ラボ 5: Parent Shape Peak (バースト許容型) ＋ Child Priority/CBWFQ 構成

* **問題:** 回線混雑のない時間帯に契約帯域以上のバースト出力を一時許容する `shape peak` を使用した HQoS を構築せよ。
* **要件:**
  * 親ポリシーで `shape peak 10000000` (10Mbps Peak) を設定。
  * 子ポリシーで Voice 1Mbps LLQ ＋ Data 残有帯域 80% を確保。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef
class-map match-any CM_DATA
 match dscp af21

policy-map PM_CHILD_PEAK
 class CM_VOICE
  priority 1000
 class CM_DATA
  bandwidth remaining percent 80
 class class-default
  fair-queue

policy-map PM_PARENT_PEAK
 class class-default
  shape peak 10000000
  service-policy PM_CHILD_PEAK

interface GigabitEthernet0/0/4
 service-policy output PM_PARENT_PEAK
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/4` を実行し、Target Shaping Rate が CIR ＋ Be に基づいて計算・出力されていることを確認。

---

### ラボ 6: Overhead Accounting (`Account User-Defined`) 付き HQoS 構成

* **問題:** SP 側での L2/L3 カプセル化（24 バイト）によるミリ秒ドロップを回避する Overhead Accounting 付き HQoS を設定せよ。
* **要件:**
  * 親シェーパー 10Mbps に対して 24 バイトのオーバーヘッドオフセットを加算すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_CHILD_ACCT
 class CM_VOICE
  priority 1000
 class class-default
  fair-queue

policy-map PM_PARENT_ACCT
 class class-default
  shape average 10000000 Account User-Defined 24
  service-policy PM_CHILD_ACCT

interface GigabitEthernet0/0/5
 service-policy output PM_PARENT_ACCT
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/5` を実行し、`Overhead 24 bytes` がシェーピング計算に正しく反映されていることを確認。

---

### ラボ 7: NBAR2 アプリケーション識別連動 HQoS 構成

* **問題:** NBAR2 で識別した WebEx トラフィックを子ポリシーで最優先処理する 30Mbps HQoS を構成せよ。
* **要件:**
  * NBAR2 で `webex-media` を識別。
  * 親 30Mbps シェーピングの内部で WebEx 通信に 8Mbps を確保すること。
* **設定例:**
```bash
class-map match-all CM_NBAR_WEBEX
 match protocol webex-media

policy-map PM_CHILD_NBAR
 class CM_NBAR_WEBEX
  priority 8000
 class class-default
  fair-queue

policy-map PM_PARENT_30M
 class class-default
  shape average 30000000
  service-policy PM_CHILD_NBAR

interface GigabitEthernet0/0/6
 ip nbar protocol-discovery
 service-policy output PM_PARENT_30M
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/6` および `show ip nbar protocol-discovery` を実行し、WebEx トラフィックが正しく分類・優先制御されているのを確認。

---

### ラボ 8: Child Policy 内への WRED / ECN 統合型 HQoS 構成

* **問題:** HQoS の子ポリシーのデータクラスに対して、パケット破棄を回避する WRED / ECN 破棄制御を統合せよ。
* **要件:**
  * 親 100Mbps シェーピング。
  * Data クラス (AF21) に対し WRED ＋ ECN を有効化すること。
* **設定例:**
```bash
class-map match-any CM_DATA_AF2
 match dscp af21 af22 af23

policy-map PM_CHILD_WRED_ECN
 class CM_DATA_AF2
  bandwidth remaining percent 70
  random-detect dscp-prec-based
  random-detect ecn
 class class-default
  fair-queue

policy-map PM_PARENT_100M
 class class-default
  shape average 100000000
  service-policy PM_CHILD_WRED_ECN

interface GigabitEthernet0/0/7
 service-policy output PM_PARENT_100M
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/7` を実行し、WRED / ECN マーク数が正しくカウントアップされることを確認。

---

### ラボ 9: 3-Level HQoS (Grandparent / Parent / Child) 構成

* **問題:** 物理ポート (1Gbps) ➔ サブインターフェイス集約 (100Mbps) ➔ クラス別優先制御 を行う 3 階層 HQoS を構成せよ。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

! 階層 1: 子ポリシー (Class Queueing)
policy-map PM_LEVEL1_CHILD
 class CM_VOICE
  priority 2000
 class class-default
  fair-queue

! 階層 2: 親ポリシー (Sub-interface Shaping: 10Mbps)
policy-map PM_LEVEL2_PARENT
 class class-default
  shape average 10000000
  service-policy PM_LEVEL1_CHILD

! 階層 3: 祖父ポリシー (Physical Port Shaping: 100Mbps)
policy-map PM_LEVEL3_GRANDPARENT
 class class-default
  shape average 100000000
  service-policy PM_LEVEL2_PARENT

interface GigabitEthernet0/0/8
 service-policy output PM_LEVEL3_GRANDPARENT
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/8` を確認し、3 階層のネスト構造が正しくレンダリングされていることを検証。

---

### ラボ 10: HQoS ＋ CoPP (Control Plane Policing) 併用環境での WAN 出口優先制御

* **問題:** HQoS をアタッチした WAN 出口において、BGP / OSPF 制御パケットを最優先保護する HQoS を構成せよ。
* **設定例:**
```bash
class-map match-any CM_CONTROL_PLANE
 match protocol bgp
 match protocol ospf
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_CHILD_WAN_SEC
 class CM_CONTROL_PLANE
  priority 2000
 class CM_VOICE
  priority 5000
 class class-default
  fair-queue

policy-map PM_PARENT_WAN_SEC
 class class-default
  shape average 50000000
  service-policy PM_CHILD_WAN_SEC

interface GigabitEthernet0/0/9
 service-policy output PM_PARENT_WAN_SEC
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/9` で BGP/OSPF パケットが Priority Queue で処理されドロップ 0 であることを確認。


## ❓ 想定試験問題

### 問 1 (構文トラブルシューティング)
**シナリオ:** エンジニアがサブレート WAN 用に以下の Policy-Map を作成し、インターフェイス Gi0/0/1 の `output` に適用しようとしたところ CLI でエラーが発生した。
```bash
policy-map PM_WAN_HQOS
 class CM_VOICE
  priority 512
 class class-default
  shape average 10000000
```
**設問:** この設定でエラーが発生した技術的理由と、修正すべきコンフィグ手順を述べよ。

* **解答:**
  * **技術的理由:** MQC アーキテクチャ上、同一の Policy-Map 内で `shape` (または `class-default` 以外のシェーピング) と `priority` コマンドを並列定義すること、あるいは親ポリシーのクラスに `priority` を直接配置することは禁止されているため。
  * **修正コンフィグ:**
```bash
policy-map PM_CHILD
 class CM_VOICE
  priority 512

policy-map PM_WAN_HQOS
 class class-default
  shape average 10000000
  service-policy PM_CHILD
```

---

### 問 2 (Design / 保守性)
**シナリオ:** WAN 回線の帯域変更（10Mbps ➔ 20Mbps）が頻繁に行われる拠点ルータにおいて、子ポリシーの各データクラスの帯域指定方法について設計を検討している。
**設問:** 保守性を最大化し、親シェーパーの帯域変更時に子ポリシーの修正を一切不要にするためのパラメータ設定手法とその理由を答えよ。

* **解答:**
  * **設定手法:** 子クラスの帯域指定に絶対値（`bandwidth <kbps>`）ではなく **`bandwidth remaining percent`** を使用する。
  * **理由:** `bandwidth remaining percent` は、Priority クラス等で消費された後の残有帯域に対する「相対比率 (%)」で動的分配計算を行うため、親ポリシーの `shape average` 値を変更しても、子クラスの分配比率が自動追従し、設定不整合によるコミットエラーや手動再計算を回避できるため。

---

### 問 3 (コンフィグ読解・計算)
**シナリオ:** 以下の HQoS コンフィグが適用されたルータに 20Mbps のデータトラフィックが流入している。
```bash
policy-map PM_CHILD
 class CM_VOICE
  priority 2000
 class CM_DATA
  bandwidth remaining percent 50

policy-map PM_PARENT
 class class-default
  shape average 10000000
  service-policy PM_CHILD
```
**設問:** Voice 通信が 1Mbps 発生している状況において、`CM_DATA` クラスが使用可能な最大帯域幅 (kbps) を算出せよ。

* **解答:**
  * **計算手順:**
    1. 親シェーパー帯域: 10,000 kbps (10Mbps)
    2. LLQ (Voice) 消費帯域: 1,000 kbps (1Mbps)
    3. 残余帯域 (Remaining Bandwidth): 10,000 - 1,000 = 9,000 kbps
    4. `CM_DATA` 割り当て (50%): 9,000 * 0.50 = **4,500 kbps**

---

### 問 4 (トラブルシューティング / DMVPN)
**シナリオ:** DMVPN Hub ルータにおいて、特定 Spoke 向けの HQoS ポリシーが適用されず、Spoke 側の 5Mbps 回線上で動画ストリーミング時に音声ドロップが発生している。Hub の Tunnel 0 設定を確認したところ以下となっていた。
```bash
interface Tunnel0
 ip nhrp map group SPOKE_5M service-policy output PM_SPOKE_5M
```
**設问:** HQoS ポリシーが適用されない直接的原因と、Spoke ルータ側で実行・確認すべき設定を答えよ。

* **解答:**
  * **原因:** 対向の DMVPN Spoke ルータ側で NHRP グループ名 `SPOKE_5M` のバインド設定（`ip nhrp group SPOKE_5M`）が欠落しているため、Hub ルータ側で Spoke の IP アドレスと該当 HQoS ポリシーのマッピングに失敗している。
  * **対処コマンド (Spoke ルータ側):**
```bash
interface Tunnel0
 ip nhrp group SPOKE_5M
```

---

### 問 5 (実装 / Overhead Accounting)
**シナリオ:** SP 網との 10Mbps 契約回線において、小さなパケット（Voice 等）が多発した際に SP 側のバッファでミリ秒ドロップが発生している。L2/L3 カプセル化による 24 バイトのオーバーヘッドを算入する HQoS コンフィグを構築せよ。

* **解答:**
```bash
policy-map PM_CHILD
 class CM_VOICE
  priority 1000
 class class-default
  fair-queue

policy-map PM_PARENT_ACCT
 class class-default
  shape average 10000000 Account User-Defined 24
  service-policy PM_CHILD

interface GigabitEthernet0/0/1
 service-policy output PM_PARENT_ACCT
```

---

## 🔗 参考リソース

Cisco 公式ドキュメントおよび関連技術資料：

* Cisco IOS XE 17.x Quality of Service Solutions Configuration Guide
* Cisco QoS Policy-Map Design Principles and HQoS Guidelines
* Cisco Live BRKRST-2515: Hierarchical QoS Design and Implementation
* Cisco Enterprise QoS Solution Reference Network Design (SRND)
* Cisco Technical Notes: Hierarchical Queueing Framework (HQF)

---

## 📝 補足（Notes）

### 1. HQoS における階層別アクションの整理
* **親クラス (Parent Class):** トラフィック全体の集約制御を実施。主に `shape average` / `shape peak` を使用。
* **子クラス (Child Class):** クラスごとの細分化制御を実施。`priority` (LLQ)、`bandwidth` / `bandwidth remaining percent` (CBWFQ)、`random-detect` (WRED) を使用。

### 2. トラブルシューティング時のチェックリスト
* `show policy-map interface` を実行した際、Parent Class の `shaper` セクションと Child Class の `queue` セクションが正しく階層表示（インデント表示）されているか？
* 子クラスで `priority` パケットがドロップしていないか？（ドロップしている場合、優先帯域制限値不足か親シェーパー帯域の不整合を疑う）。



## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
*   [**BRKCRT-1385: The CCIE in an SDN World - QoS Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)

### Configuration ガイド
*   [**Cisco IOS XE 17.x QoS: Configuring Hierarchical Modular QoS (HQoS)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_hrhqf/configuration/xe-16/qos-hrhqf-xe-16-book.html)
*   [**Quality of Service Configuration Guide, Catalyst 9300**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/qos/b_179_qos_9300_cg.html)

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)
*   [**Low Latency Queuing with Priority Percentage Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/15-mt/qos-conmgt-15-mt-book/qos-conmgt-llq-pps.html)

---

## 📝 補足
- この学習メモは、HQoS が単なるネストしたコマンドではなく、**「物理速度と論理速度のギャップを埋めるための不可欠な階層設計」**であることを示しています。CCIE ラボ試験では、親ポリシーでのシェーピングを忘れると、子ポリシーの帯域計算が破綻するため、常にセットで考える習慣をつけてください。


