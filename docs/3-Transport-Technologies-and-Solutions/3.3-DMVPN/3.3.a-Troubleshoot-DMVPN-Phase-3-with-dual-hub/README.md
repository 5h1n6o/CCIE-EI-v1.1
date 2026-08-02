---
layout: default
title: 3.3.a-Troubleshoot-DMVPN-Phase-3-with-dual-hub
parent: 3.3-DMVPN
grand_parent: 3-Transport-Technologies-and-Solutions
nav_order: 1
---

# 3.3.a Troubleshoot DMVPN Phase 3 with Dual Hub

DMVPN (Dynamic Multipoint VPN) は、mGRE、NHRP、および IPsec を組み合わせて、ハブ・アンド・スポーク型またはスポーク・アンド・スポーク型の動的なフルメッシュ接続を構築する技術です。CCIE EI v1.1 において、特に Phase 3 のデュアルハブ構成は、スケーラビリティと冗長性を両立させる高度なトピックであり、トラブルシューティング能力が厳しく問われます。

---

## 📘 概要

**DMVPN Phase 3** は、Phase 2 の「Spoke 間での直接通信」をさらに進化させたものです。最大の技術的特徴は、ハブによる **NHRP Redirect** と、スポークによる **NHRP Shortcut** メカニズムにあります。

*   **ハブの役割:** トラフィックが自身を経由した際、より最適な（スポーク間直接の）パスが存在することを検知し、送信元スポークへ Redirect メッセージを送ります。
*   **スポークの役割:** Redirect を受信すると、宛先へのショートカットパスを解決するために NHRP Resolution Request を送信し、ルーティングテーブルのネクストホップを動的に書き換えます。
*   **デュアルハブ構成:** 2台のハブ（NHS: Next Hop Server）を配置することで、ハブ自体の障害に対する冗長性と、負荷分散を実現します。

---

## 🔑 要点

### 1. NHRP (Next Hop Resolution Protocol) (i)

NHRP は DMVPN の「住所録」の役割を果たします。
*   **NHS (Next Hop Server):** 通常はハブ。スポークの論理アドレス（Tunnel IP）と物理アドレス（NBMA IP）のマッピングを保持します。
*   **NHRP Redirect:** ハブのインターフェイスで `ip nhrp redirect` が設定されている必要があります。
*   **NHRP Shortcut:** スポークのインターフェイスで `ip nhrp shortcut` が設定されている必要があります。
*   **NHRP Authentication:** ハブとスポーク間で一致させる必要があります。

### 2. IPsec/IKEv2 using Preshared Key (ii)

DMVPN のデータプレーンを保護するため、IKEv2 を使用した高度な暗号化が推奨されます。
*   **IKEv2 Keyring:** 送信元 IP（0.0.0.0 など）に基づいて共有キー（PSK）を定義します。
*   **IKEv2 Profile:** Keyring と Identity を紐付け、ISAKMP ポリシーよりも柔軟な制御を可能にします。
*   **IPsec Profile:** トランスフォームセットを適用し、GRE トンネルを保護（Protection）します。

### 3. デュアルハブ・デュアルクラウドの設計

*   **Single Cloud:** 2台のハブが同一の Tunnel サブネットを共有します。
*   **Dual Cloud:** ハブごとに異なる Tunnel サブネットと異なるトンネルインターフェイスを持ち、スポークはそれぞれのハブに対して個別のトンネルを張ります。

---

## 🎯 試験対策 (CCIE EIレベル)

ラボ試験では、意図的に仕込まれた「不整合」を特定し、Phase 3 のショートカットが形成されない原因を解決する能力が求められます。

### 1. ルーティングプロトコルとネクストホップの罠

*   **EIGRP:** ハブで `no ip next-hop-self` を設定し、スポークに元の送信元スポークのネクストホップを伝えようとするのは Phase 2 の手法です。Phase 3 では、ハブは **自分自身をネクストホップとして広告** し、その後の NHRP Redirect でネクストホップを上書きさせます。
*   **OSPF:** ネットワークタイプが `broadcast` の場合、ハブが DR になるよう優先度を調整する必要があります。Phase 3 では `point-to-multipoint` を使用するのが一般的です。

