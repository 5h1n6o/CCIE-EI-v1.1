# 1.2.i Routing protocol authentication

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験において、コントロールプレーンセキュリティ（Control Plane Security）の第一防衛線となる **Routing Protocol Authentication（ルーティングプロトコル認証：EIGRP, OSPFv2/v3, BGP, RIPv2）** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**ルーティングプロトコル認証（Routing Protocol Authentication）** とは、隣接ルータ間で交換されるルーティング更新パケット（Hello, Update, LSU, Keepalive等）の送信元身元（Identity）を特定し、パケット改ざんや不法なネイバー確立、偽経路の注入（Route Injection / Poisoning）を防ぐための暗号化・認証メカニズムです。

コントロールプレーンが改ざんされた場合、Man-in-the-Middle（中間者）攻撃、ブラックホール化、トラフィックの盗聴、DoS（Service Denial）など、インフラ全体を揺るがす重大な脅威に直面します。そのため、ルータ間の相互信頼関係を確立するルーティングプロトコル認証は、ネットワーク設計および運用において必須の基本セキュリティコンポーネントです。

### 主なプロトコルとサポートされる認証方式
1. **EIGRP (Classic / Named Mode):**
   * **Classic Mode:** MD5 認証（`key-chain` 必須）。
   * **Named Mode:** MD5 認証に加え、**HMAC-SHA-256** 認証（`key-chain` または直接パスワード指定）をサポート。
2. **OSPFv2 (IPv4):**
   * Plaintext (Type 1: 平文)
   * MD5 (Type 2: メッセージダイジェスト)
   * **HMAC-SHA-1 / HMAC-SHA-256 / HMAC-SHA-384 / HMAC-SHA-512 (RFC 5709):** 暗号化アルゴリズムの強度を高めた仕様。
3. **OSPFv3 (IPv6 / Multi-AF):**
   * **IPsec (AH / ESP) 方式 (RFC 4552):** OSPFv3 ヘッダー自体の認証フィールドを排除し、IPv6 ネイティブの IPsec 拡張ヘッダーを利用。
   * **OSPFv3 Trailer Authentication (RFC 7166):** OSPFv3 パケットの末尾に認証用 AP (Authentication Trailer) を付与し、`key-chain` / HMAC-SHA-256 等を使用。
4. **BGP (Border Gateway Protocol):**
   * **TCP MD5 Signature (RFC 2385):** TCP 3-way ハンドシェイクおよび以降の TCP セグメント（Option 19）に MD5 ダイジェストを埋め込み。
   * **TCP Authentication Option (TCP-AO - RFC 5925):** 鍵更新時のセッション瞬断を防ぐ、次世代 TCP 認証オプション。
5. **RIPv2:**
   * Plaintext / MD5 認証（`key-chain` 必須）。

---

## 🔑 要点

| 項目 | EIGRP | OSPFv2 | OSPFv3 | BGP |
| :--- | :--- | :--- | :--- | :--- |
| **サポート暗号化アルゴリズム** | MD5, HMAC-SHA-256 | Plaintext, MD5, HMAC-SHA-1/256/384/512 (RFC 5709) | IPsec (AH/ESP), HMAC-SHA-256 (Trailer - RFC 7166) | MD5 (TCP Option 19), TCP-AO (RFC 5925) |
| **認証キー適用範囲** | インターフェイス単位 / AF単位 | インターフェイス単位 / エリア単位 | インターフェイス単位 / エリア単位 | ピア（Neighbor）単位 |
| **鍵ローテーション (Key Chain)** | **必須 (Classic/Named MD5)** / オプション | サポート (`ip ospf message-digest-key` / Cryptographic) | サポート (`key-chain` / Trailer) | サポート (TCP-AO Key-Chain) |
| **ミッションクリティカル要件** | NTP 時刻同期による鍵切り替え (Hitless Key Rollover) | エリア単位の一括有効化とインターフェイス個別上書き | AH (改ざん防止) / ESP (暗号化) の選択 | TCP セッション生成時からの完全保護 |
| **Cisco IOS-XE 推奨** | Named Mode ＋ HMAC-SHA-256 | HMAC-SHA-256 (RFC 5709) | IPsec または Trailer SHA-256 | MD5 または TCP-AO |
| **注意点** | Key-Chain 内の `accept-lifetime` と `send-lifetime` の完全理解が必要 | Area 認証有効時、全ルータのキー指定漏れに注意 | IPsec SPI (Security Parameter Index) の一致が必須 | パスワード変更時は TCP セッションのクリア（リセット）が必要な場合あり |

