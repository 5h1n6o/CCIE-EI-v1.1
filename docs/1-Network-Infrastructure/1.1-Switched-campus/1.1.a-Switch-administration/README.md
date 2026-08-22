---
layout: default
title: 1.1.a-Switch-administration
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.1.a (i) Managing MAC address table, (ii) Errdisable recovery, & (iii) L2 MTU

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 ラボ試験におけるスイッチングインフラの安定化とトラブルシューティングの基礎となる、**MACアドレステーブル管理**、**Errdisable自動復旧**、および**レイヤ2 MTU（ジャンボフレーム）設計**について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ）の実装基準に準拠して詳細に整理します。

---

## 📘 概要

### 1. MACアドレステーブル管理 (Managing MAC address table)
レイヤ2スイッチは、受信したイーサネットフレームの送信元MACアドレスを学習し、ポートおよびVLAN情報と紐づけてCAM（Content Addressable Memory）テーブルに保存します。CCIE試験では、この学習プロセスを制御して未知のユニキャストフラッディングを抑制したり、悪意あるMACフラッディング攻撃やループによるMACフラッピングからコントロールプレーンを保護する技術が問われます。

### 2. Errdisable自動復旧 (Errdisable recovery)
Cisco IOS-XEデバイスは、ポートセキュリティ違反、STP BPDUガード違反、ループ、EtherChannel不整合などの異常を検知すると、ポートを保護するために自動的に `err-disabled` 状態（論理・物理的なシャットダウン）に移行させます。このエラー状態から管理者による手動介入（`shutdown` / `no shutdown`）なしで安全かつ自動的に復旧させるのが **Errdisable Recovery** 機能です。

### 3. レイヤ2 MTU (L2 MTU)
MTU（Maximum Transmission Unit）は、ネットワークメディアを通過できるイーサネットフレームの最大ペイロードサイズ（レイヤ3パケット。L2ヘッダーとFCSを除く通常1500バイト）を定義します。
近年、SD-Access（VXLANカプセル化）やMPLSなどのカプセル化技術を多用するエンタープライズインフラにおいて、余分なオーバーヘッドを吸収するための**L2ジャンボフレーム（Jumbo Frame）**およびMTU一貫性設計は極めて重要なトピックとなっています。

---

## 🔑 要点

各対象技術の機能要件、メリット、制限事項を整理します。

| 技術要素 | 項目 | 詳細内容 |
| :--- | :--- | :--- |
| **MACアドレステーブル管理** | **特徴** | 送信元MACを動的にCAMに学習。エージングタイム（デフォルト300秒）により古いエントリを破棄。 |
| | **用途** | MAC移動通知（MAC Move）、未知のユニキャストフラッディング抑止（Unicast Blocking）、静的MAC登録。 |
| | **メリット** | スイッチングのフォワーディング効率向上、不要なフラッディングトラフィックの削減、L2型攻撃の緩和。 |
| | **制限事項** | CAMメモリ制限。上限を超えるとフラッディング（Unknown Unicast Flooding）が発生し、ハブと同様の挙動となる。 |
| | **設計上の注意** | SD-Access/VXLAN環境下では、ファブリックエッジでのクラシックMAC学習とコントロールプレーン（LISP）によるマッピングが連動する。 |
| **Errdisable自動復旧** | **特徴** | 特定のエラー原因でポートが停止した際、自動復旧タイマー（デフォルト300秒）を起動してポートを再稼働させる。 |
| | **用途** | リモート拠点の無人運用、STP BPDU GuardやPort-Securityによる一時的なエラーからの自己修復。 |
| | **メリット** | 軽微なトラブル時におけるシステム管理者の手動復旧工数を削減し、可用性を維持。 |
| | **制限事項** | 根本原因（例：物理ループ、不正なスイッチの継続接続）が解決しない限り、Errdisableと復旧（フラッピング）を繰り返す。 |
| | **設計上の注意** | 復旧を繰り返すとSTPの再計算が走りネットワークが不安定化するため、自動復旧間隔（インターバル）および該当ポートのSTP設計を最適化する。 |
| **L2 MTU** | **特徴** | レイヤ2イーサネットフレームが物理ポートを通過する際の最大パケットサイズを制御。 |
| | **用途** | VXLAN, OTV, MPLS, IPsecなどのカプセル化オーバーヘッドによるパケット断片化（フラグメンテーション）および破棄の防止。 |
| | **メリット** | フラグメント処理によるCPU負荷を排除し、カプセル化環境下での高効率なパケット転送（スループット向上）を実現。 |
| | **制限事項** | ハードウェア（ASIC）およびラインカードの仕様に依存。最大値は通常9216バイト。 |
| | **設計上の注意** | **IOS-XE 17.x（Catalyst 9000シリーズ）以降、グローバルの `system mtu` 設定だけでなく、インターフェイス単位（ポート個別）での `mtu` 設定が可能に。**リロードは不要。 |

---

## 🏗 動作原理

### 1. MACアドレスの動的学習と未知のユニキャストフラッディング
受信したイーサネットフレームの宛先MACアドレスがCAMテーブルに存在しない場合、スイッチは該当フレームを**同一VLANのすべてのポート（受信ポートを除く）にフラッディング（Unknown Unicast Flooding）**します。

```
[Host A (00aa.bbcc.0001)] ➔ [Switch (CAM Table empty)] ➔ [Flood to Port 2, 3, 4]
                                  │
                       [Learns Host A on Port 1]
                                  │
                                  ▼
[CAM Table updated]
VLAN   MAC Address      Type      Ports
10     00aa.bbcc.0001   DYNAMIC   Gi1/0/1
```

### 2. Errdisable の状態遷移と Recovery タイマーのシグナリング
Errdisable Recoveryが有効化されている場合、ポート閉塞と同時に内部のタイマー（Recovery Timer）がカウントダウンを開始します。

```
[正常（Up/Up）]
      │ ➔（エラー発生：例 BPDU Guard 違反）
      ▼
[Errdisable 状態に遷移（物理的/論理的 Down）]
      │ ➔（Recovery タイマーがカウントダウンを開始：デフォルト 300秒）
      ▼
[タイマー満了]
      │ ➔（スイッチが自動的に内部で 'shutdown' -> 'no shutdown' をエミュレート）
      ▼
[ポート再試行（Attempting to UP）]
      │
      ├─► (根本原因が解決済み) ➔ 正常稼働（Up/Up）へ復帰
      │
      └─► (根本原因が未解決) ➔ 再度エラー検知 ➔ 直ちに Errdisable へ逆戻り
```

