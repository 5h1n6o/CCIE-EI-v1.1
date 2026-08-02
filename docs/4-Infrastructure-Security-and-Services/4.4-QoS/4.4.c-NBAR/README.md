---
layout: default
title: 4.4.c-NBAR
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.4.c Network Based Application Recognition (NBAR)

この学習メモでは、Cisco IOS XE における高度なトラフィック分類技術である **NBAR (Network Based Application Recognition)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき、理論、実装、およびラボ試験対策を詳細に解説します。

---

## 📘 概要

**NBAR (Network Based Application Recognition)** は、シスコのルータがパケットのペイロード（レイヤ4からレイヤ7）を深く検査し、動的なポート番号を使用するアプリケーションや、プロトコル内の特定の属性（HTTPのURLやホスト名など）を識別するための高度な分類エンジンです。

従来のアクセスコントロールリスト（ACL）が静的なIPアドレスやポート番号に依存していたのに対し、NBARは「パケットが何であるか」をその中身から判断します。現在の主流は **NBAR2 (Next-Generation NBAR)** であり、アプリケーションの「シグネチャ」を管理する **Protocol Pack** を使用することで、IOS XEのイメージを更新することなく、新しいアプリケーションやプロトコルの変更に対応できる拡張性を備えています。

NBARは単独で動作するだけでなく、**MQC (Modular QoS CLI)** フレームワークと統合され、分類（Classification）、マーキング（Marking）、ポリシング（Policing）などのQoSアクションのトリガーとして機能します。

---

## 🔑 要点

### 1. ディープパケットインスペクション (DPI)

NBARはパケットのデータ部分をスキャンします。これにより、同じTCPポート80（HTTP）を使用していても、Web閲覧トラフィック、動画ストリーミング（YouTube）、ソーシャルメディア（Facebook）などを個別に識別できます。

### 2. NBAR2 と Protocol Pack

*   **NBAR2:** パフォーマンスと識別精度が向上した次世代エンジンです。
*   **Protocol Pack:** アプリケーションシグネチャの集合体です。これを個別にロードすることで、最新のアプリケーション（Zoom, Teams等）を識別可能にします。

### 3. NBAR Protocol Discovery

特定のインターフェイスを通過するトラフィックの種類と量をリアルタイムで分析・統計する機能です。QoSポリシーを適用する前に、「どのようなトラフィックが、どれくらい流れているか」を把握するために不可欠です。

### 4. 属性ベースの分類 (Attribute-based Classification)

NBAR2では、個々のプロトコル名だけでなく、「カテゴリー（Category）」「サブカテゴリー（Sub-category）」「特性（Attributes）」に基づいたグループ化が可能です。
*   **カテゴリー例:** Network-service, Client-server, P2P。
*   **属性例:** 暗号化の有無（Encrypted-no/yes）、ビジネスへの関連度など。

### 5. マッチング条件の柔軟性

MQCの `class-map` 内で、以下の条件を NBAR を介して指定できます。
*   `match protocol [Protocol_Name]`
*   `match protocol http url [URL_String]`
*   `match protocol http host [Host_Name]`
*   `match protocol attribute [Attribute_Name]`

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純なアプリケーション識別だけでなく、複雑な条件指定やリソース保護、SD-WANとの連携が問われます。

### 1. HTTP URL/Host マッチングの精度

「特定のURL（例: `*.gif` や `*.jpg`）を含むHTTPトラフィックのみを制限せよ」といったタスクが出題されます。この際、ワイルドカード（`*`）の使い所や、正規表現の構文を正確に記述できる必要があります。

### 2. NBAR Protocol Discovery の IPv4/IPv6 両対応

ラボの要件で「IPv4とIPv6の両方のトラフィック統計を取得せよ」と指定されることがあります。デフォルトの設定で両方のプロトコルがカウントされているかを確認し、`show ip nbar protocol-discovery` 等のコマンドで詳細を確認する習慣が重要です。

### 3. パフォーマンスへの影響

DPIはCPUに負荷をかけるため、試験では「必要最小限のインターフェイス」に適用する、あるいは「特定の方向（Input/Output）」に限定するといった、最適化の視点が求められることがあります。

### 4. 暗号化トラフィック（HTTPS）の扱い

NBARはSSL/TLSの **SNI (Server Name Indication)** フィールドを読み取ってアプリケーションを識別できます。完全に暗号化された中身は見えませんが、接続先のドメイン名に基づいた制御が可能である点を理解しておく必要があります。

### 5. カスタムプロトコルの定義

標準のシグネチャにない独自の社内アプリ等を `ip nbar custom` コマンドで定義し、特定のポート範囲やペイロードのパターンで識別させるタスクも CCIE レベルでは想定されます。

---

## 🛠 設定・検証コマンド

### NBAR 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **IFでの統計収集有効化** | <code>(config-if)# ip nbar protocol-discovery</code> |
| **クラスマップでのプロトコル指定** | <code>(config-cmap)# match protocol [protocol]</code> |
| **クラスマップでのURL指定** | <code>(config-cmap)# match protocol http url "[URL]"</code> |
| **属性による一括マッチング** | <code>(config-cmap)# match protocol attribute [attribute-category] [value]</code> |
| **カスタムプロトコルの定義** | <code>(config)# ip nbar custom [NAME] [TCP&#124;UDP] [PORT]</code> |

### 検証・統計確認コマンド