---

## 🏗 動作原理

### 1. ダイジェスト生成と検証フロー（HMAC-SHA-256 / MD5共通）

ルーティングパケットの送受信時における認証ダイジェストの計算フローです。パケットのペイロード自体は暗号化されず平文のまま送信されますが（IPsec ESPを除く）、秘密鍵（Secret Key）を用いたハッシュ値が付与されることで改ざん・捏造を防止します。

```text
[ 送信ルータ (Router A) ]                                    [ 受信ルータ (Router B) ]
   │                                                             │
   ├─ 1. ルーティングパケット生成                                ├─ 4. パケット受信
   ├─ 2. パケット ＋ 秘密鍵 (Shared Key)                        ├─ 5. パケット ＋ 秘密鍵 (Shared Key)
   │     ↓                                                       │     ↓
   │  [ ハッシュ関数 (MD5/SHA-256) ]                             │  [ ハッシュ関数 (MD5/SHA-256) ]
   │     ↓                                                       │     ↓
   ├─ 3. 生成された Digest をパケット末尾/ヘッダーに挿入           ├─ 6. 計算ダイジェスト ＝ 受信ダイジェスト ?
   │                                                             │     ├── 一致 ➔ ネイバー処理 / パケット受理
   └─────── [ 認証付きパケット送信 (IP / TCP) ] ─────────────────┘     └── 不一致 ➔ パケット破棄 (Drop) & Logging
```

### 2. BGP TCP MD5 Signature (TCP Option 19) の構造
BGP は TCP ポート 179 を使用します。BGP 認証は、IP ペイロード上の BGP メッセージではなく、**TCP ヘッダーの Option 19 フィールド** に直接 MD5 ダイジェストを書き込みます。

```text
+-------------------+-------------------+------------------------+
|  IP Header        |  TCP Header       |  BGP Payload           |
|  (Src/Dst IP)     |  (Option 19: MD5) |  (OPEN, UPDATE, etc.)  |
+-------------------+-------------------+------------------------+
                             │
                             ▼
     TCP ヘッダー偽造防止、SYN 攻撃・セクションハイジャックから TCP 自体を防衛
```

---

## ⚙ 動作シーケンス

### Key Chain による無停止鍵ローテーション（Hitless Key Rollover）シーケンス

NTP で時刻同期されたルータ群において、鍵の有効期限（`send-lifetime` / `accept-lifetime`）を活用したキーローテーションの内部動作シーケンスです。

