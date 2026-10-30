---
layout: default
title: 5.1.c-YAML
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 3
---

# 5.1.c YAML

## 📘 概要

YAML（YAML Ain't Markup Language）は、人間にとっての読みやすさと書きやすさを最優先に設計されたデータシリアライゼーション（データ構造化）フォーマットです。インデント（半角スペースによる階層表現）を用いて、データ構造（スカラー、マッピング、シーケンス）を透過的に表現します。

CCIE Enterprise Infrastructure (EI) v1.1 において、YAML は自動化オーケストレーションツールである **Ansible (Playbook、Inventory、Host/Group Vars)** の主言語として機能するほか、**Python (`PyYAML` モジュール)** や **Jinja2 テンプレートエンジンのデータ定義ファイル**、さらには CI/CD パイプライン（GitLab CI、GitHub Actions）や Cisco SD-WAN / Catalyst Center の各種設定テンプレート記述において最も重要なデータ記述フォーマットとして位置付けられています。

CCIE EI ラボ試験においては、単に YAML の構文を理解するだけでなく、Ansible Playbook 内での複雑な変数構造の記述、Jinja2 テンプレートへの変数流し込み、Python による YAML ファイルの安全なロード（`yaml.safe_load`）とパース、およびタブ文字混入やインデントズレによる構文エラーの現場即応型トラブルシューティングが強く求められます。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **正式名称** | YAML Ain't Markup Language（再帰的頭字語） |
| **仕様標準** | YAML 1.2 (RFC 準拠の JSON 完全上位互換) |
| **主用途** | Ansible Playbook 記述、Ansible 変数（host_vars / group_vars）、Python 設定ファイル、Jinja2 データソース |
| **基本データ構造** | スカラー（文字列、数値、真偽値）、マッピング（Key-Value 辞書 `{}`）、シーケンス（リスト `[]`） |
| **インデントルール** | **半角スペースのみ使用可能（タブ文字 `\t` は厳禁）**。一般的に 2 スペースでネストレベルを統一 |
| **メリット** | 人間が直感的に読める、視認性が極めて高い、JSON との相互互換性、コメント記述が可能 (`#`) |
| **デメリット** | インデントズレによる構造変化が起きやすい、厳密な構文チェックが必要（`yamllint` 等の活用） |
| **型システム** | 自動型推論（数値、文字列、`true`/`false` ブール値、`null`）。文字列明示にはダブル/シングルクォート使用 |
| **特殊機能** | 複数ドキュメント記述 (`---` / `...`)、アンカー (`&`) とエイリアス (`*`) によるデータ再利用・DRY 原則 |

---

## 🏗 動作原理

YAML はテキストベースで記述された構造化データを、プログラムや自動化ツールが理解できるインメモリのオブジェクト構造（Python 辞書 `dict` や リスト `list`）へ相互変換（シリアライズ / デシリアライズ）する原理に基づきます。

```text
[人間が記述・管理する設定]
      ↓ (YAML 形式テキスト: host_vars/group_vars, Playbook)
  Ansible / Python (PyYAML Parser)
      ↓ (yaml.safe_load / YAML Engine)
[インメモリデータ構造 (Python dict / list)]
      ↓ (Jinja2 Template Engine / API Client)
[ネットワーク機器設定 (CLI コンフィグ / RESTCONF / NETCONF Payload)]
```

### 1. データ構造の 3 大要素

1. **スカラー (Scalars):** 単一の値（文字列、数値、真偽値、Null）
   * 例: `hostname: R1` , `asn: 65001` , `enabled: true`
2. **マッピング (Mappings / Mappings of Key-Value):** 辞書・ハッシュ（JSON オブジェクト同等）
   * コロン `:` と半角スペースで指定。
   ```yaml
   router:
     id: 1.1.1.1
     asn: 65001
   ```
3. **シーケンス (Sequences / Lists):** 配列・リスト（JSON 配列同等）
   * ダッシュ `-` と半角スペースで指定。
   ```yaml
   interfaces:
     - GigabitEthernet1
     - GigabitEthernet2
   ```

### 2. アンカー (&) と エイリアス (*) による参照