### 3. レイヤ2 MTU ミスマッチによる OSPF ネイバー確立失敗とパケットドロップ
レイヤ2のポートMTUが対向間で不一致である場合、MTUが小さい側のスイッチに入力された超過フレームはASICレベルで**サイレントドロップ（統計カウンタの Giants 等で記録され、即時破棄）**されます。

```
[ Switch A: MTU 9000 ] ---------------------- ( L2 Link ) ---------------------- [ Switch B: MTU 1500 ]
  OSPF DBD (Length: 4000) ────► [ Frame Sent ]
                                                      │
                                                      ▼ [受信側にて MTU 1500 を超過]
                                                [ Silent Drop! ] ➔ Switch B にはパケットが届かない
                                                (結果: OSPF状態が EXSTART / EXCHANGE でハング)
```

---

## ⚙ 動作シーケンス

### MACアドレス・フラッピング検知時の閉塞・Errdisable復旧シーケンス

```
[スイッチドネットワーク内で一時的なL2ループが発生]
      │
      ▼
[同一MACアドレスが異なる物理ポート間で高速に移動（MAC Flapping）]
      │
      ├─► スイッチが Syslog メッセージを出力：
      │   「%SW_MATM-4-MACFLAP_NOTIF: Host 0000.aaaa.bbbb in vlan 10 is flapping between port Gi1/0/1 and Gi1/0/2」
      │
      ▼
[MACフラップ検知によるポート保護（Errdisable設定時）]
      │
      ├─► 対象のポート（または送信元ポート）を直ちに「err-disabled」に遷移。
      ├─► ループトラフィックの連鎖をハードウェアレベルで即座に遮断。
      │
      ▼
[Errdisable Recoveryの自動トリガー]
      │
      ├─► ユーザーが指定した interval (例: 30秒) が経過。
      ├─► スイッチがポートを自動開放。
      │
      ▼
[復旧後の判定]
      │
      ├─► (ループが解消していない場合) ➔ 再びフラッピングを検知し、数秒以内に再閉塞。
      └─► (ループが解消している場合) ➔ 正常稼働を継続。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EIラボ試験の「1.1 Switched campus」セクションにおいて、本トピックはネットワークの可用性と完全性をテストするための「必須の隠し要件」や「トラブルシューティングのチケット」として組み込まれます。

### 1. MACアドレステーブルの制御とセキュリティ
* **静的MACエントリのピン留め:** 
  特定のサーバーやホストのMACアドレスを特定のポートに「静的（Static）」に紐付けるとともに、MAC移動（MAC Move）攻撃によるなりすましを防ぐ構成が問われます。
* **未知のユニキャストフラッディングの遮断:**
  「セキュリティ監査ポリシーに基づき、ポート Gi1/0/5 に接続されたクライアントにおいて、宛先不明のユニキャストパケットが届いた場合に、他のポートへのフラッディングを一切禁止せよ」といった条件が提示されます。
  * **対策:** 対象インターフェイスで `switchport block unicast` を適切に設定します。

### 2. Errdisable Recovery の厳密なパラメータ設計
* **原因別の自動復旧有効化:** 
  「BPDUガード、ポートセキュリティ違反、ループバック検知によって発生したポート閉塞のみを自動的に検旧させ、その他の原因による閉塞は管理者の手動復旧とするよう構成せよ」といった、**復旧原因の選択的バインド**が求められます。
  * **対策:** `errdisable recovery cause bpduguard`、`errdisable recovery cause psecurity-violation`、`errdisable recovery cause loopback` などを個別にバインドし、`all` を使用しないよう注意します。
* **復旧間隔（Interval）の最短値変更:** 
  「Errdisableからの回復を最優先とするため、IOSのデフォルト設定よりも極力短い時間（または指定された秒数、例えば30秒）で自動復旧を試みるように構成せよ」と指定されるケースがあります。
  * **対策:** `errdisable recovery interval 30`（設定可能な最小値は30秒）を確実に設定します。デフォルトの300秒のままでは試験官による自動採点スクリプトの実行タイミングまでに復旧せず、失点に繋がります。

### 3. L2 MTU とカプセル化（VXLAN/SD-Access）の相関
* **Catalyst 9000での MTU 設定パラダイムシフト:**
  レガシーなCiscoスイッチ（Catalyst 3750/3850等）では、Jumboフレームをサポートするためにグローバルで `system mtu jumbo 9000` を設定して**再起動（reload）**を行う必要がありました。
  しかし、**Catalyst 9000シリーズ（IOS-XE 17.x）では、ポート単位で `mtu 9000` コマンドを投入するだけで即時反映され、再起動は一切不要です。**
  * **試験での罠:** グローバルで `system mtu 9100` などのコマンドが通る場合もありますが、インターフェイス個別で `mtu <値>` を設定することが指示されるケースが多いため、両方の設定アプローチと機器の挙動の違いを正確に把握しておく必要があります。
* **SD-Accessファブリックにおけるオーバーヘッド計算:**
  SD-Access環境では、本来のL2フレームに VXLANヘッダー、UDPヘッダー、IPヘッダー、外側L2ヘッダーが追加されるため、合計 **50バイト以上** のオーバーヘッドが発生します。
  * **計算:** 通常のホストパケット 1500バイトをそのまま転送するには、ファブリック内のアンダーレイ（物理リンク）におけるL2 MTUは最低でも **1550バイト以上（シスコ推奨値は 9100バイト以上）** が確保されていなければ、VXLANパケットがアンダーレイで破棄される致命的な障害（サイレントロス）に直結します。

---

## 🛠 設定方法

Cisco IOS-XE 17.x（Catalyst 9000シリーズ）における実践的なコンフィグレーションコマンドです。

### 1. MACアドレステーブル管理

```bash
# グローバルでのMACアドレス動的学習エージングタイムの変更（デフォルト300秒から120秒へ短縮）
mac address-table aging-time 120

# 特定のVLAN（VLAN 10）のみ、動的学習エージングタイムを60秒に個別設定
mac address-table aging-time 60 vlan 10

# 静的（Static）MACアドレスエントリの登録（特定のポート Gi1/0/10 と VLAN 10 に固定）
mac address-table static 00aa.bbcc.0001 vlan 10 interface GigabitEthernet1/0/10

# 静的MACエントリ登録時に、他のポートへの一時的な移動（MAC Move）があった場合に転送をドロップする保護設定
mac address-table static 00aa.bbcc.0001 vlan 10 interface GigabitEthernet1/0/10 drop-on-mac-move