```text
[ タイムライン: Key 1 から Key 2 への移行 ]

時刻 T1: Key 1 のみ有効
  Router A (Key 1 Send/Accept)  ◄── (Key 1 で送信) ──►  Router B (Key 1 Send/Accept)
  * 両ルータが Key 1 でダイジェスト生成・一致確認。

時刻 T2 (移行オーバーラップ期間): 鍵変更過渡期
  Router A: Key 1 (Send/Accept), Key 2 (Accept Active)
  Router B: Key 1 (Send/Accept), Key 2 (Send Active / Accept Active)
  * Router B が Key 2 で送信開始しても、Router A は Key 2 を Accept 可能なためセッション切断ゼロ！

時刻 T3: 移行完了
  Router A (Key 2 Send/Accept)  ◄── (Key 2 で送信) ──►  Router B (Key 2 Send/Accept)
  * Key 1 の期限が切れ、完全・安全に Key 2 へ交代完了。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI 実技ラボ試験では、ルーティングプロトコル認証の単体設定だけでなく、**「プロトコルごとの構文の違い」「Key Chain のライフタイムオーバーラップ設定」「新規プロトコル（OSPFv3 IPsec / HMAC-SHA）の厳格なパラメーター合わせ」** が複雑な要件として出題されます。

### 1. EIGRP Named Mode における認証モード指定の罠
*   **出題条件:**
    「SW1 と SW2 間で EIGRP Autonomous System 100 を設定し、SHA-256 による認証を構成しなさい。キーチェーンは使用せず、直接インターフェイス配下でパスワード `CiscoCCIE2026` を指定すること」
*   **試験対策:**
    EIGRP Named Mode では、インターフェイス配下の `af-interface` モード内で認証を定義します。SHA-256 認証の場合、`key-chain` を使わずに直接キーを指定可能です。
    ```bash
    router eigrp CCIE
     address-family ipv4 autonomous-system 100
      af-interface GigabitEthernet1/0/1
       authentication mode hmac-sha-256 CiscoCCIE2026
      exit-af-interface
    ```
    *   **注意点:** MD5 認証の場合は `authentication mode md5` と `authentication key-chain <NAME>` の2行が必要ですが、`hmac-sha-256` の場合は直接パスワードを記述する記法が存在します。

### 2. OSPFv2 Area 認証とインターフェイス固有オーバーライド
*   **出題条件:**
    「OSPF Area 0 全体で MD5 認証を有効化しなさい。ただし、R1 と R2 の間の特定のリンク（`GigabitEthernet1/0/2`）のみ、Area 全体のデフォルトキーとは異なる専用キー `SecretKey99` (Key ID: 1) を使用して認証を確立せよ」
*   **試験対策:**
    *   `router ospf 1` 配下で `area 0 authentication message-digest` を設定します。
    *   対象インターフェイス配下で明示的に `ip ospf message-digest-key 1 md5 SecretKey99` を適用します。インターフェイス設定がエリア設定を優先（Override）します。

### 3. OSPFv3 IPsec AH / ESP 認証の必須パラメーター
*   **出題条件:**
    「OSPFv3（IPv6）ネイバーにおいて、IPsec AH (Authentication Header) を使用して安全にネイバーを確立しなさい。SPI 値は `1000`、認証アルゴリズムは SHA-1、キーは 40 文字の Hex 値 `1234567890123456789012345678901234567890` とすること」
*   **試験対策:**
    *   SPI (Security Parameter Index) は `256` 以上の数値である必要があります。
    *   SHA-1 の Hex キー長は正確に **40 文字 (160 ビット)** であることが求められます（MD5 は 32 文字）。長さが異なると CLI 入力が却下されます。
    ```bash
    interface GigabitEthernet1/0/1
     ospfv3 authentication ipsec spi 1000 ah sha1 1234567890123456789012345678901234567890
    ```

### 4. Key Chain ライフタイムの UTC / 時刻ローカル整合の注意点
*   **トラブル原因:**
    ルータ間で NTP が同期していない場合、`send-lifetime` の切り替え時刻の不一致により、片方のルータのみ新しいキーでパケットを送り始め、対向ルータがそれを不合格（Drop）としてネイバーが即座に切断（Down）します。
*   **対策:**
    `accept-lifetime` に**十分なオーバーラップバッファ時間（例: 前後に 30 分〜1 時間の猶予）** を持たせることが、実務および CCIE ラボ試験における鉄則です。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における各プロトコルの完全な認証構成コマンド例です。

### 1. Key-Chain (キーチェーン) 定義とライフタイム設定

```bash
# NTP同期を前提としたキーチェーンの作成
key chain ROUTING_KEYCHAIN
 key 1
  key-string PrimaryPass123
  accept-lifetime 00:00:00 Jan 1 2026 23:59:59 Dec 31 2026
  send-lifetime 00:00:00 Jan 1 2026 23:59:59 Dec 31 2026
 key 2
  key-string SecondaryPass456
  # 新しいキーの受信許可は30分前から受け入れる（オーバーラップ設計）
  accept-lifetime 23:30:00 Dec 31 2026 23:59:59 Dec 31 2027
  send-lifetime 00:00:00 Jan 1 2027 23:59:59 Dec 31 2027
```

### 2. EIGRP (Classic / Named Mode) 認証設定

```bash
# [A. EIGRP Classic Mode - MD5 キーチェーン認証]
interface GigabitEthernet1/0/1
 ip authentication mode eigrp 100 md5
 ip authentication key-chain eigrp 100 ROUTING_KEYCHAIN
exit

# [B. EIGRP Named Mode - HMAC-SHA-256 認証 (直接キー指定)]
router eigrp CCIE_DOMAIN
 address-family ipv4 autonomous-system 100
  af-interface GigabitEthernet1/0/1
   authentication mode hmac-sha-256 MyShaSecret256Bit
  exit-af-interface
```

### 3. OSPFv2 (IPv4) 認証設定 (MD5 / RFC 5709 HMAC-SHA-256)

```bash
# [A. OSPFv2 従来型 MD5 認証 (インターフェイス単位)]
interface GigabitEthernet1/0/1
 ip ospf message-digest-key 1 md5 CiscoMD5Key
 ip ospf authentication message-digest
exit

# [B. OSPFv2 RFC 5709 HMAC-SHA-256 暗号認証]
interface GigabitEthernet1/0/2
 ip ospf authentication cryptographic
 ip ospf message-digest-key 1 hmac-sha-256 MyOspfSha256Key