YAML は `&` (Anchor) でデータブロックに名前を付け、`*` (Alias) で参照することで、同一設定の重複記述を防止する DRY (Don't Repeat Yourself) 原則をサポートします。

```yaml
# デフォルトインターフェイス設定テンプレートの定義
default_qos: &QOS_POLICY
  service_policy_input: PM-MARKING
  service_policy_output: PM-QUEUING

interfaces:
  - name: GigabitEthernet1
    ip: 10.1.1.1/24
    <<: *QOS_POLICY # アンカー設定のマージ

  - name: GigabitEthernet2
    ip: 10.1.2.1/24
    <<: *QOS_POLICY # 再利用
```

---

## ⚙ 動作シーケンス

Ansible や Python プログラムが YAML データソースを読み込み、Cisco IOS XE 機器へコンフィグを展開する一連の処理シーケンスは以下の通りです。

```text
+------------------+         +--------------------+         +-------------------+         +--------------------+
| YAML File        |         | PyYAML / Ansible   |         | Jinja2 Engine     |         | Cisco IOS XE Device|
| (vars/main.yml)  |         | (YAML Parser)      |         | (Template)        |         | (Target Router/SW) |
+------------------+         +--------------------+         +-------------------+         +--------------------+
         |                             |                              |                             |
         | --- 1. Read YAML File ----> |                              |                             |
         |                             | --- 2. Lexical & Syntactic   |                             |
         |                             |        Validation (Indent) ->|                             |
         |                             | --- 3. Convert to Data Object|                             |
         |                             |        (Python dict/list) -->|                             |
         |                             |                              | --- 4. Render Template ---> |
         |                             |                              |        with Variables       |
         |                             |                              |                             | --- 5. Push CLI Config
         |                             |                              |                             |        via SSH/NETCONF ->
         |                             | <--- 6. Return Execution Status (OK/Changed/Failed) ------- |
```

1. **ファイル読み込み (File Read):** `host_vars/R1.yml` または `site_definition.yml` などの YAML ファイルをテキストとしてロード。
2. **字句・構文解析 (Lexical & Syntactic Parsing):**
   * インデント階層（スペースの数）とトークン（`-`, `:`, `#`, `---`）を解析。
   * タブ文字 `\t` の有無をチェック。存在する場合は構文エラー（`ScannerError`）をスロー。
3. **データオブジェクト化 (Data Deserialization):**
   * マッピングを Python `dict` に、シーケンスを Python `list` に、スカラーを `str`/`int`/`bool` に型変換。
4. **テンプレートレンダリング (Template Rendering):**
   * 抽出されたデータ構造を Jinja2 テンプレート（`cisco_ios.j2`）の変数にマッピングして CLI 設定文字列を生成。
5. **機器への適用 (Device Deployment):**
   * 生成された CLI 設定を SSH/NETCONF 経由で Cisco ネットワーク機器へ流し込み。

---


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、YAML は Automation セクションの基礎問題および応用問題で必ず登場します。特に Ansible Playbook の作成、変数構造のバインド、Jinja2 テンプレート連動で落とし穴が多く存在します。

### 1. Blueprint で特に重要なポイント

* **インデントの完全制御:** 2 スペースインデントで正確に揃える。**絶対に TAB キーを使用しない**。
* **リスト (Sequence) と 辞書 (Mapping) のネスト構文:**
  * リスト要素の中に辞書を含めるパターン（`vars` や `tasks` での標準記述）。
  * 辞書の値の中にリストを持たせるパターン。
* **Jinja2 変数展開構文におけるクォート要件:**
  * YAML 内で `{{ variable }}` を値の先頭に記述する場合、ダブルクォートで括る必要がある（括らないと YAML パーサーが波括弧 `{` をブロックマッピング開始と解釈してエラーになる）。
  * ❌ 誤り: `ip: {{ host_ip }}`
  * ⭕ 正解: `ip: "{{ host_ip }}"`
* **複数行文字列 (Multiline Strings) の制御記号:**
  * パイプ記号 `|` (Literal Block Scalar): 改行をそのまま保持（CLI コンフィグブロックや Banner 設定に最適）。
  * 大なり記号 `>` (Folded Block Scalar): 改行をスペースに置換して単一行化（長文メッセージ用）。
* **真偽値 (Boolean) の自動型変換の注意:**
  * `yes`/`no`, `true`/`false`, `on`/`off` はすべてブール値にキャストされる。
  * 明示的に文字列の `"yes"` や `"no"`（例: インターフェイスの説明文や VLAN 名等）を渡したい場合は必ずクォートで括る。

### 2. よくある設定ミス ＆ 狙われやすい制限事項

1. **TAB 文字の誤挿入:**
   * エディタの設定ミスにより TAB 文字が挿入され、`ansible-playbook` 実行時に `yaml.scanner.ScannerError: mapping values are not allowed here` エラーが発生する。
2. **Jinja2 二重波括弧のアンクォートエラー:**
   * `ansible.builtin.debug: msg={{ result }}` のように波括弧が文頭に来る際にクォートを忘れ、構文エラーとなる。
3. **コロン `:` 直後のスペース欠落:**
   * `ip:10.1.1.1` のようにコロンの後にスペースを入れ忘れると、`ip:10.1.1.1` 全体が単一の文字列として扱われ、キー・値のペアとして認識されない。
4. **リストハイフン `-` 直後のスペース欠落:**
   * `-name: Task1` のようにハイフンの直後にスペースを入れないと構文エラー。

---

## 🛠 設定方法

### 1. Ansible Playbook における標準的 YAML 構造例

ネットワーク機器（Cisco IOS XE）に対する VLAN 作成および Interface 設定を行う Ansible Playbook (`site_config.yml`) の設定例です。

```yaml
---
# Cisco IOS XE ネットワーク設定自動化 Playbook
- name: Configure Enterprise Core Switches
  hosts: core_switches
  gather_facts: false
  connection: ansible.netcommon.network_cli

  vars:
    domain_name: lab.ccie.internal
    dns_servers:
      - 10.1.1.254
      - 10.1.1.253

  tasks:
    - name: Ensure Domain Name and DNS are configured
      cisco.ios.ios_system:
        domain_name: "{{ domain_name }}"
        name_servers: "{{ dns_servers }}"
        state: merged

    - name: Configure Core Interfaces
      cisco.ios.ios_l3_interfaces:
        config:
          - name: GigabitEthernet0/1
            ipv4:
              - address: 10.100.1.1/30
          - name: GigabitEthernet0/2
            ipv4:
              - address: 10.100.1.5/30
        state: merged
...
```

### 2. Ansible 変数ファイル (host_vars / group_vars) での構造化 YAML

`host_vars/R1.yml` において、BGP ピアリング情報を構造化して定義する例です。

```yaml
---
# R1 固有の変数値定義
router_bgp:
  asn: 65001
  router_id: 1.1.1.1
  neighbors:
    - ip: 10.1.1.2
      remote_asn: 65001
      description: iBGP_to_R2
      update_source: Loopback0
    - ip: 192.168.12.2
      remote_asn: 65002
      description: eBGP_to_ISP
      password: "CiscoPass123!"
```

### 3. Python (`PyYAML`) による YAML の読み込みと書き出し

Python スクリプトから安全に YAML をロード・シリアライズする方法です。

```python
#!/usr/bin/env python3
import yaml
import json

# 1. YAML ファイルの安全な読み込み (yaml.safe_load)
with open('host_vars/R1.yml', 'r', encoding='utf-8') as file:
    try:
        data = yaml.safe_load(file)
        print("--- Loaded Data (Python Dict) ---")
        print(data)
        print(f"Router BGP ASN: {data['router_bgp']['asn']}")
    except yaml.YAMLError as exc:
        print(f"YAML Parsing Error: {exc}")

# 2. Python 辞書データを YAML フォーマットとして保存 (yaml.dump)
new_config = {
    'hostname': 'R2',
    'interfaces': [
        {'name': 'Loopback0', 'ip': '2.2.2.2/32'},
        {'name': 'GigabitEthernet1', 'ip': '10.1.1.2/24'}
    ]
}

with open('/workspace/scratch/R2_config.yml', 'w', encoding='utf-8') as outfile:
    yaml.dump(new_config, outfile, default_flow_style=False, sort_keys=False)
```

---

## 🔍 検証コマンド

YAML ファイルの構文検証や Ansible でのドライラン検証コマンド一覧です。

| 目的 | コマンド / 手法 | 補足・使用例 |
| --- | --- | --- |
| **YAML 構文チェック** | `yamllint <file.yml>` | インデントや行末スペース、タブ文字の有無を厳密検知 |
| **Ansible 構文確認** | `ansible-playbook --syntax-check <playbook.yml>` | Ansible 独自のタグおよび YAML 構造エラーの事前検証 |
| **Ansible ドライラン** | `ansible-playbook -i inventory <playbook.yml> --check --diff` | 機器に変更を与えず差分を表示 |
| **Python によるパーステスト** | `python3 -c 'import yaml, sys; print(yaml.safe_load(open(sys.argv[1])))' <file.yml>` | インライン Python による即座パース検証 |
| **JSON 相互変換確認** | `python3 -c 'import yaml, json, sys; print(json.dumps(yaml.safe_load(open(sys.argv[1])), indent=2))' <file.yml>` | YAML データを整形された JSON として構造表示 |

---

## 🚨 トラブルシュート

| 症状 / エラーメッセージ | 原因 | 確認・特定方法 | 対処方法 |
| --- | --- | --- | --- |
| `yaml.scanner.ScannerError: found character '	' that cannot start any token` | インデントにタブ文字（`	`）が含まれている | `cat -A <file.yml>` または `yamllint` を実行（`^I` 表示でタブを特定） | タブ文字をすべて半角スペース 2 個に置換。VS Code / vim の Tab 展開設定（`expandtab`）を有効化 |
| `yaml.parser.ParserError: expected '<block end>', but found '<block mapping start>'` | 波括弧 `{{ ... }}` のアンクォート、またはネストインデントのズレ | `ansible-playbook --syntax-check` | `msg: "{{ my_var }}"` のようにダブルクォートで括る。親要素からのスペース数を揃える |
| `yaml.scanner.ScannerError: mapping values are not allowed here` | コロン `:` の直後に半角スペースが存在しない | エラー発生行のコロン直後を確認 | `key:value` を `key: value` に修正 |
| `Syntax Error: '- name:' is not formatted correctly` | リストハイフン `-` の直後に半角スペースが存在しない | 該当行のハイフン直後を確認 | `-name:` を `- name:` に修正 |
| 真偽値 `"no"` がブール値 `false` に勝手に型変換されエラー | YAML の自動型推論により `no` や `yes` が `bool` に解釈される | Python パース結果や Ansible 変数評価を確認 | 文字列として渡したい場合は `"no"` / `'yes'` とクォートで明確に囲む |

---


## ⚠ 制限事項

1. **タブ文字の絶対使用禁止:**
   * W3C/YAML 仕様により、構造インデントにタブ文字（`\t`）を使用することは一切許可されていません。
2. **型推論による予意せぬキャスト:**
   * `0123`（先頭が 0）が 8 制度数値として解釈されたり、`3.10` が 浮動小数点数 `3.1` に変換されたり、国コード `"NO"`（ノルウェー）が `false` に変換されるトラブルが存在します。文字列識別子（VLAN 名や国コード等）は必ず明示的なクォートが必要です。
3. **パース速度のオーバーヘッド:**
   * JSON に比べて正規表現解析や複雑なアンカー/エイリアス処理が発生するため、数十メガバイトを超える大容量データの高速パースには向きません。
4. **Ansible バージョン依存性:**
   * Ansible 2.9 以降では YAML 1.2 準拠のパーサーが使用されますが、旧環境での特殊表記（`yes`/`no` の取扱い等）と Python PyYAML バージョンとのミスマッチに注意が必要です。

---

## 🔄 他技術との関連

* **Ansible (Playbook / Inventory / Variables):**
  Ansible は YAML を完全なメインフォーマットとして採用しています。Task 順序、Loop 構造 (`loop`)、条件分岐 (`when`)、エラー処理 (`failed_when`) のすべてを YAML のリスト・辞書構造で表現します。
* **Jinja2 Template Engine:**
  YAML 変数ファイル（`group_vars/all.yml` など）で定義された多次元辞書・リストデータを、Jinja2 テンプレート（`.j2`）で参照・ループ展開して Cisco CLI や NETCONF XML コンフィグを動的に書き出します。
* **JSON (RESTCONF / API Payload):**
  YAML 1.2 は JSON の超集合（Superset）です。有効な JSON データはそのまま有効な YAML データとして読み込むことが可能です（インラインスタイルの JSON 表記 `{ "a": 1 }` も YAML 内で利用可能）。
* **Python (`PyYAML` / `ruamel.yaml`):**
  Python 自動化スクリプトにおいて、コンフィグパラメータをスクリプト内にハードコードせず、外部 YAML ファイルとして分離保持することで、コードの再利用性を最大化します。

---

## 🧩 比較表

データ構造化・シリアライゼーション 3 大フォーマットの比較です。

| 比較項目 | YAML | JSON | XML |
| --- | --- | --- | --- |
| **可読性 (Readability)** | **極めて高い**（インデント構造、視認性良好） | 中程度（ブラケットが多く複雑化しやすい） | 低い（閉じタグが多く冗長） |
| **記述量 (Verbosity)** | **最小**（記号が最小限） | 少〜中 | 非常に多い（ヘッダー/タグが必須） |
| **コメント機能** | **対応 (`#`)** | 非対応 | 対応 (`<!-- -->`) |
| **インデント仕様** | **半角スペースのみ（タブ厳禁）** | 自由（空白は無視される） | 自由（空白は無視される） |
| **データ型** | 自動型推論（Str, Int, Bool, Null等） | 厳密（String, Number, Bool, Array, Object, Null） | すべてテキスト（XSD/YANGで型定義） |
| **標準用途** | Ansible, CI/CD, 設定ファイル, Jinja2 | RESTCONF, Catalyst Center API, SD-WAN API | NETCONF, Device Configuration |
| **スキーマ検証** | Kwalify, Rx, JSON Schema 経由 | JSON Schema | XSD, YANG スキーマ |

---

## 💡 ベストプラクティス

1. **2 スペースインデントの徹底:**
   * ネストレベルごとに常に半角スペース 2 個を使用し、親レベルと子レベルを明確に揃えます。
2. **変数表現におけるクォートの標準化:**
   * 文頭が `{{` で始まる波括弧表現は必ずダブルクォートで括る (`"{{ my_var }}"`)。
   * 数字だけで構成される文字列（VLAN ID、AS 番号等）を文字列として扱いたい場合は `asn: "65001"` のように明示的にクォートする。
3. **ファイル先頭と末尾の記号指定:**
   * ファイルの開始に `---` (Document Start) を、終了に `...` (Document End) を記述し、複数ドキュメントの区切りやファイルの境界を明示します。
4. **`yamllint` による CI/CD 構文自動検証:**
   * Git リポジトリへのコミット前に `yamllint` ツールを適用し、インデントミスや行末の無駄なスペース、不適切な改行を自動検知・修正します。
5. **Ansible 変数ファイルの階層化と命名規則:**
   * `group_vars/all.yml` (全ホスト共通変数), `group_vars/spines.yml` (役割別変数), `host_vars/R1.yml` (個別ホスト固有変数) のように階層を整理し、変数の影響範囲を極小化します。

---


## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルの実践的な YAML 定義、Ansible Playbook、Python スクリプトの演習サンプル（10 個）です。

### サンプル 1: Ansible Playbook での BGP Neighbor 設定（リスト ＋ 辞書の多層 YAML）

* **問題:**
  `R1` ルータに対し、Ansible `cisco.ios.ios_bgp_global` モジュールを用いて BGP ASN 65001、Router-ID 1.1.1.1、および 2 つの iBGP ネイバー（10.1.1.2, 10.1.1.3）を設定する Playbook (`configure_bgp.yml`) を完全な YAML 構文で作成しなさい。
* **要件:**
  1. `---` で開始し、インデントは 2 スペースで統一すること。
  2. BGP ネイバー設定はリスト形式で定義し、各ネイバーに `remote_asn` と `update_source` (Loopback0) を含めること。
  3. 変数部分は `{{ ... }}` を使用し、文頭に来る場合は適切にクォート処理を行うこと。
* **設定例 (`configure_bgp.yml`):**

```yaml
---
- name: Configure BGP Routing on Cisco IOS XE
  hosts: R1
  gather_facts: false
  connection: ansible.netcommon.network_cli

  vars:
    bgp_asn: 65001
    router_id: 1.1.1.1
    neighbors:
      - ip: 10.1.1.2
        remote_asn: 65001
        update_source: Loopback0
        description: iBGP_to_R2
      - ip: 10.1.1.3
        remote_asn: 65001
        update_source: Loopback0
        description: iBGP_to_R3

  tasks:
    - name: Apply BGP Global Configuration
      cisco.ios.ios_bgp_global:
        config:
          as: "{{ bgp_asn }}"
          router_id: "{{ router_id }}"
          neighbors:
            - neighbor: "{{ item.ip }}"
              remote_as: "{{ item.remote_asn }}"
              update_source: "{{ item.update_source }}"
              description: "{{ item.description }}"
        state: merged
      loop: "{{ neighbors }}"
...
```

* **検証方法:**
  `ansible-playbook -i inventory configure_bgp.yml --syntax-check` を実行し、構文エラーが発生しないことを確認。さらに `--check` オプションでドライランを実施する。

---

### サンプル 2: Jinja2 用多次元変数定義ファイル (`host_vars/SW1.yml`)

* **問題:**
  スイッチ `SW1` の多層 VLAN および SVI（L3 インターフェイス）設定用データを保持する YAML 変数ファイル (`host_vars/SW1.yml`) を作成しなさい。
* **要件:**
  1. VLAN 10 (DATA), VLAN 20 (VOICE), VLAN 99 (MGMT) の 3 つの VLAN 情報を記述すること。
  2. VLAN 10 と 20 には SVI IP アドレス（`10.1.10.1/24`, `10.1.20.1/24`）と HSRP 仮想 IP アドレス（`10.1.10.254`, `10.1.20.254`）を含めること。
* **設定例 (`host_vars/SW1.yml`):**

```yaml
---
hostname: SW1
vlans:
  - id: 10
    name: DATA_VLAN
    svi_enabled: true
    ip_address: 10.1.10.1
    netmask: 255.255.255.0
    hsrp:
      group: 10
      vip: 10.1.10.254
      priority: 110

  - id: 20
    name: VOICE_VLAN
    svi_enabled: true
    ip_address: 10.1.20.1
    netmask: 255.255.255.0
    hsrp:
      group: 20
      vip: 10.1.20.254
      priority: 110

  - id: 99
    name: MANAGEMENT
    svi_enabled: false
...
```

* **検証方法:**
  Python で `yaml.safe_load(open('host_vars/SW1.yml'))` を実行し、データが辞書型として正しくパースされ、`data['vlans'][0]['hsrp']['vip']` から `10.1.10.254` が抽出できることを確認。

---

### サンプル 3: Python `PyYAML` による YAML 構文エラーの検知スクリプト

* **問題:**
  指定された YAML ファイルを安全にロードし、タブ文字やインデントエラーが存在する場合にエラー内容と該当行を詳細表示する Python スクリプト (`validate_yaml.py`) を作成しなさい。
* **要件:**
  1. `yaml.safe_load()` を使用し、例外 `yaml.YAMLError` をキャッチすること。
  2. 正常時はデータ構造（キー数・要素数）を出力し、異常時はエラーメッセージを表示すること。
* **設定例 (`validate_yaml.py`):**

```python
#!/usr/bin/env python3
import sys
import yaml

def validate_file(file_path):
    print(f"[*] Validating YAML file: {file_path}")
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
            print("[+] SUCCESS: YAML syntax is perfectly valid!")
            if isinstance(data, dict):
                print(f"    Loaded Dictionary with {len(data)} top-level keys: {list(data.keys())}")
            elif isinstance(data, list):
                print(f"    Loaded List with {len(data)} items.")
    except yaml.YAMLError as exc:
        print("[-] ERROR: YAML Syntax Validation Failed!")
        if hasattr(exc, 'problem_mark'):
            mark = exc.problem_mark
            print(f"    Error Location: Line {mark.line + 1}, Column {mark.column + 1}")
            print(f"    Problem Description: {exc.problem}")
        else:
            print(f"    Error Details: {exc}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 validate_yaml.py <target_yaml_file>")
        sys.exit(1)
    validate_file(sys.argv[1])
```

* **検証方法:**
  故意にタブ文字を入れたファイルに対して実行し、`Error Location: Line X, Column Y` が正確に表示されることを検証。

---

### サンプル 4: アンカー (`&`) と エイリアス (`*`) を用いた冗長記述の共通化

* **問題:**
  複数のインターフェイスに同一の QoS ポリシーおよび NTP/Logging 設定テンプレートを適用するための YAML 設定ファイル (`interfaces_anchored.yml`) を記述しなさい。
* **要件:**
  1. `&qos_policy` アンカーを定義し、`service_policy_in` と `service_policy_out` を含めること。
  2. `GigabitEthernet1` と `GigabitEthernet2` で `<<: *qos_policy` を使用してマージ・再利用すること。
* **設定例 (`interfaces_anchored.yml`):**

```yaml
---
# 共通テンプレートの定義
defaults:
  qos: &QOS_DEF
    input_policy: PM-INGRESS-MARKING
    output_policy: PM-EGRESS-QUEUING
  logging: &LOG_DEF
    event_link_status: true

interfaces:
  - name: GigabitEthernet0/1
    description: Uplink_to_Core1
    ip_address: 10.254.1.1/30
    <<: *QOS_DEF
    <<: *LOG_DEF

  - name: GigabitEthernet0/2
    description: Uplink_to_Core2
    ip_address: 10.254.1.5/30
    <<: *QOS_DEF
    <<: *LOG_DEF
...
```

* **検証方法:**
  Python でロードし、`data['interfaces'][0]['input_policy']` が `PM-INGRESS-MARKING` に正しく展開されることを確認。

---

### サンプル 5: 改行保持スカラー (`|`) を用いた Cisco バナー (Banner MOTD) 定義

* **問題:**
  Cisco IOS XE 機器の Banner MOTD（ログイン警告バナー）メッセージを改行を含めてそのまま保持する YAML ファイル (`banner_vars.yml`) を作成しなさい。
* **要件:**
  1. 改行ブロック記号 `|` を使用すること。
  2. 複数行にわたるセキュリティ警告文を含めること。
* **設定例 (`banner_vars.yml`):**

```yaml
---
system_banners:
  motd: |
    *****************************************************************
    * WARNING: AUTHORIZED ACCESS ONLY!                              *
    * All activities on this device are logged and monitored.       *
    * Unauthorized access will be prosecuted to the fullest extent. *
    *****************************************************************
  exec: |
    Welcome to Core Router R1.
    Authorized Session Established.
...
```

* **検証方法:**
  Python の `yaml.safe_load()` でロードし、`print(data['system_banners']['motd'])` を実行した際、改行がそのまま維持されて出力されることを確認。

---


### サンプル 6: Ansible 役割（Role）変数としての OSPF マルチエリア YAML 構造

* **問題:**
  OSPFv2 マルチエリア構成情報を管理するためのロール変数ファイル (`roles/ospf/vars/main.yml`) を作成しなさい。
* **要件:**
  1. OSPF プロセス ID 1、Router-ID 10.255.255.1。
  2. Area 0 (Backbone) と Area 10 (NSSA) の 2 つのエリア情報を定義すること。
  3. Area 10 には `area_type: nssa` と `no_summary: true` を含めること。
* **設定例 (`roles/ospf/vars/main.yml`):**

```yaml
---
ospf_config:
  process_id: 1
  router_id: 10.255.255.1
  auto_cost_reference_bandwidth: 100000
  areas:
    - area_id: 0
      type: normal
      networks:
        - prefix: 10.254.0.0
          wildcard: 0.0.255.255
        - prefix: 10.255.255.1
          wildcard: 0.0.0.0

    - area_id: 10
      type: nssa
      no_summary: true
      networks:
        - prefix: 10.1.10.0
          wildcard: 0.0.0.255
...
```

* **検証方法:**
  Ansible から `{{ ospf_config.areas }}` ループを通して各エリアパラメータが正しく取得可能か検証する。

---

### サンプル 7: SD-WAN テンプレート定義用 YAML データ構造

* **問題:**
  Cisco SD-WAN vEdge / cEdge の Transport 側 WAN インターフェイス（Biz-Internet 及び MPLS）のパラメータを保持する YAML 構造 (`sdwan_transport.yml`) を記述しなさい。
* **要件:**
  1. VPN 0 (Transport VPN) 配下に 2 つの WAN インターフェイスを定義。
  2. カラー (`biz-internet`, `mpls`)、カプセル化 (`ipsec`)、および帯域幅制限を含めること。
* **設定例 (`sdwan_transport.yml`):**

```yaml
---
sdwan_vpn_0:
  vpn_id: 0
  dns_servers:
    - 8.8.8.8
    - 1.1.1.1
  interfaces:
    - name: GigabitEthernet1
      description: WAN_Primary_BizInternet
      ip_address: 203.0.113.2/30
      tunnel_interface:
        color: biz-internet
        encapsulation: ipsec
        allow_service:
          - bgp
          - dhcp
          - dns
          - icmp

    - name: GigabitEthernet2
      description: WAN_Secondary_MPLS
      ip_address: 198.51.100.2/30
      tunnel_interface:
        color: mpls
        encapsulation: ipsec
        allow_service:
          - all
...
```

* **検証方法:**
  Python でロード後、`data['sdwan_vpn_0']['interfaces'][0]['tunnel_interface']['color']` が `biz-internet` になることを確認。

---

### サンプル 8: Python による JSON データを YAML フォーマットへ変換保存するスクリプト

* **問題:**
  RESTCONF API や Catalyst Center REST API から受信した JSON レスポンスデータを読み込み、整形された視認性の高い YAML ファイルへ自動変換保存する Python スクリプト (`json_to_yaml.py`) を作成しなさい。
* **要件:**
  1. `json.loads()` で JSON をロードし、`yaml.dump()` で YAML へ変換すること。
  2. `sort_keys=False` を指定してキーの順序を維持すること。
* **設定例 (`json_to_yaml.py`):**

```python
#!/usr/bin/env python3
import json
import yaml

# RESTCONF レスポンス例 (JSON)
json_response = """
{
  "ietf-interfaces:interfaces": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "description": "MANAGEMENT_INTERFACE",
        "type": "iana-if-type:ethernetCsmacd",
        "enabled": true,
        "ietf-ip:ipv4": {
          "address": [
            {
              "ip": "10.1.1.1",
              "netmask": "255.255.255.0"
            }
          ]
        }
      }
    ]
  }
}
"""

def convert_json_to_yaml(json_str, output_filepath):
    # 1. JSON のパース
    data_dict = json.loads(json_str)
    
    # 2. YAML ファイルへの書き出し
    with open(output_filepath, 'w', encoding='utf-8') as f:
        yaml.dump(data_dict, f, default_flow_style=False, sort_keys=False, indent=2)
    print(f"[+] Successfully converted JSON to YAML -> {output_filepath}")

if __name__ == "__main__":
    convert_json_to_yaml(json_response, "/workspace/scratch/interface_converted.yml")
```

* **検証方法:**
  生成された `/workspace/scratch/interface_converted.yml` を開き、インデント 2 スペースの正当な YAML 構造に変換されていることを検証。

---

### サンプル 9: YAML 内での真偽値・数値の型キャスト厳密制御

* **問題:**
  自動型変換による意図しないキャスト（`no` ➔ `false` 等）を防ぎ、文字列として正しく伝達するための YAML 変数ファイル (`strict_types.yml`) を作成しなさい。
* **要件:**
  1. インターフェイスの説明文 `description` に `"no"` や `"true"` を文字列として保持させること。
  2. VLAN ID や AS 番号をクォート付き/なしで定義し、Python 側の型判定をアサートすること。
* **設定例 (`strict_types.yml`):**

```yaml
---
type_test:
  boolean_implicit: true        # Python bool: True
  boolean_explicit: "true"      # Python str:  'true'
  string_no: "no"               # Python str:  'no'  (クォートなしだと False になる)
  number_int: 65001             # Python int:  65001
  number_str: "65001"           # Python str:  '65001'
  vlan_id: 10                   # Python int:  10
...
```

* **検証方法:**
  Python スクリプト `type(data['type_test']['string_no'])` が `<class 'str'>` であることを確認。

---

### サンプル 10: Ansible インベントリ (Inventory) ファイルの YAML 記述例

* **問題:**
  全社の Cisco 機器群（R1-R3, SW1-SW2）を地域グループ（`datacenter`, `branch`）および役割グループ（`routers`, `switches`）に階層分類した Ansible インベントリファイル (`hosts.yml`) を作成しなさい。
* **要件:**
  1. `all.children` 構造を使用すること。
  2. 各グループおよび個別ホスト宛ての `ansible_host` アドレス変数を定義すること。
* **設定例 (`hosts.yml`):**

```yaml
---
all:
  children:
    datacenter:
      hosts:
        DC-R1:
          ansible_host: 10.254.0.1
        DC-SW1:
          ansible_host: 10.254.0.11

    branch:
      hosts:
        BR-R1:
          ansible_host: 10.100.0.1
        BR-SW1:
          ansible_host: 10.100.0.11

    routers:
      hosts:
        DC-R1:
        BR-R1:

    switches:
      hosts:
        DC-SW1:
        BR-SW1:

  vars:
    ansible_user: admin
    ansible_network_os: cisco.ios.ios
    ansible_connection: network_cli
...
```

* **検証方法:**
  `ansible-inventory -i hosts.yml --list` を実行し、全ホストおよびグループ関係が JSON ツリーとして正しく出力されることを検証。

---


## ❓ 想定試験問題

CCIE EI v1.1 ラボ試験および筆記試験（ENCOR / Practical Exam）を想定した実戦形式の設問 6 問です。

### 問 1 (コンフィグ読解・トラブルシューティング)
以下の Ansible Playbook (`deploy.yml`) を実行したところ、Ansible パーサーから `Syntax Error: expected <block end>, but found '<block mapping start>'` エラーがスローされて処理が中断しました。エラーの原因と正しい修復方法を答えなさい。

```yaml
---
- name: Deploy Device Banner
  hosts: routers
  tasks:
    - name: Set MOTD
      ansible.builtin.debug:
        msg: {{ banner_message }}
```

* **正解・解説:**
  * **原因:** 文頭が `{{`（Jinja2 変数宣言）で始まる場合、YAML パーサーはこれをブロックマッピング（インライン辞書 `{}`）の開始記号とみなしてパースを試みますが、閉じ括弧や構文が合致しないため `Syntax Error` となります。
  * **修正方法:** 変数宣言全体をダブルクォートで囲み、YAML パーサーに対して明示的に文字列値として認識させます。
  ```yaml
        msg: "{{ banner_message }}"
  ```

---

### 問 2 (トラブルシューティング / インデント・型ミス)
エンジニアが Cisco IOS スイッチの VLAN 一括作成用変数ファイル (`vars/vlans.yml`) を記述しましたが、特定スイッチでのみ Ansible タスクが `vlan_id must be an integer` というエラーで失敗します。問題のある行と修正内容を指摘しなさい。

```yaml
---
vlans:
  - id: 10
    name: DATA
  - id: "20"
    name: VOICE
  - id: 30
    name: GUEST
```

* **正解・解説:**
  * **問題点:** VLAN 20 の ID 定義において `id: "20"` とダブルクォートで囲まれているため、YAML パーサーはこれを数値（Integer）ではなく文字列（String）として型判別します。Ansible の `cisco.ios.ios_vlans` モジュールは `id` に Integer 型を要求するため、型不一致エラーが発生します。
  * **修正方法:** ダブルクォートを削除し、`id: 20` と指定して数値型としてロードさせます。

---

### 問 3 (Design / アーキテクチャ)
ネットワーク自動化パイプラインにおいて、JSON ではなく YAML を Ansible Playbook や人間が編集する変数ファイル（`host_vars`/`group_vars`）の主要フォーマットとして採用する最大の設計上の利点（3 点）を述べなさい。

* **正解・解説:**
  1. **人間に対する圧倒的な可読性と書きやすさ:** ブラーケット（`{}`や`[]`）や末尾カンマが不要で、視認性が高く入力ミスを低減できる。
  2. **コメント機能のネイティブサポート (`#`):** 設定意図や変数の説明、変更履歴をファイル内に直接注釈として残すことが可能（JSON では不可）。
  3. **複数行テキストブロックの柔軟な表現 (`|` や `>`):** バナーメッセージや CLI コンフィグブロックを改行を保持したまま直感的に記述できる。

---

### 問 4 (実装 / Python スクリプト)
Python でネットワーク機器のコンフィグデータを定義した YAML ファイルを読み込む際、セキュリティ脆弱性（任意コード実行攻撃）を回避するために絶対に使用すべき PyYAML の関数名を答えなさい。

* **正解・解説:**
  * **正解関数:** `yaml.safe_load()`
  * **解説:** 従来の `yaml.load()` 関数はデフォルトで任意の Python オブジェクトをデシリアライズできるため、悪意のある YAML データに含まれる Python 実行可能オブジェクト（`!!python/object/apply`）を実行してしまう重大な脆弱性（RCE）が存在します。`yaml.safe_load()` は基本データ型（Dict, List, Str, Int, Bool）のみに解析を制限するため安全です。

---

### 問 5 (コンフィグ読解 / 真偽値と文字列)
以下の YAML 設定において、変数 `enable_dhcp` と `vlan_name` の型はそれぞれ Python 側でどのようにロードされるか答えなさい。

```yaml
---
settings:
  enable_dhcp: no
  vlan_name: "no"
```

* **正解・解説:**
  * `enable_dhcp`: **Boolean 型 (`False`)**。クォートなしの `no`, `off`, `false` は YAML 1.1/1.2 仕様に従いブール値 `False` に自動型変換されます。
  * `vlan_name`: **String 型 (`'no'`)**。ダブルクォートで括られているため、文字通りの文字列 `"no"` として評価されます。

---

### 問 6 (トラブルシューティング / タブ文字混入)
テキストエディタで Ansible Playbook を作成し実行したところ、以下のエラーが発生しました。このエラーが発生する根本原因と、エディタおよび CLI での対処方法を説明しなさい。

`yaml.scanner.ScannerError: found character '	' that cannot start any token`

* **正解・解説:**
  * **根本原因:** インデントにタブ文字（`	`）が含まれているため。YAML 標準規格により、構造インデントにタブ文字を使用することは固く禁止されています。
  * **CLI 対処方法:** `cat -A <file.yml>` でタブ文字（`^I`）を特定し、半角スペースに置換するか、`yamllint` ツールで不当インデントを検出して修正する。
  * **エディタ対処方法:** vim の場合は `.vimrc` に `set expandtab` および `set shiftwidth=2` を設定。VS Code の場合は `Editor: Insert Spaces` を有効化し、`Tab Size: 2` に指定する。

---

## 🔗 参考リソース

Cisco 公式ドキュメントおよび標準規格の参考リソースです。

* **Cisco Validated Design (CVD) & Automation Guides:**
  * [Cisco DevNet Learning Labs: Introduction to YAML]
  * [Cisco Ansible Network Automation Documentation]
  * [Cisco IOS XE Ansible Collection (`cisco.ios`)]
* **Standard Specifications:**
  * [YAML Official Website & Specification 1.2]
  * [PyYAML Documentation & Safety Guidelines]
  * [yamllint Documentation and Rule Definitions]
* **Cisco Live Presentations:**
  * [Cisco Live BRKDEV-1002 - Introduction to Network Automation with Ansible and YAML]
  * [Cisco Live DEVNET-2015 - Data Modeling and Structure with JSON and YAML]

---

## 📝 **補足（Notes）**

### 1. 学習メモ: Ansible と YAML インデントの構造対応

```text
[Ansible Playbook 構造]                  [YAML インデント表現]
Playbook (リスト) --------------------> - name: Play1
  ├─ Host/Vars ----------------------->   hosts: core_switches
  └─ Tasks (リスト) ------------------->   tasks:
       ├─ Task1 (辞書) ---------------->     - name: Task 1
       │    └─ Module/Args (辞書) ----->         cisco.ios.ios_vlan:
       │                                           vlan_id: 10
       └─ Task2 (辞書) ---------------->     - name: Task 2
                                                 cisco.ios.ios_vlan:
                                                   vlan_id: 20
```

### 2. 注意点チェックリスト
* [ ] インデントはすべて **半角スペース 2 個** で統一されているか？（タブ文字は厳禁）
* [ ] 文頭が `{{` で始まる変数は **ダブルクォート** で囲まれているか？
* [ ] コロン `:` およびハイフン `-` の直後に **半角スペース** が存在する通りか？
* [ ] Ansible 実行前に `ansible-playbook --syntax-check` および `yamllint` を通したか？
* [ ] Python スクリプトで読み込む際は `yaml.safe_load()` を使用しているか？