### 2. NHRP Redirect/Shortcut の欠落

*   **症状:** スポーク間の疎通は取れるが、常にハブを経由（Traceroute で確認）してしまう。
*   **原因:** ハブでの `ip nhrp redirect` またはスポークでの `ip nhrp shortcut` の設定漏れ。

### 3. IKEv2 プロポーザルのミスマッチ

*   暗号化アルゴリズム（AES vs 3DES）やハッシュ方式（SHA256 vs MD5）の不一致により、ISAKMP セッションが確立されません。`show crypto ikev2 sa` で状態を確認するスキルが必須です。

### 4. MTU とフラグメンテーション

*   GRE (24byte) + IPsec (約50byte以上) のオーバーヘッドにより、パケットドロップが発生します。`ip mtu 1400` および `ip tcp adjust-mss 1360` の適切な設定が問われます。

---

## 🛠 設定・検証コマンド

### NHRP & トンネル設定

| 目的 | コマンド |
| :--- | :--- |
| **ハブ：Redirect 有効化** | <code>(config-if)# ip nhrp redirect</code> |
| **スポーク：Shortcut 有効化** | <code>(config-if)# ip nhrp shortcut</code> |
| **スポーク：NHS 登録** | <code>(config-if)# ip nhrp nhs [NHS_IP] nbma [NBMA_IP] mult</code> |
| **NHRP 認証設定** | <code>(config-if)# ip nhrp authentication [STRING]</code> |

### IKEv2 / IPsec 設定

| 目的 | コマンド |
| :--- | :--- |
| **IKEv2 Keyring 作成** | <code>crypto ikev2 keyring [NAME]</code> <br> <code>peer [ANY] address 0.0.0.0 0.0.0.0</code> <br> <code>pre-shared-key [KEY]</code> |
| **IKEv2 Profile 作成** | <code>crypto ikev2 profile [NAME]</code> <br> <code>match identity remote address 0.0.0.0</code> <br> <code>authentication remote pre-share</code> <br> <code>keyring local [NAME]</code> |
| **IPsec Profile 適用** | <code>(config-if)# tunnel protection ipsec profile [NAME]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **DMVPN 全体状態確認** | <code>show dmvpn [detail]</code> |
| **NHRP キャッシュ確認** | <code>show ip nhrp [brief]</code> |
| **IKEv2 セッション確認** | <code>show crypto ikev2 sa</code> |
| **IPsec トンネル通信確認** | <code>show crypto ipsec sa</code> |
| **ショートカットルート確認** | <code>show ip route next-hop-override</code> |
| **NHRP パケットのデバッグ** | <code>debug nhrp [condition]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. Phase 3 最小構成（ハブ側）

**【問題】** ハブ R1 において、スポークからのトラフィックを直接通信へ誘導するための Redirect 機能を有効にせよ。
```ios
interface Tunnel0
 ip nhrp redirect
```

---

### 2. Phase 3 最小構成（スポーク側）

**【問題】** スポーク R2 において、ハブからの Redirect を受け取り、ショートカットパスを形成するようにせよ。
```ios
interface Tunnel0
 ip nhrp shortcut
```

---

### 3. デュアルハブ NHS 冗長化

**【問題】** スポークから 2 台のハブ（R1: 10.1.1.1, R3: 10.1.1.3）を NHS として登録し、両方にマルチキャストを許可せよ。
```ios
interface Tunnel0
 ip nhrp nhs 10.1.1.1 nbma 172.16.1.1 multicast
 ip nhrp nhs 10.1.1.3 nbma 172.16.1.3 multicast
```

---

### 4. NHRP 認証不一致の修正

**【問題】** NHRP 認証文字列を "DMVPN_KEY" に統一し、ネイバーが正常に登録されるようにせよ。
```ios
! 全ルータ共通
interface Tunnel0
 ip nhrp authentication DMVPN_KEY
```