exit
```

### 4. OSPFv3 (IPv6) 認証設定 (IPsec AH / ESP & Trailer)

```bash
# [A. OSPFv3 IPsec AH 認証 (インターフェイス単位)]
interface GigabitEthernet1/0/1
 ospfv3 authentication ipsec spi 1000 ah sha1 1234567890123456789012345678901234567890
exit

# [B. OSPFv3 Trailer Authentication (RFC 7166 - Key-Chain 連携)]
interface GigabitEthernet1/0/2
 ospfv3 authentication key-chain ROUTING_KEYCHAIN
exit
```

### 5. BGP (TCP MD5 & TCP-AO) 認証設定

```bash
# [A. BGP 従来型 TCP MD5 認証]
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 password BGPSecretPassword123
exit

# [B. BGP 次世代 TCP-AO (TCP Authentication Option) 認証]
# 1. TCP-AO 用 key-chain 定義 (tcp-ao キーアルゴリズムを指定)
key chain TCP_AO_CHAIN-KEY
 key 1
  key-string AO_SecretPass789
  cryptographic-algorithm hmac-sha-1-96
  send-lifetime 00:00:00 Jan 1 2026 infinite
  accept-lifetime 00:00:00 Jan 1 2026 infinite

# 2. BGP ピアへの TCP-AO バインド
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 ao key-chain TCP_AO_CHAIN-KEY
exit
```

---

## 🔍 検証コマンド

認証の設定状態、ダイジェスト不一致エラー、パケットドロップ数を追跡するための検証コマンド体系です。

| 目的 | コマンド |
| :--- | :--- |
| **キーチェーンの動作状況、アクティブな Key ID、送信/受信ライフタイムの確認** | <code>show key chain</code> |
| **EIGRP インターフェイスごとの認証モードおよび Key-Chain バインド確認** | <code>show ip eigrp interfaces detail</code> |
| **OSPFv2 インターフェイスの認証タイプ（MD5/Cryptographic）、Key ID の確認** | <code>show ip ospf interface GigabitEthernet1/0/1</code> |
| **OSPFv3 IPsec SA (Security Association) の確立状態確認** | <code>show crypto ipsec sa</code> / <code>show ospfv3 interface</code> |
| **BGP ピアの TCP MD5 / TCP-AO 認証状態、MD5 パケットドロップ数確認** | <code>show ip bgp neighbors 10.1.12.2</code> |
| **EIGRP 認証失敗・ミスマッチイベントのリアルタイムデバッグ** | <code>debug eigrp packets retry auth</code> / <code>debug ip eigrp</code> |
| **OSPFv2 / OSPFv3 認証エラー・不整合パケットのデバッグ** | <code>debug ip ospf adj</code> / <code>debug ip ospf packet</code> / <code>debug ospfv3 adj</code> |
| **TCP レイヤでの MD5 / TCP-AO 認証ミスマッチのデバッグ** | <code>debug ip tcp transactions</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **EIGRP ネイバーが「Authentication failed」を繰り返してUPしない。** | 1. 送信側と受信側の `key-string`（文字・大文字小文字）が不一致。<br>2. ルータ間の時刻がずれており、有効な Key ID が存在しない。 | `show key chain`<br>`show clock`<br>`debug eigrp packets` | 1. パスワード文字列を両端で統一する。<br>2. NTP を同期させるか、`accept-lifetime` に時間的余裕を持たせる。 |
| **OSPFv2 エリア全体で認証を設定後、一部のルータが「`Mismatched Authentication Key`」を発出し、ネイバーが全断した。** | `area 0 authentication message-digest` を投入したが、**対象ルータの一部のインターフェイスで `ip ospf message-digest-key` の指定を忘れていた**。 | `show ip ospf interface`<br>`show logging` | 対象インターフェイスに正しい Key ID と MD5 パスワードを設定する。 |
| **OSPFv3（IPv6）で IPsec AH 認証を設定したが、ネイバーが INIT/DROPPED を繰り返す。** | 1. 両端で SPI (Security Parameter Index) の数値が異なっている。<br>2. SHA1 の Hex 文字列（40桁）の不一致。 | `show ospfv3 interface`<br>`show crypto ipsec sa` | 両ルータで SPI 値および 40桁の Hex キー文字列を完全に一致させる。 |
| **BGP ピアで `neighbor password` を設定変更したが、セッションが一度切断されるまで古いパスワードで通信が継続/ハングする。** | TCP セッションが既に ESTABLISHED 状態であるため、既存の TCP コネクションが維持されている。 | `show ip bgp neighbors` | `clear ip bgp <IP> soft` または `clear ip bgp <IP>` を実行して TCP コネクションを再確立させる。 |

---

## ⚠ 制限事項

### 1. BGP TCP MD5 と Path MTU Discovery (PMTUD)
*   TCP MD5 認証（Option 19）を有効にすると、TCP ヘッダーサイズが **18 バイト増大** します。これにより、Path MTU の限界ギリギリのパケットで断片化（Fragmentation）が発生したり、一部のファイアウォールで TCP オプションパケットがドロップされる制限があります。

### 2. OSPFv3 IPsec 認証時のハードウェア ASIC 制限
*   Catalyst 9000 シリーズ等で OSPFv3 IPsec 認証を使用する場合、コントロールプレーンで IPsec 処理が行われるため、大量の OSPFv3 LSA 交換時に CPU 利用率が一時的に上昇する場合があります。

---

## 🔄 他技術との関連

*   **NTP (Network Time Protocol):**
    Key-Chain による無停止鍵ローテーション（Hitless Key Rollover）を成立させるための絶対的インフラ前提技術です。NTP による時刻同期が破綻している場合、鍵の期限切れに伴いルーティングドメイン全体が崩壊します。
*   **CoPP (Control Plane Policing):**
    不正なダイジェストを持つ大量の偽ルーティングパケットが送り付けられた際、CPU がハッシュ計算処理で過負荷になるのを防ぐため、CoPP でルーティングプロトコルパケットのレートリミットを事前定義します。

---

## 🧩 比較表

### ルーティングプロトコル認証方式の技術比較

| 比較項目 | MD5 認証 (Classic/Standard) | HMAC-SHA-256 認証 (Modern) | IPsec AH/ESP 認証 (OSPFv3) | TCP-AO (BGP 次世代) |
| :--- | :--- | :--- | :--- | :--- |
| **適用プロトコル** | EIGRP, OSPFv2, RIPv2, BGP | EIGRP Named, OSPFv2 (RFC 5709) | OSPFv3 (IPv6 ネイティブ) | BGP (RFC 5925) |
| **セキュリティ強度** | 中 (MD5 衝突攻撃のリスクあり) | **高** (256ビット暗号ハッシュ) | **極めて高** (IPsec 互換) | **極めて高** (柔軟な Key 構造) |
| **鍵無停止ローテーション** | Key-Chain に依存 | Key-Chain または直接キー | SPI 値の変更 | **完全自動ローテーション** |
| **設定の複雑さ** | 簡単 | 普通 | やや複雑 (SPI/Hexキー指定) | やや複雑 |

---

## 💡 ベストプラクティス

1.  **暗号アルゴリズムのモダン化 (MD5 から HMAC-SHA-256 / TCP-AO への脱却):**
    脆弱性が指摘される MD5 を避け、Cisco IOS-XE 環境では EIGRP Named Mode (HMAC-SHA-256) や OSPFv2 RFC 5709 Cryptographic (HMAC-SHA-256) を優先採用します。
2.  **Key-Chain 運用時の `accept-lifetime` バッファ猶予の定義:**
    鍵ローテーション設計時には、NTP 時刻のわずかなズレや移行作業遅延を考慮し、古いキーの `accept-lifetime` 終了時刻と新しいキーの開始時刻に **最低 30 分〜1 時間の重複（オーバーラップ）** を設けます。
3.  **エリア単位・プロトコル単位の一括認証有効化:**
    OSPF や EIGRP においては、個別の物理インターフェイス設定漏れを防ぐため、可能な限り Area 全体や EIGRP `af-interface default` レベルで認証ポリシーをベースライン定義します。

---

## 📝 ラボ学習・設定サンプル例

※ 本サンプルは、Cisco IOS-XE 17.x の実機挙動に 100% 準拠した、省略なしの完全な CLI 設定構成です。

### 1. 【EIGRP Classic Mode】MD5 Key-Chain 認証

**【問題】**
R1 と R2 の間の `GigabitEthernet1/0/1` において、EIGRP Classic Autonomous System 100 の MD5 認証を構成してください。
*   Key Chain 名: `EIGRP_KEY`
*   Key ID: `1`
*   Key String: `CiscoEigrpPass100`

**【R1 設定】**
```bash
R1# configure terminal
key chain EIGRP_KEY
 key 1
  key-string CiscoEigrpPass100
 exit
