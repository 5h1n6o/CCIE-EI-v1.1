---
layout: default
title: 4.5.b-Time-sync
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.5.b 時刻同期プロトコル

ネットワークインフラにおける時刻同期は、ログの正確な相関分析、デジタル証明書の有効性検証、およびプロトコルの安定動作において不可欠な要素です。CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲では、従来の **NTP (Network Time Protocol)** のクライアント実装に加え、より高精度な **PTP (Precision Time Protocol)** の設計上の考慮事項が問われます。

---

## 📘 概要

### NTP (Network Time Protocol)

NTP は、階層的な階層構造（Stratum）を使用して、ネットワーク上のデバイス間で時刻を同期させるプロトコルです。UDP ポート 123 を使用し、パケット交換の往復遅延を計算して誤差を補正します。
*   **クライアント/サーバーモデル:** クライアントがサーバーに時刻を要求し、同期します。
*   **ピアモデル:** 相互に時刻を比較し、より正確な側に同期します。

### PTP (Precision Time Protocol)

IEEE 1588 に基づく PTP は、マイクロ秒からナノ秒単位の極めて高い精度を提供します。主に放送、金融、電力網などの特殊な要件を持つ環境で使用されますが、現代のエンタープライズネットワークでも特定のアプリケーションや IoT デバイスの同期に採用されています。PTP はハードウェアによるタイムスタンプ付与を利用して、OS やソフトウェアの処理遅延を排除します。

---

## 🔑 要点

### 1. NTP クライアントの要件と動作 (i)

*   **Stratum（ストラタム）:** 時刻源からの距離を示す数値です。Stratum 1 は原子時計に直接接続されたサーバーであり、数値が大きくなるほど精度が低下する可能性があります。
*   **アソシエーションの種類:** `ntp server`（単方向同期）、`ntp peer`（双方向同期）、`ntp broadcast client`（受信専用）などが存在します。
*   **同期の優先順位:** `prefer` キーワードを使用して、複数のサーバーがある場合に優先するパスを指定できます。
*   **セキュリティ:** MD5 認証を使用して時刻情報の改ざんを防止し、`access-group` を使用してルータへの NTP アクセスを制御します。

### 2. PTP 設計上の考慮事項 (ii)

*   **クロックの役割:**
    *   **Grandmaster (GM):** ネットワーク全体のプライマリ時刻源。
    *   **Boundary Clock (BC):** ルータやスイッチが PTP クライアントとして受信し、別のポートからサーバーとして再配布することで、ホップごとのジッターを排除します。
    *   **Transparent Clock (TC):** パケットがスイッチを通過する際の滞在時間を計算し、PTP メッセージを補正します。
*   **トランスポート:** IPv4、IPv6、または直接 Ethernet レイヤ 2 で動作可能です。
*   **同期精度:** ネットワーク内のすべてのホップが PTP に対応している必要があります。非対応デバイスが混在すると精度が著しく低下します。

---

## 🎯 試験対策 (CCIE EIレベル)

### 1. セキュアな時刻同期の設計

ラボ試験では、単に `ntp server` を設定するだけでなく、管理プレーンの保護が求められます。
*   **アクセス制御:** `ntp access-group` コマンドを使用して、時刻の同期を許可するピアや、自身の時刻情報を要求できるクライアントを ACL で制限する設定が頻出します。
*   **認証の整合性:** `ntp trusted-key` が正しく構成されていないと、認証が有効になりません。

### 2. IPv6 環境での NTPv4

Blueprint 1.1 では IPv6 が重視されています。NTPv4 を使用して IPv6 ユニキャストアドレス経由で同期を行う手順を確認してください。

### 3. PTP の適用シナリオ

PTP に関しては「どのような場合に PTP が必要か」という設計的な視点が重要です。
*   **BC vs TC:** 多くのポートを持つ大規模な配信環境では Boundary Clock が推奨され、ネットワーク経路の遅延変動を最小限に抑える必要がある場合は Transparent Clock が適しています。

### 4. トラブルシューティングの検証指標

*   `show ntp status` で「Clock is synchronized」になっているか。
*   `show ntp associations detail` で `offset`（誤差）や `dispersion`（分散）が許容範囲内かを確認します。

---

## 🛠 設定・検証コマンド

### NTP クライアント設定