# インターフェイスにおける「未知のユニキャスト（Unknown Unicast）」および「マルチキャスト」パケットのフラッディング遮断
interface GigabitEthernet1/0/5
 switchport block unicast
 switchport block multicast
```

### 2. Errdisable 自動復旧の設定

```bash
# 現在の設定可能・有効化されている Errdisable 原因一覧の確認
# (設定コマンドの前にこれを特権モードで確認することを推奨)
show errdisable recovery

# グローバル設定：特定の原因（BPDU Guard / Port Security / Loopback）に対して自動復旧を有効化
errdisable recovery cause bpduguard
errdisable recovery cause psecurity-violation
errdisable recovery cause loopback

# グローバル設定：自動復旧を試みるタイマー間隔を「30秒」（最小値）に設定
errdisable recovery interval 30
```

### 3. レイヤ2 MTU（ジャンボフレーム）設定（IOS-XE 17.x 方式）

```bash
# グローバルでのシステムMTUの変更（IOS-XE 17.xでは即時反映、リロード不要）
system mtu 9100

# インターフェイス個別（ポート単位）でのL2 MTU設定（Catalyst 9000でのベストプラクティス）
interface GigabitEthernet1/0/1
 mtu 9100
```

---

## 🔍 検証コマンド

設定および稼働状態の健全性を評価するためのコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **MACアドレステーブルの一覧サマリ** | <code>show mac address-table</code> |
| **特定のMACエントリ情報、ポート、VLANの確認** | <code>show mac address-table address [MAC-Address]</code> |
| **動的/静的/自己学習MACエントリ数、エージングタイムサマリ** | <code>show mac address-table count</code> / <code>show mac address-table aging-time</code> |
| **MACアドレスの移動（MAC Move）に関するカウンタと検知確認** | <code>show mac address-table notification mac-move</code> |
| **ポートセキュリティ、MACアドレス数違反状態の確認** | <code>show port-security</code> |
| **現在Errdisable状態にあるポートと、その発生原因（Reason）の一覧** | <code>show interfaces status err-disabled</code> |
| **Errdisable自動復旧が有効な原因、タイマー稼働状況、次の復旧試行までの残り時間** | <code>show errdisable recovery</code> |
| **スイッチ全体のシステムMTU、および各ポートの現在のL2 MTU設定確認** | <code>show system mtu</code> |
| **特定の物理インターフェイス詳細（L2 MTU値および巨パケット Giants 等の破棄カウンタ）** | <code>show interfaces GigabitEthernet1/0/1</code> |
| **MACアドレステーブル学習プロセスのリアルタイムトレース** | <code>debug mac address-table learning</code> |

---

## 🚨 トラブルシュート

ラボ実機およびトラブルシューティングセクションにおける具体的な障害シナリオ、原因、対処方法です。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **スイッチ全体のMAC学習プロセスがハングし、すべての通信がすべてのポートへフラッディングされる。** | **MACアドレスバッファ（CAMテーブル）が上限超過（MAC Flooding攻撃または巨大ループ）**し、新規学習が不可になった。 | <code>show mac address-table count</code> | 1. <code>clear mac address-table dynamic</code> で一時キャッシュをクリア。<br>2. ループを検知し閉塞するか、不要なMACの学習を制限するためにポートセキュリティ（<code>port-security</code>）を適用する 。 |
| **ループ等のトラブル解決後も、対象ポートが「Down/Down (err-disabled)」から自動的に戻らない。** | Errdisable Recovery がグローバルで該当の原因（例: <code>loopback</code> / <code>udld</code>）に対して**有効化されていない**、または**タイマーが満了していない**。 | <code>show errdisable recovery</code> | 1. 該当原因を <code>errdisable recovery cause [原因]</code> で有効化。<br>2. <code>errdisable recovery interval 30</code> を設定して復旧を加速させる。 |
| **Errdisableリカバリによって一度ポートが回復（Up/Up）するが、約1〜2秒後に再び Errdisable に戻ってしまう。** | エラーの**根本原因（例：違反パケットの送信元が接続されたまま、光ファイバの片芯断線の物理的未修復）が継続**している。 | <code>show interfaces status err-disabled</code><br><code>show logging</code> | 物理的なループ配線の撤去、ポートセキュリティ違反クライアントの切断、UDLDアグレッシブの場合は光ファイバパッチコードの清掃・交換。 |
| **ホスト間の大容量パケットが静かに破棄（サイレントロス）される。Giantsエラーが入力ポートで激増する。** | 対向ポート間、または中継L2トランクリンク間で **L2 MTU が不一致（MTUミスマッチ）** となっている。 | <code>show system mtu</code><br><code>show interfaces [INT]</code> | 送信元から宛先までのデータパス上にあるすべての物理・論理インターフェイス（Port-Channel含む）のMTUを一貫した値（例：一律 9000 または 9100）に修正する。 |
| **物理ポートの L2 MTU を変更したが、 show ip interface 等の L3 MTU 表示に反映されない。** | L2 MTU と L3 MTU は内部処理として分離されている。L2 MTU はフレーム全体の上限、L3 MTU（IP MTU）はペイロードの上限を指す。 | <code>show ip interface [INT]</code> | インターフェイス設定配下で <code>ip mtu </code> コマンドを明示的に適用してL3バジェットを整合させる。 |

---

## ⚠ 制限事項

### 1. MACアドレステーブル管理の制限
* ハードウェア（ASIC）がサポート可能な最大CAMエントリ数は制限されています（Catalyst 9300 UADP 2.0等では最大32,000エントリ）。これを超えると、新規MACアドレスのパケットは宛先不明ユニキャストとして扱われます。
* VACLやPACLによるMACベースのアクセス制御ポリシーは、ハードウェアのTCAMリソースを消費するため、エントリ数過多によるメモリ制限（TCAM Exhaustion）に注意が必要です。

### 2. Errdisable 自動復旧の制限
* 一部の深刻なハードウェア障害、または一部のインターフェイス固有のASICエラー（例：`keepalive-loop`等の一部特殊ケース）は、自動復旧ポリシー（`errdisable recovery`）のリストに含まれず、手動の物理リロードまたは `shutdown` / `no shutdown` を必要とする場合があります。

### 3. レイヤ2 MTU の制限
* **ポートチャネル（EtherChannel）との整合性:** 
  論理インターフェイスである `Port-Channel` の MTU を変更する場合、**必ずメンバー物理ポートすべての MTU を一致させる必要があります。**
  メンバー間で MTU が一致していない場合、ポートチャネルから該当メンバーが強制的に離脱されるか、ポートチャネル自体が err-disabled に移行する重大な不整合を招きます。
* **物理ハードウェア境界:** 
  L2 MTU はハードウェア限界（通常 9216 バイト）を超えて設定することはできません。

---

## 🔄 他技術との関連

* **STP (Spanning Tree Protocol):** 
  ループバック検知やBPDUガードが動作したポートは、STPドメイン全体の崩壊を防ぐために Errdisable によって閉塞されます。Errdisable Recoveryタイマーと、STPのコンバージェンスタイマー（Forward DelayやMax Age）が不適切に干渉すると、ポートが復旧した瞬間に一時的なループが走り、ネットワークが不安定になります。
* **Port Security:** 
  不正MACの接続検知、MACアドレススプーフィングの防御。違反（Violation）時の挙動を `shutdown` に設定すると、ポートは即座に `err-disable` 状態になります。
* **SD-Access / VXLAN カプセル化:** 
  L2 MTU の整合性は、アンダーレイIPネットワークにおけるVXLANトンネルを形成するための必須条件です。L2 MTUが不足すると、カプセル化されたVXLANパケットが物理リンク上で Giant フレームとして破棄され、ファブリック内のエンドツーエンド通信が完全に切断されます。

---

## 🧩 比較表

### 1. MAC学習制御：ポートセキュリティ（Port Security） vs 未知のユニキャスト抑止（Unicast Blocking）

| 項目 | ポートセキュリティ (Port Security) | 未知のユニキャスト抑止 (Unicast Blocking) |
| :--- | :--- | :--- |
| **動作レイヤ** | レイヤ2（MACテーブルの学習数上限を制御） | レイヤ2（フラッディング動作を制御） |
| **主な用途** | 未認可の外部デバイス（MAC）の接続防止。 | 不要なブロードキャストドメイン内のフラッディング削減。 |
| **動作内容** | 許可されたMACアドレス数（デフォルト1）を超えるとポートを閉塞。 | 宛先がCAMにないパケットを、そのインターフェイスへの転送から除外（Block）。 |
| **Errdisableとの関連** | 違反モードが `shutdown` の場合、ポートは Errdisable へ移行。 | Errdisable 状態は発生させない。静かにフラッディングのみをブロックする。 |

### 2. MTUの概念：L2 MTU (System MTU) vs IP MTU (L3 MTU)

| 比較項目 | L2 MTU (System MTU) | IP MTU (L3 MTU / IP MTU) [23, 24, 1.2.k] |
| :--- | :--- | :--- |
| **適用範囲** | イーサネットヘッダーのペイロードの最大サイズ（FCS、L2タグ除くフレーム最大値）。 | レイヤ3（IPパケット）ヘッダーからペイロードの最大サイズ。 |
| **フラグメンテーション挙動** | **一切行われない。** 超過フレームは即座にポート上で破棄（Giantsカウンタ加算）。 | DFビットが0の場合、送信元またはルータ（L3境界）でパケットを**自動的に断片化（フラグメント）**。 |
| **設定レベル** | 物理ポート、ポートチャネル。 | SVI、ルーテッドポート、トンネル（GRE/VTI）。 |
| **カプセル化への配慮** | VXLAN等のL2外側カプセル化の総和に耐えうるよう、十分な大きさ（通常9000以上）を確保。 | パス内の最小MTU（Path MTU）を意識し、1400〜1450バイトに調整することが推奨される（MSS調整との併用）。 |

---

## 💡 ベストプラクティス

1. **SD-AccessファブリックにおけるMTU一貫設定:**
   アンダーレイを構成するすべてのコアルータ・コアスイッチ（Catalyst 9500/9600）の物理ポートおよびポートチャネルにおいて、一律で **`mtu 9100`** 以上の設定を投入し、カプセル化に伴う断片化処理・ドロップを未然に防止する。
2. **BPDU Guard 違反の自動リカバリ最小化:**
   エッジスイッチ（Catalyst 9300）のホストアクセスポートで動作する BPDU Guard 違反による err-disable を、タイマー30秒で自動復旧させる設計を構築する。これにより、不正に個人用スイッチを接続して外したユーザーのポートが、管理者の介入なく迅速に自己復旧します。
3. **MACフラップ時のポート隔離とErrdisable:**
   レイヤ2の完全な冗長化を行っている環境では、万が一のSTP障害に備え、MACフラッピングを検知したポートを自動で Errdisable に移行するよう構成し、ネットワーク全体のハング（融解）を局所的な物理閉塞で防ぎます。

---

## 📝 ラボ学習・設定サンプル例

CCIE EIラボ試験に対応した11個の実践的な設定・検証シナリオです。

### 1. 静的MACアドレスの登録と drop-on-mac-move の構成
**【問題】** 
VLAN 10上の特定のセキュアホストのMACアドレス（`0011.2233.4455`）を、SW1 の `GigabitEthernet1/0/10` に固定してください。また、他のポートから同一のMACアドレスによるなりすましパケットが届いた場合、スイッチがそのパケットを破棄（Drop）するように設定してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# mac address-table static 0011.2233.4455 vlan 10 interface GigabitEthernet1/0/10 drop-on-mac-move
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show mac address-table static | include 0011.2233.4455
# 出力に STATIC、かつ Gi1/0/10 が指定されていることを確認します。
```