exit

interface GigabitEthernet1/0/1
 ip authentication mode eigrp 100 md5
 ip authentication key-chain eigrp 100 EIGRP_KEY
end
```

**【R2 設定】**
```bash
R2# configure terminal
key chain EIGRP_KEY
 key 1
  key-string CiscoEigrpPass100
 exit
exit

interface GigabitEthernet1/0/1
 ip authentication mode eigrp 100 md5
 ip authentication key-chain eigrp 100 EIGRP_KEY
end
```

**【検証方法】**
```bash
R1# show ip eigrp interfaces detail GigabitEthernet1/0/1
# 「Authentication mode is md5, key-chain is "EIGRP_KEY"」が表示されることを確認します。
```

---

### 2. 【EIGRP Named Mode】HMAC-SHA-256 認証 (直接キー指定)

**【問題】**
R1 と R2 において、EIGRP Named Mode（インスタンス名: `CCIE_NAMED`、AS 200）のインターフェイス `GigabitEthernet1/0/2` に対し、Key-Chain を使用せず直接 HMAC-SHA-256 認証を設定してください。
*   Password: `NamedEigrpSha256Secret`

**【R1 設定】**
```bash
R1# configure terminal
router eigrp CCIE_NAMED
 address-family ipv4 autonomous-system 200
  af-interface GigabitEthernet1/0/2
   authentication mode hmac-sha-256 NamedEigrpSha256Secret
  exit-af-interface
 exit-address-family