| 目的 | コマンド |
| :--- | :--- |
| **リアルタイム統計の表示** | <code>show ip nbar protocol-discovery [interface]</code> |
| **カテゴリー別のプロトコル一覧表示** | <code>show ip nbar attribute category [CATEGORY_NAME]</code> |
| **プロトコルパックのバージョン確認** | <code>show ip nbar version</code> |
| **現在識別可能なプロトコル一覧** | <code>show ip nbar protocol-id</code> |
| **QoSポリシー内でのヒット数確認** | <code>show policy-map interface [INTERFACE]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 特定の画像ファイルダウンロードの制限

**【要件】** HTTP でダウンロードされる `.gif` または `.jpg` ファイルのトラフィックを 100 kbps に制限せよ。
```ios
class-map match-any CM-HTTP-IMAGES
 match protocol http url "*.gif"
 match protocol http url "*.jpg"
!
policy-map PM-LIMIT-IMAGE
 class CM-HTTP-IMAGES
  police 100000
!
interface GigabitEthernet1
 service-policy output PM-LIMIT-IMAGE
```

---

### 2. インターフェイスでのプロトコル可視化

**【要件】** R9 の Ethernet0/0 インターフェイスで、IPv4 および IPv6 トラフィックのアプリケーション統計を有効にせよ。
```ios
interface Ethernet0/0
 ip nbar protocol-discovery
!
! 検証コマンド
# show ip nbar protocol-discovery interface Ethernet0/0
```

---

### 3. P2P トラフィックの一括マーキング

**【要件】** 暗号化されていない P2P テクノロジーを使用する全アプリを識別し、DSCP CS1 を付与せよ。
```ios
class-map match-all CM-P2P-CLEAR
 match protocol attribute p2p-technology p2p-tech-yes
 match protocol attribute encrypted encrypted-no
!
policy-map PM-MARK-P2P
 class CM-P2P-CLEAR
  set ip dscp cs1
```

---

### 4. 特定のビジネスアプリ（Lotus Notes）のシェーピング

**【要件】** NBAR を用いて Lotus Notes トラフィックを識別し、512 kbps にシェーピングせよ。
```ios
class-map match-any CM-LOTUS
 match protocol notes
!
policy-map PM-SERIAL-QOS
 class CM-LOTUS
  shape average 512000
```

---

### 5. HTTP ホスト名に基づく優先制御

**【要件】** `www.cisco.com` へのアクセスを最優先クラス（LLQ）として処理せよ。
```ios
class-map match-all CM-CISCO-WEB
 match protocol http host "www.cisco.com"
!
policy-map PM-PRIORITY
 class CM-CISCO-WEB
  priority percent 10
```

---

### 6. IPv6 環境における NBAR 統計

**【要件】** IPv6 トラフィックのみの統計情報を個別に確認せよ。
```ios
! 設定は共通
interface Gi1
 ip nbar protocol-discovery
!
! 検証（IPv6のみフィルタリングして表示）
# show ip nbar protocol-discovery stats ipv6
```

---

### 7. カスタムプロトコルの作成

**【要件】** TCP ポート 9999 を使用する社内アプリを `MY_APP` として定義せよ。
```ios
ip nbar custom MY_APP tcp 9999
!
class-map CM-CUSTOM-APP
 match protocol MY_APP
```

---

### 8. カテゴリーベースの Web アプリ一括ドロップ

**【要件】** 「Social-Networking」カテゴリーに属するすべての Web サービスを拒否せよ。
```ios
class-map match-all CM-SOCIAL
 match protocol attribute category social-networking
!
policy-map PM-BLOCK-SOCIAL
 class CM-SOCIAL
  drop
```

---

### 9. NBAR2 属性の確認

**【要件】** システムで「VoIP」カテゴリーとして定義されているプロトコルの一覧を確認せよ。
```ios
# show ip nbar attribute category voice-and-video
! 期待される出力: rtp, skype, sip 等が表示される
```

---

### 10. プロトコルパックのアップロード

**【要件】** フラッシュ上の `nbar-pp-17.x.pkg` を読み込み、最新のシグネチャを適用せよ。
```ios
ip nbar protocol-pack flash:nbar-pp-17.x.pkg
!
! 検証
show ip nbar version
```

---

### 11. MIME タイプに基づくメール添付ファイルの制御

**【要件】** HTTP 通信内の「MIMEタイプ（application/pdf）」を識別し、制御せよ。
```ios
class-map CM-PDF-DOCS
 match protocol http mime "application/pdf"
```

---

### 12. 非優先トラフィック（Scavenger）のマーキング

**【要件】** `match-not` を使用し、重要プロトコル（SSH, OSPF）以外の全 NBAR 識別トラフィックを DSCP CS1 にせよ。
```ios
class-map match-any CM-IMPORTANT
 match protocol ssh
 match protocol ospf
!
policy-map PM-SCAVENGER
 class CM-IMPORTANT
  set ip dscp af41
 class class-default
  set ip dscp cs1
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and IOS XE**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
    *   最新の NBAR2 実装とハードウェアアクセラレーションの解説。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
    *   エンタープライズキャンパスでの NBAR による分類設計。

### Configuration ガイド
*   [**Configuring NBAR-Based Classification (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)。
*   [**NBAR2 Protocol Pack Release Notes**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/prot_lib/nbar-prot-pack-library.html)。

### テクニカルドキュメント・設定例
*   [**NBAR2 Attributes and Category Definitions**](https://www.cisco.com/c/en/us/products/collateral/ios-nx-os-software/network-based-application-recognition-nbar/qa_c67-697963.html)。
*   [**Advanced MQC NBAR2 Classification Examples**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において「見えないトラフィックをいかに可視化し、制御するか」という課題に対する強力な指針となります。ラボでは、**`show ip nbar protocol-discovery`** を活用してトラフィックの現状を正しく把握し、要件に合わせた **`match protocol`** を柔軟に使い分けることが合格への鍵です。