---

### 2. 特定インターフェイスにおける未知のユニキャスト/マルチキャストフラッディングの遮断
**【問題】** 
SW1の `GigabitEthernet1/0/5` ポートに接続されているホストに対して、宛先が学習されていない未知のユニキャストパケットおよびマルチキャストパケットが流入した場合に、このポートを経由したネットワークへの不要なフラッディングをすべてブロックするよう構成してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/5
SW1(config-if)# switchport block unicast
SW1(config-if)# switchport block multicast
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/5 switchport
# 出力内の「Unknown unicast blocked: enabled」「Unknown multicast blocked: enabled」を確認します。
```

---

### 3. VLAN単位の個別MACアドレステーブル・エージングタイムチューニング
**【問題】** 
SW1全体の動的MACエージングタイムはデフォルト値（300秒）を維持したまま、高頻度でホストの移動が発生する「VLAN 20」に所属するMACエントリのみ、エージングタイムを「60秒」に短縮して、CAMテーブルの枯渇を抑止してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# mac address-table aging-time 60 vlan 20
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show mac address-table aging-time
# VLAN 20 に対するエージングタイムが 60s になっていることを確認します。
```

---

### 4. BPDU Guard 違反による Errdisable 発生時の自動リカバリ構成
**【問題】** 
アクセスポートにおいて、BPDU Guard違反によってポートが `err-disabled` になった場合、自動的に復旧プロセスを実行するように構成してください。また、復旧間隔（リカバリインターバル）は、IOSがサポートする最短時間（30秒）に短縮してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# errdisable recovery cause bpduguard
SW1(config)# errdisable recovery interval 30
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show errdisable recovery
# 「bpduguard」行が「Enabled」であり、かつ「Timer interval: 30 seconds」と表示されていることを確認します。
```

---

### 5. Port Security 違反による閉塞と自動リカバリタイマーの組み合わせ
**【問題】** 
SW1のポートセキュリティが動作するポート（Gi1/0/12）において、不正デバイスの接続（セキュリティアドレス制限超過）を検知した際、ポートを物理的に閉塞（err-disabled）させてください。さらに、この閉塞が発生してから自動的に30秒後にポートを再起動させて、再試行させるリカバリ設定を併せて構成してください。

**【設定例】**
```bash
SW1# configure terminal
# 1. インターフェイス側でPort-Securityおよび違反モードをシャットダウンに設定
SW1(config)# interface GigabitEthernet1/0/12
SW1(config-if)# switchport mode access
SW1(config-if)# switchport port-security
SW1(config-if)# switchport port-security violation shutdown
SW1(config-if)# exit