---

### 5. IKEv2 Keyring とワイルドカード PSK

**【問題】** あらゆるスポークからの接続を許可するため、全ルータで IKEv2 Keyring を構成せよ。パスワードは "CISCO" とする。
```ios
crypto ikev2 keyring K-RING
 peer ALL_SPOKES
  address 0.0.0.0 0.0.0.0
  pre-shared-key CISCO
```

---

### 6. EIGRP スプリットホライゾンの無効化

**【問題】** ハブにおいて、スポーク A から受信したルートをスポーク B へ転送できるよう設定せよ。
```ios
interface Tunnel0
 no ip split-horizon eigrp 100
```

---

### 7. OSPF ネットワークタイプの最適化

**【問題】** タイマー変更なしで Phase 3 の動作を安定させるため、OSPF ネットワークタイプを Point-to-Multipoint に変更せよ。
```ios
interface Tunnel0
 ip ospf network point-to-multipoint
```

---

### 8. MTU 不整合による TCP 通信不可の解決

**【問題】** トンネルを通過する HTTP トラフィックがドロップする。MSS を適切に調整せよ。
```ios
interface Tunnel0
 ip mtu 1400
 ip tcp adjust-mss 1360
```

---

### 9. ショートカットパスの強制解除

**【問題】** NHRP キャッシュを手動でクリアし、Redirect プロセスを最初から再試行させよ。
```ios
clear ip nhrp
! または特定エントリのみ
clear ip nhrp 10.2.2.2
```

---

### 10. NHS クラスタリングによる負荷分散

**【問題】** 複数のハブが存在する環境で、特定のスポークが優先的に R1 を NHS として使用するようにせよ。
```ios
! スポーク側で優先度(priority)を調整する場合
interface Tunnel0
 ip nhrp nhs 10.1.1.1 priority 10
 ip nhrp nhs 10.1.1.3 priority 20
```

---

### 11. IKEv2 Identity Mismatch のトラブルシュート

**【問題】** Identity に Hostname を使用している場合に通信ができない。Address に基づく照合に修正せよ。
```ios
crypto ikev2 profile P-V2
 match identity remote address 0.0.0.0
```

---

### 12. IPsec Transform-set の検証

**【問題】** 暗号化強度の要件に基づき、AES-256 と SHA256 を使用したセットに更新せよ。
```ios
crypto ipsec transform-set T-SET esp-aes 256 esp-sha256-hmac
 mode transport
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKSEC-3052: Demystifying DMVPN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-3052)
    *   DMVPN Phase 1, 2, 3 の動作ロジックの決定版解説。
*   [**BRKRST-3320: Troubleshooting IP Routing**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
    *   DMVPN 上での再帰ルーティング問題のトラブルシュート。

### Configuration ガイド
*   [**Dynamic Multipoint VPN (DMVPN) Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_conn_dmvpn/configuration/xe-17/sec-conn-dmvpn-xe-17-book.html)。
*   [**Cisco IKEv2 Services Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_conn_ikevpn/configuration/xe-17/sec-conn-ikevpn-xe-17-book.html)。

### テクニカルノーツ・設定例
*   [**DMVPN Phase 3 NHRP Redirect and Shortcut (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/security-software/dynamic-multipoint-vpn-dmvpn/111380-dmvpn-phase3-00.html)。
*   [**Common DMVPN Troubleshooting Issues**](https://www.cisco.com/c/en/us/support/docs/security-software/dynamic-multipoint-vpn-dmvpn/118370-technote-gre-00.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において「なぜスポーク間が直接繋がらないのか」を NHRP の Redirect/Shortcut 階層と IPsec IKEv2 の認証階層から切り分けるための強力な指針となります。特に **ハブでの `no ip next-hop-self` が Phase 3 では不要（むしろハブをネクストホップにするのが標準）** であるという理論的転換を完璧に理解しておくことが合格への鍵です。