| 目的 | コマンド |
| :--- | :--- |
| **時刻同期サーバーの指定** | <code>ntp server [IP_ADDRESS] version [prefer]</code> |
| **同期元インターフェイスの固定** | <code>ntp source [INTERFACE]</code> |
| **NTP 認証キーの定義** | <code>ntp authentication-key [ID] md5 [KEY_STRING]</code> |
| **信頼済みキーの指定** | <code>ntp trusted-key [ID]</code> |
| **サーバーとの認証有効化** | <code>ntp server [IP] key [ID]</code> |
| **アクセス制限の適用** | <code>ntp access-group [peer&#124;serve&#124;query-only] [ACL]</code> |

### PTP 設定

| 目的 | コマンド |
| :--- | :--- |
| **PTP モードの指定** | <code>ptp mode [boundary-clock&#124;e2etransparent]</code> |
| **インターフェイスでの有効化** | <code>(config-if)# ptp enable</code> |
| **PTP ドメインの設定** | <code>ptp domain</code> |

### 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **同期状態のサマリ確認** | <code>show ntp status</code> |
| **ピア/サーバーとの詳細状態** | <code>show ntp associations [detail]</code> |
| **NTP パケット統計の表示** | <code>show ntp packets</code> |
| **PTP 状態の確認** | <code>show ptp brief</code> |
| **現在のシステム時刻表示** | <code>show clock [detail]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な NTP クライアント設定 (優先度付き)

**【要件】** 2 台のサーバー (10.1.1.1, 10.1.1.2) を指定し、1 台目を優先せよ。
```ios
ntp server 10.1.1.1 prefer
ntp server 10.1.1.2
```

### 2. ソースインターフェイスの固定

**【要件】** NTP パケットの送信元 IP アドレスを Loopback 0 に固定せよ。
```ios
ntp source Loopback0
```

### 3. NTP 認証の実装

**【要件】** キー ID 10、パスワード "ccie_key" で MD5 認証を構成せよ。
```ios
ntp authenticate
ntp authentication-key 10 md5 ccie_key
ntp trusted-key 10
ntp server 10.1.1.1 key 10
```

### 4. ACL による NTP アクセス制限

**【要件】** 172.16.1.0/24 のセグメントのみに同期を許可せよ。
```ios
access-list 10 permit 172.16.1.0 0.0.0.255
ntp access-group peer 10
```

### 5. IPv6 NTP クライアントの構成

**【要件】** IPv6 アドレス (2001:DB8::1) のサーバーと同期せよ。
```ios
ntp server 2001:DB8::1
```

### 6. NTP ピアリング (対称アクティブモード)

**【要件】** R1 と R2 で相互に時刻を比較し合うように設定せよ。
```ios
! R1 側
ntp peer 10.2.2.2
```

### 7. Stratum 値の手動変更 (マスター設定)

**【要件】** 外部同期が取れない場合に、自身を Stratum 5 の時刻源として動作させよ。
```ios
ntp master 5
```

### 8. PTP Boundary Clock の有効化

**【要件】** デバイスを PTP 境界クロックとして動作させ、Gi0/1 で有効化せよ。
```ios
ptp mode boundary-clock
!
interface GigabitEthernet0/1
 ptp enable
```

### 9. NTP バージョンの明示指定

**【要件】** 古いシステムとの互換性のため NTP version 2 を使用せよ。
```ios
ntp server 10.5.5.5 version 2
```

### 10. タイムゾーンと夏時間の設定

**【要件】** 日本標準時 (JST) を設定せよ。
```ios
clock timezone JST 9 0
```

### 11. NTP ステータスの詳細検証

**【操作例】** 同期が完了しているか、分散（dispersion）が大きすぎないかを確認する。
```ios
show ntp associations detail
! "synced", "master" などのフラグを確認
```

### 12. ログへの正確な時刻付与

**【要件】** ログメッセージにミリ秒単位のタイムスタンプを含めよ。
```ios
service timestamps log datetime msec
```

---

## 📘 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRS-2031: Network Time Protocol (NTP) Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031) - NTP の詳細な仕組みと攻撃対策。
*   [**BRKARC-2011: Precision Time Protocol (PTP) in Enterprise Networks**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-2011) - PTP の設計と実装ガイド。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Network Time Protocol Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/bsm/configuration/xe-17/bsm-xe-17-book.html)。
*   [**Configuring Precision Time Protocol (PTP)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg/m_ptp.html)。

### テクニカルドキュメント・設定例
*   [**NTP Best Practices White Paper**](https://www.cisco.com/c/en/us/support/docs/availability/high-availability/19643-ntp.html) - 階層設計とセキュリティの推奨事項。
*   [**Troubleshooting NTP Sync Issues (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13506-snmpv3.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験において正確な時刻同期がいかに基盤技術として重要であるかを網羅しています。特に **NTP 認証** と **アクセスグループによる制限** は、セキュリティセクションと組み合わせて出題される可能性が高いため、確実にマスターしてください。