# 2. グローバルでPort-Security違反に対する自動復旧を設定
SW1(config)# errdisable recovery cause psecurity-violation
SW1(config)# errdisable recovery interval 30
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show errdisable recovery | include psecurity-violation
# psecurity-violation に対するリカバリが Enabled であることを確認します。
```

---

### 6. MACフラッピング（L2ループ）検知時のポート自動閉塞（Errdisable）の有効化
**【問題】** 
SW1は特定のVLAN内で発生するMACフラッピング（MAC Flapping）による転送ループから保護される必要があります。MACフラップによるerr-disableが機能するようにグローバルで有効化し、かつ検知時に自動で30秒後に復旧を試みるように設定してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# errdisable detect cause mac-flapping
SW1(config)# errdisable recovery cause mac-flapping
SW1(config)# errdisable recovery interval 30
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show errdisable recovery | include mac-flapping
# 「mac-flapping」の検知およびリカバリが有効になっていることを確認します。
```

---

### 7. OSPFネイバー不確立に対応する L2 MTU 9000 への変更（Catalyst 9000系ポート単位方式）
**【問題】** 
SW1（Catalyst 9300）と中継L2トランクで接続されたルーテッドスイッチとの間で、OSPFのDBDパケット超過によるパケットドロップが発生し、ネイバーが `EXSTART` 状態から進まなくなりました。インターフェイス `GigabitEthernet1/0/20` の L2 MTU を「9000バイト」に設定し、ジャンボフレームを即時透過させて再起動なしに通信を復旧させてください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/20
SW1(config-if)# mtu 9000
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/20 | include MTU
# MTU 9000 bytes がポートに適用されていることを確認します。
```

---

### 8. システム一律のレイヤ2 MTU（System MTU）の変更
**【問題】** 
SW1に搭載されているすべてのL2/L3ポートにおいて、デフォルトフレームサイズ（1500バイト）から、シスコのファブリック設計推奨値である「9100バイト」のイーサネットフレームを透過できるように、再起動を伴わずにシステム全体へ即時適用してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# system mtu 9100
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show system mtu
# 「System MTU size is 9100 bytes」という表示を確認します。
```

---

### 9. ポートチャネル（EtherChannel）メンバー物理ポートの一貫した L2 MTU 設定
**【問題】** 
SW1とSW2を結ぶ `Port-channel 5`（構成物理ポート：`GigabitEthernet1/0/1` および `GigabitEthernet1/0/2`）において、MTUの不一致によるポートチャネル切断（err-disabled）を避けるために、物理メンバーポートすべてに一貫して「9000バイト」の L2 MTU を設定してください。

**【設定例】**
```bash
SW1# configure terminal
# メンバー物理インターフェイスすべてにまとめてMTUを適用
SW1(config)# interface range GigabitEthernet1/0/1 - 2
SW1(config-if-range)# mtu 9000
SW1(config-if-range)# exit

# 論理ポートチャネルインターフェイスのMTUも合わせて整合させる
SW1(config)# interface Port-channel 5
SW1(config-if)# mtu 9000
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show system mtu
# 各物理インターフェイスが MTU 9000 として稼働しており、Port-channel 5 に含まれていることを確認します。
```

---