end
```

**【R2 設定】**
```bash
R2# configure terminal
router eigrp CCIE_NAMED
 address-family ipv4 autonomous-system 200
  af-interface GigabitEthernet1/0/2
   authentication mode hmac-sha-256 NamedEigrpSha256Secret
  exit-af-interface
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors
# R2 (10.1.2.2) とのネイバーが ESTABLISHED になっていることを確認します。
```

---

### 3. 【EIGRP】無停止鍵ローテーション (Hitless Key Rollover)

**【問題】**
R1 において、キーの自動切り替えを行う Key-Chain `EIGRP_ROLLOVER` を作成してください。
*   Key 1: String `OldKey111`（常時受付許可、送信は 2026年12月31日 23:59:59 まで）
*   Key 2: String `NewKey222`（2026年12月31日 23:00:00 より受信受付開始、2027年1月1日 00:00:00 より送信開始）

**【R1 設定】**
```bash
R1# configure terminal
key chain EIGRP_ROLLOVER
 key 1
  key-string OldKey111
  accept-lifetime 00:00:00 Jan 1 2025 infinite
  send-lifetime 00:00:00 Jan 1 2025 23:59:59 Dec 31 2026
 key 2
  key-string NewKey222
  accept-lifetime 23:00:00 Dec 31 2026 infinite
  send-lifetime 00:00:00 Jan 1 2027 infinite
 exit
end
```

---

### 4. 【OSPFv2】Area 0 全体 MD5 認証と特定リンクの個別キー指定

**【問題】**
R1 と R2 において、OSPFv2 Area 0 全体で MD5 認証を有効化（デフォルト Key ID 1: `AreaDefaultKey`）しつつ、R1-R2 間の `GigabitEthernet1/0/1` のみ個別の Key ID 2 (`LinkSpecificKey`) に上書き構成してください。

**【R1 設定】**
```bash
R1# configure terminal
router ospf 1
 area 0 authentication message-digest
exit

interface GigabitEthernet1/0/1
 ip ospf message-digest-key 2 md5 LinkSpecificKey
exit
end
```

**【R2 設定】**
```bash
R2# configure terminal
router ospf 1
 area 0 authentication message-digest
exit

interface GigabitEthernet1/0/1
 ip ospf message-digest-key 2 md5 LinkSpecificKey
exit
end
```

---

### 5. 【OSPFv2】RFC 5709 HMAC-SHA-256 暗号認証

**【問題】**
R1 の `GigabitEthernet1/0/3` において、RFC 5709 に準拠した HMAC-SHA-256 暗号認証を設定してください。
*   Key ID: `10`
*   Key String: `OspfSha256CryptKey`

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/3
 ip ospf authentication cryptographic
 ip ospf message-digest-key 10 hmac-sha-256 OspfSha256CryptKey
end
```

---

### 6. 【OSPFv3】IPv6 IPsec AH 認証

**【問題】**
R1 と R2 の `GigabitEthernet1/0/1` において、OSPFv3（IPv6）のネイバー間認証を IPsec AH を使用して構成してください。
*   SPI: `5000`
*   AH Algorithm: `sha1`
*   Key (40桁 Hex): `a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0`

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/1
 ospfv3 authentication ipsec spi 5000 ah sha1 a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0
