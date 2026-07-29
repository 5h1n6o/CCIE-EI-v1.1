---
layout: default
title: 1.1.b-Layer-2-protocols
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.1.b-Layer-2-protocols

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.b Layer 2 protocols」に関連する CDP, LLDP, および UDLD について、提供されたソース資料に基づき整理しました。

---

## 1.1.b (i) CDP, LLDP

### 📘 概要

直接接続された隣接デバイスを動的に発見するためのレイヤ2プロトコルです。
*   **CDP (Cisco Discovery Protocol):** シスコ独自のプロトコル。デフォルトで有効になっており、シスコデバイス間での情報交換に使用されます。
*   **LLDP (Link Layer Discovery Protocol):** IEEE 802.1ABで標準化されたマルチベンダー対応のプロトコルです。

### 🔑 要点

| 特徴 | CDP | LLDP |
| :--- | :--- | :--- |
| **標準規格** | シスコ独自 (レイヤ2) | IEEE 802.1AB |
| **デフォルト** | 有効 | プラットフォームにより異なる |
| **通知内容** | ホスト名、IP、ポート、プラットフォーム、Native VLAN、VTPドメイン等 | CDPとほぼ同様（LLDP-MEDによる拡張あり） |
| **主な用途** | 物理トポロジの把握、設定不一致（Duplex/VLAN）の検出 | マルチベンダー環境での隣接デバイス管理 |

### 🎯 試験対策 (CCIE EIレベル)

*   **トポロジの可視化:** 物理構成図が与えられない、あるいは不明確なラボ環境において、`show cdp neighbors` は物理接続を確認する最速の手段です。
*   **セキュリティ:** 不要なインターフェイス（外部網など）でのプロトコル停止 (`no cdp run`, `no lldp run`) が要件となる場合があります。
*   **トラブルシューティング:** ネイティブVLANの不一致やデュプレックスの不一致をログメッセージで迅速に特定します。
*   **LLDP-MED:** IP Phone 等のエンドポイントデバイスに対するネットワークポリシー配布など、コラボレーション連携の基礎として理解が必要です。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **CDPをグローバルで有効化** | <code>cdp run</code> |
| **CDPをグローバルで無効化** | <code>no cdp run</code> |
| **インターフェイス単位での有効化** | <code>cdp enable</code> |
| **LLDPをグローバルで有効化** | <code>lldp run</code> |
| **CDP隣接デバイスの要約表示** | <code>show cdp neighbors</code> |
| **CDP隣接デバイスの詳細表示** | <code>show cdp neighbors detail</code> |
| **特定のネイバー情報の確認** | <code>show cdp entry [Name]</code> |
| **LLDP隣接デバイスの確認** | <code>show lldp neighbors</code> |

---

## 1.1.b (ii) UDLD

### 📘 概要

**UDLD (UniDirectional Link Detection):** 光ファイバやツイストペアケーブル上の物理的な単方向リンクを検出し、スパニングツリーのループ発生などのレイヤ2障害を防止するシスコ独自のプロトコルです。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **動作モード** | **通常 (Normal):** 検知しても通知のみ。 **アグレッシブ (Aggressive):** 対向からの応答が途切れた場合にポートを **err-disable** にする。 |
| **検出対象** | 物理的な配線ミス（ファイバの交差）、片方向の信号途絶、インターフェイスのハングアップなど。 |
| **動作レイヤ** | レイヤ2（キープアライブパケットを定期的に交換）。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **ループ防止:** STPの Loop Guard と UDLD の違いを理解しておくこと。UDLDは物理的な単方向性を、Loop Guardはソフトウェア的なBPDUの途絶を監視します。
*   **Errdisable リカバリ:** UDLDによって無効化されたポートを自動復旧させる `errdisable recovery cause udld` との組み合わせがラボ試験で問われる可能性があります。
*   **光インターフェイス:** デフォルトでは光ファイバポートのみグローバル設定で有効化されることが多いため、銅線ポートでの個別設定 (`udld port`) が必要になる場合があります。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **グローバルでの有効化（光ポートのみ）** | <code>udld {enable&#124;aggressive}</code> |
| **インターフェイスでの個別有効化** | <code>udld port [aggressive]</code> |
| **UDLDステータスの確認** | <code>show udld [interface-id]</code> |
| **隣接関係の確認** | <code>show udld neighbors</code> |
| **UDLDによる遮断ポートの再起動** | <code>udld reset</code> |
| **UDLDによるerrdisableの自動復旧設定** | <code>errdisable recovery cause udld</code> |

---

## 参考リソースリンク

### Configurationガイド

*   [Configuring the Cisco Discovery Protocol (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/nm/b_179_nm_9300_cg/m_nm_cdp.html)
*   [Configuring UniDirectional Link Detection (UDLD)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/configuring_udld.html)

### CiscoLive (動画・スライド)

*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKENS-2031: Enterprise Campus Design](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)

## 📝 補足
- 補足情報をここに追加してください。