### 10. L2 MTU と IP MTU (L3 MTU) の整合性制御
**【問題】** 
SW1のルーテッドポート `GigabitEthernet1/0/15` において、L2 MTU を「9000バイト」に引き上げると同時に、IP層（レイヤ3）のIPペイロード最大サイズ（IP MTU）も「9000バイト」に変更し、L2/L3両方でジャンボフレームのパケット断片化なしにフルスピード転送が動作するように構成してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/15
SW1(config-if)# no switchport
SW1(config-if)# mtu 9000
SW1(config-if)# ip mtu 9000
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show ip interface GigabitEthernet1/0/15 | include MTU
# 「IP MTU is 9000 bytes」を確認します。
```

---

### 11. 【Troubleshooting】Errdisable 閉塞ポートの CLI 手動強制リカバリ（udld reset）
**【問題】** 
光ファイバーリンク（Gi1/0/24）がUDLDアグレッシブモードの誤検知、または一時的なケーブル清掃によって `err-disabled`（状態：`udld`）となり閉塞されました。物理ケーブルの接続を正常に戻した後、インターフェイスの `shutdown` / `no shutdown` を実行せずに、UDLDによって閉塞されたポートのみを一括で CLI から即座に解放（手動強制リカバリ）してください。

**【設定例】**
特権EXECプロンプト直下から以下を実行します。

```bash
SW1# udld reset
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/24 status
# ポートのステータスが「err-disabled」から「notconnect」または「connected」へ即時に遷移していることを確認します。
```

---

## ❓ 想定試験問題

CCIE EIラボ実技および診断（Diagnostic）試験をシミュレートした6つのシナリオ問題です。

### 1. 【コンフィグ読解：MTU変更後の再起動依存の有無】
**問題:**
以下のCatalyst 9300（IOS-XE 17.x）上で実施されたコンフィグ変更ログを読み、この設定を反映して有効化するためにスイッチの再起動（reload）が必要かどうか、理由とともに述べてください。
```text
SW1# configure terminal
SW1(config)# system mtu 9100
SW1(config)# interface GigabitEthernet1/0/1
SW1(config-if)# mtu 9000
```

**解答・解説:**
* **回答:** 再起動は**不要**です（即時に反映されます）。
* **解説:**
  レガシーなCatalystスイッチ（3560/3750/3850等）では、`system mtu` コマンドでJumboフレームサイズを変更した後に適用するためには `reload` が必須であり、再起動するまで設定値は仮保留（Pending）の状態になっていました。しかし、Catalyst 9000シリーズ（IOS-XE 17.x以降）をベースとするハードウェアアーキテクチャでは、グローバルの `system mtu` 変更および物理ポート個別の `mtu` 変更はともに**ハードウェア（ASIC）に対して動的に即時反映可能**であり、再起動プロセスなしでMTUサイズが拡張されます。

---

### 2. 【トラブルシュート：Errdisableリカバリの無制限フラッピング抑止】
**問題:**
SW1において、STP BPDUガード違反により物理ポートが `err-disabled` に陥りました。自動復旧を高速化するために、以下の設定を施しました。
```text
SW1(config)# errdisable recovery cause bpduguard
SW1(config)# errdisable recovery interval 30
```
しかし、ポートに接続されている不正なスイッチが物理的に取り外されていないため、30秒ごとに「ポート復旧（Up）➔ 違反検知 ➔ Errdisable閉塞（Down）」を永遠に繰り返すフラッピングが発生し、STPトメイン全体に不要なTC（Topology Change）が伝搬しています。
このフラッピングによる二次災害を防ぐための設計上の回避策、またはIOS-XEの設定を1つ提示してください。

**解答・解説:**
* **回答:** **`errdisable recovery` の自動復旧タイマーを無効化（またはデフォルト値300秒以上へ引き上げ）し、さらに `errdisable detect cause` 側の保護ポリシーを見直します。**
* **解説:**
  Errdisable Recoveryタイマー（最短30秒）は、テスト環境や一時的なトラブルには非常に便利ですが、悪意ある物理的な不正接続が持続している環境下では、30秒という極めて短い周期でポートが再起電力を試み、その直後に再度切断されるため、スイッチから他の中継トランクポートに向けて膨大なトポロジー変更（STP TC）の通知が送信され、インフラ全体のコンバージェンス（SPF再計算）を阻害します。
  本番のCCIEラボ環境や実務では、このフラッピングを防ぐために、STPのエッジポートに `spanning-tree portfast`（または `spanning-tree portfast edge`）および `spanning-tree bpduguard enable` を適用した上で、自動復旧ポリシーから `bpduguard` を除外するか、あるいは `errdisable recovery interval` を長めに設計することが鉄則です。

---

### 3. 【Design：SD-Access VXLANアンダーレイにおけるMTU設計の計算】
**問題:**
ある企業がSD-Access（Software-Defined Access）ファブリックを構築しています。ホスト（クライアントPC）の最大パケットサイズ（MTU）は 1500 バイトです。
ファブリックエッジスイッチとファブリックボーダースイッチ間を結ぶアンダーレイ物理IPリンクにおいて、一切のパケット断片化（フラグメント）を発生させず、カプセル化オーバーヘッドを安全に透過させるために必要な**最低L2 MTU値**を計算して算出し、さらにシスコが設計ガイドで推奨しているベストプラクティス設定値を提示してください。

**解答・解説:**
* **計算プロセスと最低必要値:**
  ホストパケット（IPペイロードサイズ）：**1500 バイト**
  SD-Access VXLANカプセル化オーバーヘッドの構成：
  * 内側イーサネットFCS（4バイト）を除去し、VXLAN-GPO（グループポリシーオプション）ヘッダーを付与：**8 バイト**
  * 外側UDPヘッダー：**8 バイト**
  * 外側IPヘッダー：**20 バイト**
  * 外側イーサネットヘッダー（802.1Qタグ含む）：**18 バイト**
  * VXLANカプセル化全体の合計必要オーバーヘッド：**最低 50〜54 バイト**
  したがって、物理リンクを通過する際の最低限のL2 MTUは、`1500 + 54 =` **最低 1554 バイト** 以上が物理的に必須となります。
* **シスコ推奨ベストプラクティス値:**
  将来のIPv6拡張ヘッダーや追加タグ（SGT、MPLS、QinQなど）のオーバーヘッドを柔軟に包含させるため、シスコのCVD（Cisco Validated Design）ガイドでは、アンダーレイリンクのL2 MTUを一貫して **`9100` バイト**（ジャンボフレーム対応）に設定することをベストプラクティスとして推奨しています。

---

### 4. 【トラブルシュート：未知のユニキャストフラッディングとMACエージングタイムの罠】
**問題:**
以下のログがSW1（Catalyst 9300）に出力され続け、特定の共有データストレージに接続されたポート（Gi1/0/10）に向かうトラフィックにおいて、激しいパケットロスが確認されました。
```text
SW1# show mac address-table count
Active DYNAMIC MAC entries: 32000 (Maximum limit reached!)
```
エージングタイムがデフォルト（300秒）であるため、CAMが枯渇したスイッチはホスト宛てのパケットを Unknown Unicast として全ポートにフラッディングしています。これを一時的に防ぐために、不要なポート（Gi1/0/15）で Unknown Unicast のフラッディングをインターフェイスレベルで抑止するための正確なコマンドシーケンスを記載してください。

**解答・解説:**
* **対処設定コマンド:**
  ```text
  SW1# configure terminal
  SW1(config)# interface GigabitEthernet1/0/15
  SW1(config-if)# switchport block unicast
  ```
* **解説:**
  CAMテーブルの上限に達したスイッチは、パケットの宛先MACアドレスを検索できなくなり、新規のパケットをすべてハブと同様に同一VLAN内の全ポートへフラッディングさせます。特定のポート（例えばトラフィック量の多いサーバーやストレージポートではない一般PC接続ポートなど）に対して、この不要なフラッディングパケットの流入を防止するために `switchport block unicast` を適用することで、該当ポート配下の帯域幅飽和や情報漏洩を防御できます。

---

### 5. 【Design：StackWise Virtual（SV）環境におけるMACアドレスの不一致と回復ポリシー】
**問題:**
2台の物理スイッチ（SW1、SW2）を仮想的に1台に統合する「Cisco StackWise Virtual (SV)」テクノロジーがディストリビューション層で動作しています。
論理スイッチにマルチシャーシ EtherChannel（MEC）で接続されたサーバーホストが、片側の物理スイッチのハードウェアトランシーバ不良によりパケットが正常に送受信できなくなり、MACフラッピングを検知しました。この際、 StackWise Virtual リンク（SVL）への影響を最小限に抑えつつ、不良リンクを持つポートを即座にerr-disabledに移行させて正常な側のシャーシへの迂回を成功させるために、どのような設定を施すべきか述べてください。

**解答・解説:**
* **対策設計と設定方法:**
   StackWise Virtual を構成している場合、シャーシ間（SW1 と SW2）の転送経路のバックアップとして機能する SVL（StackWise Virtual Link）自体でMACフラップを検知して閉塞してしまうと、論理構成そのものが崩壊（デュアルアクティブ状態の発生など）します。
  そのため、SVLを構成している物理リンク（通常は10G/40G/100Gポート）を検知対象から明示的に除外するか、あるいはサーバーが接続される通常のダウンリンク（MEC）側で **`errdisable detect cause mac-flapping`** および **`switchport port-security`** を適用しておくことで、シャーシ間の制御リンク（SVL）を保護しつつ、不良ダウンリンク側のみをerr-disabledへと落としてポートチャネル（LACP）の力で正常な物理シャーシ側のリンクへと安全にトラフィックを迂回（サブ秒コンバージェンス）させることができます。

---

## 🔗 参考リソース

### Cisco Live (動画・スライド)
* [**BRKCRS-2031: Enterprise Campus Design - Layer 2 Control Plane**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031)
  * MACアドレステーブル管理、CAMの保護、BPDUガード、Loop Guardの体系的設計ガイド。
* [**BRKARC-3437: Cisco Catalyst 9000 Switching Architecture Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-3437)
  * Catalyst 9000シリーズのASIC（UADP）上で動作するCAMエントリ学習とL2 MTU制御方式の詳細。

### Configuration ガイド（Cisco公式）
* [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Layer 2 Configuration Guide (Release 17.x)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/lyr2/b_17x_lyr2_9300_cg.html)
  * MACアドレステーブル、MTU、Errdisable設定の全コマンド、パラメータ仕様。
* [**Configuring Port-Security and Switch Security Features (Catalyst 9000)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/sec/b_17x_sec_9300_cg.html) [13, 34, 42.a]
  * ポートセキュリティ違反違反による Errdisable トリガーとの親和性設計ガイド。

### テクニカルドキュメント・テクニカルノーツ
* [**Understanding and Troubleshooting Errdisable Port State on Cisco Switches**](https://www.cisco.com/c/en/us/support/docs/lan-switching/spanning-tree-protocol/6998-errdisable-recovery.html)
  * Errdisable状態を招くすべての原因リストと、リカバリメカニズムの解説。
* [**Cisco Software-Defined Access (SD-Access) Design Guide (CVD)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)
  * ファブリック内オーバーレイVXLANパケットを透過させるためのMTU 9100設計一貫性に関する完全なベストプラクティス。

---

## 📝 **補足（Notes）**

* **MAC学習メカニズムの挙動図解:**
  ```text
  [Ingress Ethernet Frame]
            │
            ├─► 1. [Source MAC Address Checked]
            │       ├─► (CAM テーブルに存在しない) ➔ ポート、VLAN と共に動的学習
            │       └─► (CAM テーブルに存在) ➔ エージングタイムタイマーを 300秒（初期値）にリセット
            │
            └─► 2. [Destination MAC Address Checked]
                    ├─► (CAM テーブルに存在) ➔ 対象ポートへユニキャスト転送
                    └─► (CAM テーブルに存在しない) ➔ 同一VLANの全ポートへフラッディング（Unknown Unicast Flooding）
  ```
* **注意（L2 MTU とカプセル化タグ）:**
  スイッチに `mtu 1500` と設定した場合、ASICはL2イーサネットフレームヘッダー（14バイト）とFCS（4バイト）の合計 **18バイト** を除外したペイロード部のサイズで制限します。したがって、物理ワイヤを流れるフレーム全体の長さは `1500 + 18 = 1518` バイトになります（802.1Qタグが挿入されるトランクリンクの場合は `1522` バイト）。MTUの計算ミスを防ぐため、フレームが追加のVLANタグ（Dot1q）やカプセル化（VXLAN等）を含むトランクインターフェイスを通過する場合は、ヘッダー長の変化を考慮してL2 MTUを十分に大きく設計することが最善です。


### 🛠 本項で使用されるコマンド

#### (i) Managing MAC address table

```md
# ===============================
# MAC Address Table Configuration
# ===============================

