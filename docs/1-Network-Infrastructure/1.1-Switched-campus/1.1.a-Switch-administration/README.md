---
layout: default
title: 1.1.a-Switch-administration
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.1.a-Switch-administration

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.a Switch administration」に関する内容を、提供されたソース資料に基づいて表形式で整理しました。

---

## 1.1.a (i) Managing MAC address table

### 📘 概要
スイッチは、受信したイーサネットフレームの送信元MACアドレスを学習し、着信ポートおよびVLANに関連付けて**MACアドレステーブル（CAM：Content Addressable Memoryテーブル）**に記録します。この情報を基に転送先を決定し、未知のユニキャストフラッディングを最小限に抑えます。

### 🔑 要点
| 項目 | 内容 |  
| :--- | :--- |  
| **学習プロセス** | フレーム受信時に送信元MACを読み取り、ポート/VLAN情報を動的に登録。 |  
| **エージング** | デフォルト300秒。一定期間通信がないエントリは削除される。 |  
| **MAC移動 (Move)** | 同一MACが別ポートで検出された際の更新。通知トラップの設定が可能。 |  
| **静的登録** | 手動でMACとポートを紐付け、エージングによる削除を防止する。 |  
| **通知機能** | 追加、削除、移動、またはしきい値超過をSNMPトラップで通知可能。 | 

### 🎯 試験対策 (CCIE EIレベル)
*   **CAMの構造理解**: CAMはバイナリ結果（0または1）を高速で検索する高機能メモリであることを理解しておく。
*   **トラブルシューティング**: `show mac address-table dynamic` で特定ポートに複数のMACがある場合、その先にスイッチやハブ、仮想スイッチが存在することを即座に判断する。

### 🛠 設定・検証コマンド
| 目的 | コマンド | 
| :--- | :--- |  
| **静的エントリ追加** | `mac address-table static [MAC] vlan [ID] interface [INT]` | 
| **エージングタイム変更** | `mac address-table aging-time [秒]` |  
| **テーブル表示** | `show mac address-table [dynamic\|static\|vlan ID]` | 
| **テーブル消去** | `clear mac address-table dynamic` |  

---

## 1.1.a (ii) Errdisable recovery

### 📘 概要
ポートが特定のプロトコル違反や異常を検知した際に、デバイス保護のため自動的にポートを無効化（err-disable状態）にする機能、およびそれを自動復旧させるメカニズムです。

### 🔑 要点
| 項目 | 内容 |  
| :--- | :--- |  
| **検知原因 (Causes)** | `bpduguard`, `psecure-violation`, `link-flap`, `storm-control` など。 | 
| **自動復旧の仕組み** | `errdisable recovery` により、管理者の介入なしに設定間隔後に再アクティブ化。 |  
| **デフォルト間隔** | 300秒。最短30秒などの調整が可能。 | 

### 🎯 試験対策 (CCIE EIレベル)
*   **迅速な復旧要件**: ラボ試験で「特定の違反（BPDUガード等）によるダウンから、規定時間内に自動復旧させよ」というタスクに対応できるよう、原因（cause）の指定とインターバル（interval）の設定をセットで覚える。

### 🛠 設定・検証コマンド
| 目的 | コマンド |  
| :--- | :--- | 
| **原因の有効化** | `errdisable detect cause [all\|原因]` |  
| **自動復旧の有効化** | `errdisable recovery cause [原因]` |  
| **復旧間隔の設定** | `errdisable recovery interval ` |  
| **ステータス確認** | `show errdisable recovery` / `show interfaces status err-disabled` |  

---

## 1.1.a (iii) L2 MTU

### 📘 概要
インターフェイスがドロップせずに通過させることができる最大フレームサイズを規定します。

### 🔑 要点
| 項目 | 内容 |  
| :--- | :--- |  
| **標準MTU** | 1500バイト（イーサネットペイロード）。 |  
| **ジャンボフレーム** | 1500バイトを超えるサイズ（最大9000〜9216バイト）。 |  
| **不一致の影響** | OSPFの隣接関係が `EXSTART` で止まるなどのルーティング問題を引き起こす。 |  
| **設定レベル** | プラットフォームにより、システム全体での設定や個別ポート設定がある。 |  

### 🎯 試験対策 (CCIE EIレベル)
*   **MTU不一致の特定**: 物理的な疎通はあるが特定プロトコルが動作しない場合、`show vlan mtu` で不一致（Mismatch）がないか確認する。
*   **オーバーヘッドの考慮**: MPLS等のタグ付け環境では、L2 MTUを拡張（Baby Giant対応）させる必要がある。

### 🛠 設定・検証コマンド
| 目的 | コマンド |  
| :--- | :--- |  
| **システムMTU設定** | `system mtu [サイズ]` または `system jumbomtu [サイズ]` | 
| **個別MTU設定** | `interface` モード配下で `mtu [サイズ]` または `ip mtu [サイズ]` |  
| **設定確認** | `show system mtu` / `show vlan mtu` | 
| **VLAN情報での確認** | `show vlan brief` (システムMTU設定が表示される場合がある) | 

---

## 参考リソースリンク

### Configurationガイド
*   [Managing MAC Address Table (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_mac_addr_table.html)
*   [Configuring System MTU (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/int_hw/b_179_int_hw_9300_cg/configuring_system_mtu.html)
*   [Errdisable Recoveryのトラブルシューティングと設定](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/69980-errdisable-recovery.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKENS-2031: Enterprise Campus Design](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates (MTU/PMTUD関連含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

## 📝 補足
- 補足情報をここに追加してください。