end
```

---

### 7. 【OSPFv3】Trailer Authentication (RFC 7166)

**【問題】**
R1 の `GigabitEthernet1/0/2` において、IPsec を使用しない RFC 7166 OSPFv3 Trailer Authentication をキーチェーン `OSPFv3_TRAILER` にバインドして構成してください。

**【R1 設定】**
```bash
R1# configure terminal
key chain OSPFv3_TRAILER
 key 1
  key-string TrailerSecret999
 exit
exit

interface GigabitEthernet1/0/2
 ospfv3 authentication key-chain OSPFv3_TRAILER
end
```

---

### 8. 【BGP】TCP MD5 Neighbor 認証

**【問題】**
R1 (AS 65001) と R2 (AS 65002) 間（ピア IP: `10.1.12.2`）の BGP セッションに TCP MD5 パスワードを適用してください。
*   Password: `BgpMd5Pass65000`

**【R1 設定】**
```bash
R1# configure terminal
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 password BgpMd5Pass65000
end
```

---

### 9. 【BGP】TCP-AO (TCP Authentication Option - RFC 5925)

**【問題】**
R1 (AS 65001) と R2 (AS 65002) 間において、TCP-AO 認証を構成してください。
*   Key Chain: `BGP_TCP_AO`
*   Algorithm: `hmac-sha-1-96`
*   Key String: `TcpAoSecretKey2026`

**【R1 設定】**
```bash
R1# configure terminal
key chain BGP_TCP_AO
 key 1
  key-string TcpAoSecretKey2026
  cryptographic-algorithm hmac-sha-1-96
 exit
exit

router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 ao key-chain BGP_TCP_AO
end
```

---

### 10. 【RIPv2】MD5 Key-Chain 認証

**【問題】**
R1 の `GigabitEthernet1/0/4` において、RIPv2 の MD5 認証を構成してください。
*   Key Chain: `RIP_KEY`
*   Key String: `RipMd5Password`

**【R1 設定】**
```bash
R1# configure terminal
key chain RIP_KEY
 key 1
  key-string RipMd5Password
 exit
exit

interface GigabitEthernet1/0/4
 ip rip authentication mode md5
 ip rip authentication key-chain RIP_KEY
end
```

---

### 11. 【VRF-aware EIGRP】VRF 内インターフェイスにおける HMAC-SHA-256 認証

**【問題】**
VRF `RED` に所属する `GigabitEthernet1/0/5` において、EIGRP Named Mode（AS 300）の HMAC-SHA-256 認証を設定してください。
*   Password: `VrfRedEigrpSecret`

**【R1 設定】**
```bash
R1# configure terminal
router eigrp CCIE_NAMED
 address-family ipv4 vrf RED autonomous-system 300
  af-interface GigabitEthernet1/0/5
   authentication mode hmac-sha-256 VrfRedEigrpSecret
  exit-af-interface
 exit-address-family
end
```

---

## ❓ 想定試験問題

CCIE EI ラボ実技および記述試験を意識したハイレベル設問集です。

### 1. 【コンフィグ読解：Key-Chain ライフタイム切れによる EIGRP ネイバー断】
**問題:** 
R1 と R2 の間で以下の Key-Chain コンフィグを流し込み、EIGRP MD5 認証を有効化しました。
現在のルータ時刻は **2026年7月1日 12:00:00** です。この時、ネイバー関係に発生する問題と原因を説明してください。
```text
key chain EIGRP_KEY
 key 1
  key-string PrimaryPass
  send-lifetime 00:00:00 Jan 1 2026 23:59:59 Jun 30 2026
  accept-lifetime 00:00:00 Jan 1 2026 23:59:59 Jun 30 2026
 key 2
  key-string SecondaryPass
  send-lifetime 00:00:00 Jul 1 2026 23:59:59 Dec 31 2026
  accept-lifetime 00:00:00 Jul 2 2026 23:59:59 Dec 31 2026
```

**解答・解説:**
*   **発生する障害:** R1 と R2 の間の EIGRP ネイバーが**即座に切断（Down）** します。
*   **技術的原因:**
    *   現在時刻（7月1日 12:00）において、`Key 1` の `send-lifetime` および `accept-lifetime` はすでに期限切れ（6月30日終了）です。
    *   一方、`Key 2` は `send-lifetime` が 7月1日より有効になっているためパケット送出に使用されますが、`accept-lifetime`（受信許可）が **「7月2日」からに誤設定** されています。
    *   結果として、両ルータともに送信したパケット（Key 2 で署名）を受信側で受け入れることができず（Valid Key なしと判断）、認証失敗により EIGRP ネイバーが切断されます。

---

### 2. 【トラブルシュート：OSPFv3 IPsec SPI 不一致】
**問題:** 
R1 と R2 間で OSPFv3（IPv6）のネイバーを確立するため、以下のコマンドを適用しましたが、ネイバー状態が `INIT/DROPPED` から進みません。
デバッグコマンド `debug ospfv3 adj` では `Authentication Failed` が検出されています。原因と修正箇所を指摘してください。
```text
[R1 コンフィグ]
interface GigabitEthernet1/0/1
 ospfv3 authentication ipsec spi 1000 ah sha1 1234567890123456789012345678901234567890