## MAC アドレステーブルのエージングタイム設定
Switch1(config)# mac address-table aging-time 500 vlan 2

## 動的 MAC アドレスの削除（全削除）
Switch1# clear mac address-table dynamic

## 動的 MAC アドレスの削除（MAC 指定）
Switch1# clear mac address-table dynamic address c2f3.220a.12f4

## 動的 MAC アドレスの削除（インターフェイス指定）
Switch1# clear mac address-table dynamic interface gigabitethernet1/0/1

## 動的 MAC アドレスの削除（VLAN 指定）
Switch1# clear mac address-table dynamic vlan 4

## 動的 MAC アドレスの表示
Switch1# show mac address-table dynamic

# ===============================
# MAC Notification (SNMP Traps)
# ===============================

## MAC アドレス変更通知トラップ（Change Notification）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 変更通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification change

Switch1(config)# ! MAC アドレス変更通知を有効化
Switch1(config)# mac address-table notification change

Switch1(config)# ! 通知間隔を 123 秒に設定
Switch1(config)# mac address-table notification change interval 123

Switch1(config)# ! 通知履歴サイズを 100 に設定
Switch1(config)# mac address-table notification change history-size 100

Switch1(config-if)# ! 特定インターフェイスで MAC 追加通知を有効化
Switch1(config-if)# snmp trap mac-notification change added


## MAC アドレス移動通知トラップ（MAC Move）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 移動通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification move

Switch1(config)# ! MAC 移動通知を有効化
Switch1(config)# mac address-table notification mac-move


## MAC アドレス閾値通知トラップ（Threshold）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 閾値通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification threshold

Switch1(config)# ! MAC 閾値通知を有効化
Switch1(config)# mac address-table notification threshold

Switch1(config)# ! 通知間隔を 123 秒に設定
Switch1(config)# mac address-table notification threshold interval 123

Switch1(config)# ! 閾値を 78 に設定
Switch1(config)# mac address-table notification threshold limit 78


# ===============================
# Static MAC Address Configuration
# ===============================

## 静的 MAC アドレスの設定（インターフェイスへ割り当て）
Switch1(config)# ! VLAN 4 の静的 MAC を Gi1/1/1 に設定
Switch1(config)# mac address-table static c2f3.220a.12f4 vlan 4 interface gigabitethernet1/1/1

## 静的 MAC アドレスのドロップ設定（フィルタ）
Switch1(config)# ! VLAN 4 の指定 MAC をドロップ
Switch1(config)# mac address-table static c2f3.220a.12f4 vlan 4 drop


# ===============================
# MAC Learning Control
# ===============================

## VLAN の MAC 学習を無効化
Switch1(config)# ! VLAN 200 の MAC 学習を無効化
Switch1(config)# no mac address-table learning vlan 200

## MAC 学習状態の確認
Switch1# ! MAC 学習状態の確認
Switch1# show mac-address-table learning
```
---

#### (ii) Errdisable recovery

```md
# ===============================
# Errdisable Detection / Recovery
# ===============================

## Errdisable の原因を確認
Switch1# ! Errdisable の検出状態を確認
Switch1# show errdisable detect

## Errdisable Recovery の状態を確認
Switch1# ! 自動復旧の設定とタイマーを確認
Switch1# show errdisable recovery

## Errdisable Recovery を有効化（原因を指定）
Switch1(config)# ! BPDU Guard による errdisable を自動復旧
Switch1(config)# errdisable recovery cause bpduguard

Switch1(config)# ! UDLD による errdisable を自動復旧
Switch1(config)# errdisable recovery cause udld

Switch1(config)# ! Link-flap による errdisable を自動復旧
Switch1(config)# errdisable recovery cause link-flap

## Recovery タイマーの変更（デフォルト 300 秒）
Switch1(config)# ! Recovery タイマーを 400 秒に変更
Switch1(config)# errdisable recovery interval 400

## Errdisable 状態のポートを手動で復旧
Switch1(config)# ! shutdown → no shutdown で復旧
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# shutdown
Switch1(config-if)# no shutdown

# ===============================
# BPDU Guard / PortFast
# ===============================

## PortFast を有効化
Switch1(config)# ! 端末接続ポートで PortFast を有効化
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# spanning-tree portfast enable

## BPDU Guard を有効化
Switch1(config)# ! BPDU 受信時にポートを errdisable にする
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# spanning-tree bpduguard enable

# ===============================
# EtherChannel Misconfiguration
# ===============================

## EtherChannel の状態確認
Switch1# ! EtherChannel のステータスを確認
Switch1# show etherchannel summary

## EtherChannel の正しい設定例（desirable）
Switch1(config)# ! 両側が同意した場合のみチャネル形成
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# channel-group 3 mode desirable non-silent

# ===============================
# UDLD
# ===============================

## UDLD のエラー例（参考）
Switch1# ! UDLD による errdisable の syslog 例
Switch1# %PM-SP-4-ERR_DISABLE: udld error detected on Gi4/1

# ===============================
# Link-Flap
# ===============================

## Link-flap の値を確認
Switch1# ! フラップ回数と時間を確認
Switch1# show errdisable flap-values

# ===============================
# Port-Security
# ===============================

## Port-security の shutdown モード
Switch1(config)# ! セキュリティ違反時にポートを shutdown
Switch1(config)# interface gigabitethernet4/8
Switch1(config-if)# switchport port-security violation shutdown

# ===============================
# L2PT Guard
# ===============================

## L2PT Guard の設定例
Switch1(config)# ! L2 プロトコルのトンネリング設定
Switch1(config)# interface gigabitethernet0/7
Switch1(config-if)# l2protocol-tunnel stp

## L2PT Guard の自動復旧
Switch1(config)# ! L2PT Guard による errdisable を自動復旧
Switch1(config)# errdisable recovery cause l2ptguard
```

---

#### (iii) L2 MTU

```md
# ===============================
# System MTU Configuration (IOS 15.2)
# ===============================

## FastEthernet のシステム MTU を 1900 bytes に設定
Switch1(config)# ! FastEthernet の MTU を 1900 に設定
Switch1(config)# system mtu 1900

## Gigabit/10G の Jumbo MTU を 7500 bytes に設定
Switch1(config)# ! ギガビット/10G の Jumbo MTU を 7500 に設定
Switch1(config)# system mtu jumbo 7500

## L3 ポートのルーティング MTU を 2000 bytes に設定
Switch1(config)# ! ルーティング MTU を 2000 に設定（再起動不要）
Switch1(config)# system mtu routing 2000

## MTU 設定の確認
Switch1# ! 現在の MTU 設定を確認
Switch1# show system mtu

## MTU 設定反映のための reload
Switch1# ! system mtu / jumbo 設定反映のため reload
Switch1# reload

## 範囲外の Jumbo MTU 設定例（エラー）
Switch1(config)# ! Jumbo MTU に 25000 を設定しようとしてエラー
Switch1(config)# system mtu jumbo 25000
^
% Invalid input detected at '^' marker.
```

```md
# ===============================
# Catalyst 9300 MTU Configuration (IOS-XE 17.9.x)
# ===============================

## システム MTU を 1500 に設定（即時反映）
Switch1(config)# ! システム MTU を 1500 に設定
Switch1(config)# system mtu 1500

## Jumbo MTU を 9198 に設定（即時反映）
Switch1(config)# ! Jumbo MTU を 9198 に設定
Switch1(config)# system mtu jumbo 9198

## L2 インターフェイス MTU を 9000 に設定
Switch1(config)# ! L2 インターフェイスの MTU を 9000 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# mtu 9000

## L3 インターフェイスの IPv4 MTU を 1500 に設定
Switch1(config)# ! L3 IPv4 MTU を 1500 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# ip mtu 1500

## L3 インターフェイスの IPv6 MTU を 1500 に設定
Switch1(config)# ! L3 IPv6 MTU を 1500 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# ipv6 mtu 1500

## MTU 設定の確認
Switch1# ! MTU 設定を確認
Switch1# show system mtu
```