[R2 コンフィグ]
interface GigabitEthernet1/0/1
 ospfv3 authentication ipsec spi 2000 ah sha1 1234567890123456789012345678901234567890
```

**解答・解説:**
*   **原因:** **SPI (Security Parameter Index) の不一致** です。R1 は `spi 1000`、R2 は `spi 2000` となっており、IPsec アソシエーションが成立しません。
*   **修正方法:** R2 側の SPI を R1 と同じ `1000` に揃えます（`ospfv3 authentication ipsec spi 1000 ...`）。

---

### 3. 【Design：BGP パスワード変更時のセッション寸断回避】
**問題:** 
稼働中の eBGP ピアにおいて、セキュリティポリシー変更に伴い BGP 認証パスワードを更新する必要があります。
従来の TCP MD5 (`neighbor password`) と比較した場合、**TCP-AO (TCP Authentication Option - RFC 5925)** を採用することで得られる運用上の決定的なメリットを解説してください。

**解答・解説:**
*   **TCP MD5 の課題:** `neighbor password` を変更すると、TCP 擬似ヘッダーのオプション値が変化するため、確立中の TCP セッションを一度クリア（Reset）しなければ新しいパスワードが反映されず、BGP セッションの寸断（Route Flap）が不可避でした。
*   **TCP-AO のメリット:** TCP-AO は複数のキー（Key ID）および暗号アルゴリズムを保持可能な Key-Chain と連携できます。旧キーと新キーが並行して有効な「過渡期（Overlap）」を作ることで、**BGP TCP セッションを 1 秒たりとも切断することなく（Hitless Key Rollover）、安全かつシームレスにパスワードを更新可能** になります。

---

## 🔗 参考リソース

ページ作成にあたり参照された Cisco 公式ドキュメントおよび技術リソースです。

*   [**Cisco IOS XE 17.x IP Routing: EIGRP Configuration Guide - EIGRP Authentication**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/17-x/ire-17-x-book.html)
*   [**Cisco IOS XE 17.x IP Routing: OSPF Configuration Guide - OSPF Authentication**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/17-x/iro-17-x-book.html)
*   [**Cisco IOS XE 17.x IP Routing: BGP Configuration Guide - BGP TCP Authentication Option**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/17-x/irg-17-x-book.html)
*   [**RFC 5709 - OSPFv2 HMAC-SHA Cryptographic Authentication**](https://datatracker.ietf.org/doc/html/rfc5709)
*   [**RFC 7166 - OSPFv3 Authentication Trailer**](https://datatracker.ietf.org/doc/html/rfc7166)
*   [**RFC 5925 - The TCP Authentication Option (TCP-AO)**](https://datatracker.ietf.org/doc/html/rfc5925)

---

## 📝 **補足（Notes）**

### ルーティングプロトコル認証 チェックリスト

```text
                  [ ルーティング認証構成チェック ]
                                 │
           ┌─────────────────────┼─────────────────────┐
           ▼                     ▼                     ▼
     [ Key-Chain ]         [ NTP 時刻同期 ]       [ 適合アルゴリズム ]
  ・Lifetime オーバーラップ    ・全ルータで UTC 統一    ・MD5 ➔ SHA-256 推進
  ・大文字小文字の完全一致    ・Stratum の安定化       ・40桁 Hex 等の型合わせ
```

*   **最終チェックシート:**
    *   [ ] EIGRP / RIPv2 の Key-Chain において、`accept-lifetime` に十分なオーバーラップバッファを設定しているか？
    *   [ ] OSPFv2 で Area 認証を設定した際、全ルータの対向インターフェイスに Key ID が定義されているか？
    *   [ ] OSPFv3 IPsec AH 認証で、SPI 値が 256 以上かつ Hex キーが正確な桁数（SHA1: 40桁）になっているか？
    *   [ ] BGP 認証パスワード設定時、TCP コネクションが正しく再確立または維持されているか確認したか？

