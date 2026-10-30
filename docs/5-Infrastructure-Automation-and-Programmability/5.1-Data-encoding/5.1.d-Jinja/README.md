---
layout: default
title: 5.1.d-Jinja
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 4
---



# 5.1.d Jinja

## 📘 概要

Jinja2 は、Python 言語で広く実装されている強力で柔軟なオープンソースのテンプレートエンジン（Template Engine）です。ネットワーク自動化や Infrastructure as Code (IaC) の分野において、Ansible、Python (Nornir、NETMIKO、NAPALM)、および各種オーケストレーションツールと組み合わせて、動的で拡張性の高いコンフィグレーション（Cisco IOS XE、NX-OS、SD-WAN Feature Template など）や API リクエスト用データ（JSON、XML、YAML）を自動生成するための業界標準テクノロジーとして位置づけられています。

CCIE Enterprise Infrastructure (EI) v1.1 試験において、Jinja2 は「データ（データ構造モデル：YAML/JSON/Python 辞書）とロジック（コンフィグ生成構文）の分離」を実現するキーテクノロジーとして評価されます。静的なコンフィグファイルを各機器用に個別に作成・保守する従来の手法から脱却し、ネットワークパラメーター（IP アドレス、VLAN ID、BGP ASN、QoS ポリシーなど）を変数データとして独立して管理しながら、共通のコンフィグ構造を Jinja2 テンプレートとして抽象化する高度な自動化設計手法が問われます。

---

## 🔑 要点

Jinja2 テンプレートエンジンの主要な特徴、用途、利点、制限事項、および設計上の考慮事項を下表に整理します。

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | Python ベースのテキストテンプレートエンジン。変数展開 (`{{ }}`), 制御構文 (`{% %}`), 注釈 (`{# #}`), 組み込み・カスタムフィルタ (`\|`) をサポート。 |
| **用途** | Cisco IOS XE コンフィグの動的自動生成、Ansible プレイブックでのテンプレート適用 (`ansible.builtin.template`), REST API/RESTCONF 向け JSON/XML ペイロードの生成。 |
| **メリット** | 「データ (Data) とプレゼンテーション (Template) の完全分離」。コードの再利用性の向上、設定ミスの防止、条件分岐によるマルチベンダー・マルチモデル対応。 |
| **デメリット** | 複雑なテンプレートにおける可読性の低下 (Spaghetti Template 化)。テンプレート単体では構文検証 (Syntax Validation) が行われず、適用先の CLI/API でエラーとなるリスク。 |
| **対応環境** | Ansible Core/Automation Controller, Python 3.x (jinja2 パッケージ), Cisco Catalyst Center (DNA Center) テンプレートエディタ, Nornir, SaltStack。 |
| **制限事項** | テンプレート内での直接的なネットワーク通信や状態変更は不可能 (純粋なテキスト展開エンジン)。制御文内での変数スコープ (Scoping) 制御に固有のルールが存在。 |
| **設計上の注意点** | 空行 (Whitespace/Newline) やインデントの制御 (`trim_blocks`, `lstrip_blocks`, `+`/`-` 演算子)。複雑なビジネスロジックは Python/Ansible 側に寄せ、テンプレートはシンプルに維持。 |

---

## 🏗 動作原理

Jinja2 は、**「変数データ (Data Source)」** と **「テンプレート構文 (Jinja2 Template)」** の 2 つのインプットを受け取り、**「Jinja2 評価エンジン (Render Engine)」** を通して最終的な **「プレーンテキスト成果物 (Generated Configuration / Payload)」** を出力します。

```text
  +---------------------------+       +-----------------------------------+
  |   Data Source (Variables)  |       |     Jinja2 Template File (.j2)    |
  |  - YAML (host_vars/all.yml)|       |  - Structural Logic               |
  |  - JSON Payload            |       |  - Loops ({% for %})              |
  |  - Python Dictionary       |       |  - Conditionals ({% if %})        |
  +---------------------------+       +-----------------------------------+
                |                                       |
                +-------------------+-------------------+
                                    |
                                    v
                     +-----------------------------+
                     |    Jinja2 Render Engine     |
                     |   (Python / Ansible Engine) |
                     +-----------------------------+
                                    |
                                    v
                     +-----------------------------+
                     |   Generated Text Output     |
                     |  - Cisco IOS XE Config CLI  |
                     |  - RESTCONF JSON / XML      |
                     +-----------------------------+
```

### 1. 構文エレメント (Syntax Delimiters)

Jinja2 では、テキスト内に組み込まれる特殊なデリミタ (Delimiter) によって評価ルールが決定されます。

1. **`{{ ... }}` (Expressions / Variables):**  
   変数の値、式、またはフィルタを通した評価結果をテキストとして出力します。
   * 例: `hostname {{ host_name }}` $
ightarrow$ `hostname R1`
2. **`{% ... %}` (Statements / Control Structures):**  
   繰り返し文 (`for`)、条件分岐 (`if/elif/else`)、マクロ定義 (`macro`)、変数セット (`set`) などのロジックを実行します。テキストとして評価結果は直接出力されません。
   * 例: `{% if enable_bgp %} router bgp {{ bgp_asn }} {% endif %}`
3. **`{# ... #}` (Comments):**  
   テンプレート内のコメント記述用デリミタ。生成される最終テキストからは完全に除外されます。
   * 例: `{# This section configures OSPF interfaces #}`
4. **`# ...` / `## ...` (Line Statements):**  
   オプションで設定可能な行単位のステートメント構文。

### 2. フィルタ (Filters) とパイプライン処理

変数の後ろにパイプ記号 (`|`) を配置することで、変数の値を変換・加工してから出力できます。フィルタはチェーン (鎖状) に複数連結可能です。

```text
{{ variable | filter1 | filter2(arg) }}
```

* **`default(value)` / `d(value)`:** 変数が未定義の場合にデフォルト値を挿入。
* **`upper` / `lower` / `capitalize`:** 大文字・小文字変換。
* **`to_json` / `to_yaml` / `from_json` / `from_yaml`:** データ形式のパースおよび再シリアライズ。
* **`ipaddr` (Ansible Netcommon フィルタ):** IP アドレスの検証、サブネットマスク計算、ネットワークアドレス抽出。
* **`map` / `selectattr` / `rejectattr`:** 配列・辞書オブジェクトに対する高度な抽出・集計処理。

---

## ⚙ 動作シーケンス

Jinja2 テンプレートエンジンが変数を評価し、テキストを構築する内部シーケンスは以下のステップで処理されます。

```text
[Step 1: Data & Template Loading]
  Ansible / Python が YAML/JSON データおよび .j2 テンプレートファイルを読み込み、内部メモリへロード。
        ↓
[Step 2: Template Parsing & AST Generation]
  Jinja2 エンジンがテンプレート内のデリミタ ({{ }}, {% %}) をスキャンし、抽象構文木 (AST: Abstract Syntax Tree) を構築。
        ↓
[Step 3: Context Binding & Evaluation]
  渡された変数 (Context) を AST にバインドし、{% for %} ループの反復処理や {% if %} 条件文を上から順に評価。
        ↓
[Step 4: Filter Execution Pipeline]
  パイプ記号 (|) で接続されたフィルタ関数を適用し、文字列操作、IP アドレス計算、フォーマット変換を順次実行。
        ↓
[Step 5: Whitespace & Newline Trimming]
  trim_blocks / lstrip_blocks 設定および -/x 制御文字に基づき、余分なインデントや改行コードを自動削除・微調整。
        ↓
[Step 6: Text Rendering & Output Delivery]
  レンダリングされた最終文字列を生成し、CLI コンフィグバッファ、ファイル、または RESTCONF/NETCONF API モジュールへ引き渡し。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験（Section 2: Automation and Programmability）における Jinja2 出題ポイントおよび不合格に直結する落とし穴を整理します。

### 1. ラボ試験で頻出・重要となるポイント

1. **空白・改行制御 (Whitespace / Newline Control):**  
   Jinja2 のデフォルト動作では、`{% ... %}` 制御ブロックが配置された行は「空行 (Empty Line)」としてそのまま出力されます。Cisco IOS XE コンフィグにおいて不必要な空行が大量に生成されたり、インデントがずれると、CLI 適用時に不要な警告やコンミットエラーの原因となります。  
   * **`-` 記号の制御:**  
     `{%- ... %}` : ブロックより**前**の空白・改行を削除。  
     `{% ... -%}` : ブロックより**後**の空白・改行を削除。
2. **ループ処理におけるループ変数の活用 (`loop.index`, `loop.first`, `loop.last`):**  
   `{% for %}` ループ内で特殊変数 `loop` を使いこなし、リストの先頭・末尾・インデックスに応じた条件分岐を行う記述力が求められます。
   * `loop.index` (1 開始) / `loop.index0` (0 開始)
   * `loop.first` (最初の要素の時 `true`)
   * `loop.last` (最後の要素の時 `true`)
3. **変数スコープ (Scoping) と `namespace` の使用:**  
   Jinja2 2.10 以降では、`{% for %}` ループ内部で `{% set %}` した変数は**ループの外部へ引き継がれません (Block Scope)**。ループ内で変数を集計・追記する場合は `{% set ns = namespace(found=false) %}` を宣言し、`{% set ns.found = true %}` のようにアサインする必要があります。
4. **Ansible 統合におけるフィルタの活用:**  
   * `ipaddr('address')` / `ipaddr('netmask')` / `ipaddr('network')` による CIDR 記法からの動的アドレス分解。
   * `default('omit')` や `selectattr()` による柔軟な変数パース。

---

## 🛠 設定方法

### 1. Jinja2 テンプレートの基本文法構造

以下に、Cisco IOS XE 向け代表的コンフィグ生成 Jinja2 テンプレートの基本記法を示します。

```jinja2
{# ========================================== #}
{# Cisco IOS XE Base Interface & OSPF Template #}
{# ========================================== #}
hostname {{ host_name | default('ROUTER-DEFAULT') | upper }}

{% if domain_name is defined %}
ip domain name {{ domain_name }}
{% endif %}

{% for intf in interfaces -%}
{% if intf.enabled | default(true) %}
interface {{ intf.name }}
 description {{ intf.description | default('Configured via Automation') }}
 ip address {{ intf.ip_address }} {{ intf.netmask }}
 {% if intf.ospf is defined and intf.ospf.enabled %}
 ip ospf {{ intf.ospf.process_id }} area {{ intf.ospf.area }}
  {% if intf.ospf.network_type is defined %}
 ip ospf network {{ intf.ospf.network_type }}
  {% endif %}
 {% endif %}
 no shutdown
!
{% endif %}
{% endfor -%}

router ospf {{ ospf_process_id | default(1) }}
 router-id {{ router_id }}
{% if ospf_passive_interfaces is defined %}
{% for pass_intf in ospf_passive_interfaces %}
 passive-interface {{ pass_intf }}
{% endfor %}
{% endif %}
```

### 2. Python における Jinja2 レンダリング実装 (jinja2 Library)

```python
from jinja2 import Environment, FileSystemLoader
import yaml

# 1. 変数データ (YAML) の読み込み
with open('host_vars/R1.yml', 'r', encoding='utf-8') as f:
    var_data = yaml.safe_load(f)

# 2. Jinja2 環境のセットアップ
env = Environment(
    loader=FileSystemLoader(searchpath='./templates'),
    trim_blocks=True,      # 制御文直後の改行を自動削除
    lstrip_blocks=True     # 制御文行の先頭空白行を自動削除
)

# 3. テンプレートのロードとレンダリング
template = env.get_template('ios_config.j2')
rendered_config = template.render(var_data)

print(rendered_config)
```

---

## 🔍 検証コマンド

Jinja2 テンプレート自体の検証、および Ansible / Python 経由でのレンダリング結果の確認コマンド・手法を下表に整理します。

| 目的 | コマンド / 手法 | 説明 |
| :--- | :--- | :--- |
| **Ansible テンプレート試行** | `ansible-playbook site.yml --check --diff` | ドライラン（試行実行）を行い、生成されたコンフィグと実機コンフィグの差分を表示。 |
| **Ansible レンダリング確認** | `ansible localhost -m template -a "src=templates/ios.j2 dest=/tmp/out.cfg" -e "@vars.yml"` | プレイブック全体を実行せずに、ローカル環境で Jinja2 テンプレートの展開結果をデバッグ出力。 |
| **Ansible デバッグ出力** | `- name: Debug Rendered Template`<br>  `ansible.builtin.debug:`<br>    `msg: "{{ lookup('template', 'templates/ios.j2') }}"` | プレイブック実行中にメモリ上でレンダリングされたコンフィグ文字列を画面上に表示。 |
| **Python CLI 検証** | `python3 -c "import jinja2, yaml; print(jinja2.Template(open('t.j2').read()).render(yaml.safe_load(open('v.yml'))))"` | 1 行の Python スクリプトで Jinja2 テンプレートと YAML 変数のレンダリング結果をクイック検証。 |
| **Ansible jinja2 構文チェック** | `ansible-lint site.yml` | Ansible Playbook 内の Jinja2 変数展開構文や非推奨フィルタの自動検出。 |

---

## 🚨 トラブルシューティング

Jinja2 導入およびレンダリング時に発生する典型的な障害原因と対処法をまとめます。

| 症状 / エラーメッセージ | 原因 | 確認・特定方法 | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`UndefinedError: 'dict object' has no attribute 'x'`** | テンプレートで参照している変数・属性が YAML/JSON データ内に存在しない。 | データ構造 (YAML) を確認し、キー名のスペルミスや階層のズレを特定。 | `default()` フィルタを適用 (`{{ item.x | default('N/A') }}`) するか、`{% if item.x is defined %}` で保護。 |
| **`TemplateSyntaxError: unexpected 'endfor'`** | `{% for %}` ブロックの閉じタグ構文エラー、または `{% if %}` の閉じ忘れ。 | エラーログに表示されたテンプレートの行番号を確認。 | `{% endfor %}` または `{% endif %}` のタグ対応を正しく修復。 |
| **生成された CLI コンフィグに不要な空行やズレが大量に発生する** | `{% ... %}` 制御ブロックの改行がそのままテキスト出力されている。 | 生成された成果物ファイル (`.cfg`) の改行位置をテキストエディタで確認。 | 制御タグに `-` を付与 (`{%-` / `-%}`) するか、Python 側で `trim_blocks=True`, `lstrip_blocks=True` を有効化。 |
| **ループ内で更新した変数がループ外で消える** | Jinja2 の変数スコープ制限 (Block Scoping)。 | `{% set var = val %}` を `{% for %}` 内で実行後、ループ外で `{{ var }}` を参照。 | `{% set ns = namespace(val=initial) %}` をループ外で宣言し、ループ内で `{% set ns.val = new_val %}` と更新。 |
| **`FilterError: netcommon ipaddr filter failed`** | `ipaddr` フィルタ適用時に手元の Python 環境に `netaddr` ライブラリがない。 | `python3 -c "import netaddr"` を実行してエラーを吐くか確認。 | コントロールノードで `pip install netaddr` を実行してライ component をインストール。 |

---

## ⚠ 制限事項

1. **Jinja2 自体は「ステートレスな文字列生成器」:**  
   Jinja2 はネットワーク機器への通信、SSH 接続、API 実行、コンフィグ適用機能を一切持ちません。生成されたテキストをどのように機器へ反映させるかは、Ansible (`cisco.ios.ios_config`) や Python (`netmiko` / `requests`) 側の責務となります。
2. **テンプレート内の複雑なロジック処理制限:**  
   Jinja2 内部で高度な計算、複雑な正規表現パース、外部 DB 検索などを行うと、テンプレートが非人間的な可読性（Spaghetti Code）となり保守が不可能になります。データ整形やビジネスロジックは Python スクリプトや Ansible Filter Plugin に集約すべきです。

---

## 🔄 他技術との関連

* **YAML / JSON データ形式 (Blueprint 5.1.a / 5.1.c):**  
  Jinja2 が処理する変数構造の記述形式。YAML のリスト（`-`）や辞書（`key: val`）が Jinja2 の `{% for %}` や `{{ dict.key }}` に直接対応します。
* **Ansible (Blueprint 5.5):**  
  `ansible.builtin.template` モジュールにより、Jinja2 テンプレートを読み込んで機器へコンフィグを自動生成・適用します。
* **RESTCONF / NETCONF (Blueprint 5.4):**  
  CLI コンフィグだけでなく、RESTCONF 用の JSON ペイロードや NETCONF 用の XML ペイロードを Jinja2 テンプレートを用いて動的に組み立てることが可能です。

---

## 🧩 比較表

### 1. Jinja2 (テンプレート生成) vs Python F-Strings / String Formatting

| 比較項目 | Jinja2 テンプレート (`.j2`) | Python F-Strings / `%` フォーマット |
| :--- | :--- | :--- |
| **構造の分離** | **完全分離** (データ: YAML, ロジック: .j2) | **密結合** (Python コード内にコンフィグ文字列が混在) |
| **可読性** | 高い (CLI コンフィグの形そのままに記述可能) | 低い (多重引用符やインデントのエスケープが繁雑) |
| **保守性・再利用性** | 非常に高い (テンプレートを他プロジェクトで再利用可) | 低い (Python スクリプトごとにコード修正が必要) |
| **機能性** | ループ、条件分岐、各種変換フィルタが豊富 | 基本的な変数埋め込みと文字操作のみ |
| **適合ユースケース** | エンタープライズ大規模自動化、Ansible / Catalyst Center | 小規模スクリプト、簡単なワンライナー処理 |

---

## 💡 ベストプラクティス

1. **制御ブロックの空白処理の徹底:**  
   制御文には必ず `-` 制御記号 (`{%-` または `-%}`) を適用するか、Ansible / Python 側で `trim_blocks: yes`, `lstrip_blocks: yes` を設定し、無駄な空行を出力しない。
2. **デフォルト値の明示 (`default` フィルタ):**  
   オプショナルなパラメーター（例: Interface Description, OSPF Cost など）には `{{ intf.desc | default('Managed by Automation') }}` のように必ずデフォルト値を準備し、変数の定義漏れによる `UndefinedError` で自動化パイプラインが停止するのを防止する。
3. **ヘッダーコメントとバージョン管理:**  
   テンプレートの冒頭には `{# Template Name: ios_xe_bgp.j2, Last Updated: 2026-10-30 #}` のようにコメントを記載し、Git で一元管理する。

## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルの実戦的な Jinja2 サンプルシナリオを 10 個提示します。各サンプルには、背景問題、要件、入力変数 (YAML/JSON)、Jinja2 テンプレート (.j2)、出力結果、および検証方法が含まれます。

---

### 🧪 ラボ 1: インターフェイス ＆ IP アドレス動的自動生成

#### 問題
拠点ルータ R1 の複数物理インターフェイスおよび Loopback インターフェイスの設定を、手動入力ミスを防ぐために Jinja2 テンプレートで動的生成したい。

#### 要件
1. インターフェイスが `enabled: false` の場合は `shutdown` を出力し、`true` の場合は `no shutdown` を出力すること。
2. Description が未定義の場合はデフォルト値 `Configured by Automation` を代入すること。
3. `interfaces` リスト変数をループで回して生成すること。

#### 変数定義 (`host_vars/R1.yml`)
```yaml
host_name: "R1-EDGE"
interfaces:
  - name: "GigabitEthernet1"
    description: "WAN Uplink to ISP-A"
    ip_address: "192.168.1.1"
    netmask: "255.255.255.252"
    enabled: true
  - name: "GigabitEthernet2"
    ip_address: "10.1.10.1"
    netmask: "255.255.255.0"
    enabled: true
  - name: "GigabitEthernet3"
    description: "Reserved for Future Use"
    ip_address: "10.1.20.1"
    netmask: "255.255.255.0"
    enabled: false
  - name: "Loopback0"
    description: "Router Management IP"
    ip_address: "1.1.1.1"
    netmask: "255.255.255.255"
    enabled: true
```

#### Jinja2 テンプレート (`templates/interfaces.j2`)
```jinja2
hostname {{ host_name }}
!
{% for intf in interfaces -%}
interface {{ intf.name }}
 description {{ intf.description | default('Configured by Automation') }}
 ip address {{ intf.ip_address }} {{ intf.netmask }}
{% if intf.enabled %}
 no shutdown
{% else %}
 shutdown
{% endif %}
!
{% endfor -%}
```

#### レンダリング出力結果
```text
hostname R1-EDGE
!
interface GigabitEthernet1
 description WAN Uplink to ISP-A
 ip address 192.168.1.1 255.255.255.252
 no shutdown
!
interface GigabitEthernet2
 description Configured by Automation
 ip address 10.1.10.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet3
 description Reserved for Future Use
 ip address 10.1.20.1 255.255.255.0
 shutdown
!
interface Loopback0
 description Router Management IP
 ip address 1.1.1.1 255.255.255.255
 no shutdown
!
```

#### 検証方法
`python3 -c "import jinja2, yaml; print(jinja2.Template(open('templates/interfaces.j2').read()).render(yaml.safe_load(open('host_vars/R1.yml'))))"` を実行し、GigabitEthernet2 にデフォルト Description が設定され、GigabitEthernet3 が `shutdown` になっていることを確認する。

---

### 🧪 ラボ 2: 条件分岐 (`{% if %}`) による ルーティングプロトコル自動選択

#### 問題
拠点ルータの種類に応じて、OSPF プロセスまたは BGP プロセスを選択的に動的生成する汎用ルーティングテンプレートを作成する。

#### 要件
1. `routing.protocol` が `ospf` の場合、OSPF プロセス、Router-ID、Area 設定を出力すること。
2. `routing.protocol` が `bgp` の場合、BGP ASN、Router-ID、Neighbor 設定を出力すること。
3. `passive_interfaces` が定義されている場合は、OSPF プロセス配下にパッシブ設定を出力すること。

#### 変数定義 (`host_vars/R2.yml`)
```yaml
host_name: "R2-BRANCH"
routing:
  protocol: "ospf"
  process_id: 10
  router_id: "2.2.2.2"
  areas:
    - id: "0"
      networks:
        - prefix: "10.2.0.0"
          wildcard: "0.0.255.255"
        - prefix: "2.2.2.2"
          wildcard: "0.0.0.0"
  passive_interfaces:
    - "GigabitEthernet2"
    - "GigabitEthernet3"
```

#### Jinja2 テンプレート (`templates/routing.j2`)
```jinja2
hostname {{ host_name }}
!
{% if routing.protocol == 'ospf' -%}
router ospf {{ routing.process_id }}
 router-id {{ routing.router_id }}
{% if routing.passive_interfaces is defined -%}
{% for pass_intf in routing.passive_interfaces -%}
 passive-interface {{ pass_intf }}
{% endfor -%}
{% endif -%}
{% for area in routing.areas -%}
{% for net in area.networks -%}
 network {{ net.prefix }} {{ net.wildcard }} area {{ area.id }}
{% endfor -%}
{% endfor -%}
{% elif routing.protocol == 'bgp' -%}
router bgp {{ routing.bgp_asn }}
 bgp router-id {{ routing.router_id }}
 bgp log-neighbor-changes
{% for nbr in routing.neighbors -%}
 neighbor {{ nbr.ip }} remote-as {{ nbr.remote_as }}
 neighbor {{ nbr.ip }} description {{ nbr.description | default('BGP Peer') }}
{% endfor -%}
{% endif -%}
```

#### レンダリング出力結果
```text
hostname R2-BRANCH
!
router ospf 10
 router-id 2.2.2.2
 passive-interface GigabitEthernet2
 passive-interface GigabitEthernet3
 network 10.2.0.0 0.0.255.255 area 0
 network 2.2.2.2 0.0.0.0 area 0
```

#### 検証方法
`routing.protocol: "bgp"` に書き換えた別変数ファイルを準備し、同テンプレートをレンダリングした際に `router bgp` ブロックが正しく生成されるかロジックの汎用性を検証する。

---

### 🧪 ラボ 3: 多重ループ (`{% for %}`) による VLAN ＆ Trunk 許可 VLAN 自動生成

#### 問題
Catalyst スイッチ群に対して、VLAN データベースおよび Trunk インターフェイスの `switchport trunk allowed vlan` 設定をネストされたループ構文で一括自動展開したい。

#### 要件
1. `vlans` リストから各 VLAN ID と VLAN 名を生成すること。
2. Trunk インターフェイスの `allowed_vlans` リストをカンマ区切りの文字列へ変換して出力すること (`join` フィルタの活用)。

#### 変数定義 (`host_vars/SW1.yml`)
```yaml
host_name: "SW1-ACCESS"
vlans:
  - id: 10
    name: "DATA_USERS"
  - id: 20
    name: "VOICE_PHONES"
  - id: 30
    name: "WIRELESS_GUEST"
  - id: 99
    name: "NATIVE_MGMT"
trunk_interfaces:
  - name: "GigabitEthernet1/0/47"
    description: "Trunk to Distribution SW1"
    native_vlan: 99
    allowed_vlans: [10, 20, 30, 99]
  - name: "GigabitEthernet1/0/48"
    description: "Trunk to Distribution SW2"
    native_vlan: 99
    allowed_vlans: [10, 20, 99]
```

#### Jinja2 テンプレート (`templates/vlan_trunk.j2`)
```jinja2
hostname {{ host_name }}
!
{# VLAN Database Definition #}
{% for vlan in vlans -%}
vlan {{ vlan.id }}
 name {{ vlan.name }}
!
{% endfor -%}
!
{# Trunk Interfaces Definition #}
{% for intf in trunk_interfaces -%}
interface {{ intf.name }}
 description {{ intf.description }}
 switchport mode trunk
 switchport trunk native vlan {{ intf.native_vlan }}
 switchport trunk allowed vlan {{ intf.allowed_vlans | join(',') }}
 no shutdown
!
{% endfor -%}
```

#### レンダリング出力結果
```text
hostname SW1-ACCESS
!
vlan 10
 name DATA_USERS
!
vlan 20
 name VOICE_PHONES
!
vlan 30
 name WIRELESS_GUEST
!
vlan 99
 name NATIVE_MGMT
!
!
interface GigabitEthernet1/0/47
 description Trunk to Distribution SW1
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,30,99
 no shutdown
!
interface GigabitEthernet1/0/48
 description Trunk to Distribution SW2
 switchport mode trunk
 switchport trunk native vlan 99
 switchport trunk allowed vlan 10,20,99
 no shutdown
!
```

#### 検証方法
`allowed_vlans` のリストが `join(',')` フィルタにより、Cisco IOS XE CLI が要求する `10,20,30,99` 形式のカンマ区切り文字列に正しく展開されているか確認する。

---

### 🧪 ラボ 4: `ipaddr` フィルタを用いた CIDR 計算とサブネット分解

#### 問題
`192.168.10.1/24` のような CIDR 形式で渡された IP アドレス情報から、Jinja2 フィルタを用いて IP アドレス本体、サブネットマスク、およびワイルドカードマスクを自動分解・計算して出力する。

#### 要件
1. CIDR アドレスから `ipaddr('address')` で IP アドレス部を抽出すること。
2. CIDR アドレスから `ipaddr('netmask')` でドット 10 制度サブネットマスクを抽出すること。
3. OSPF 設定用に `ipaddr('wildcard')` でワイルドカードマスクを動的計算すること。

#### 変数定義 (`host_vars/R3.yml`)
```yaml
host_name: "R3-CORE"
interface_cidr: "10.50.100.1/26"
ospf_area: "0"
```

#### Jinja2 テンプレート (`templates/cidr_calc.j2`)
```jinja2
hostname {{ host_name }}
!
interface GigabitEthernet0/0/0
 description Core Interface calculated via ipaddr filter
 ip address {{ interface_cidr | ipaddr('address') }} {{ interface_cidr | ipaddr('netmask') }}
 no shutdown
!
router ospf 1
 network {{ interface_cidr | ipaddr('network') }} {{ interface_cidr | ipaddr('wildcard') }} area {{ ospf_area }}
```

#### レンダリング出力結果
```text
hostname R3-CORE
!
interface GigabitEthernet0/0/0
 description Core Interface calculated via ipaddr filter
 ip address 10.50.100.1 255.255.255.192
 no shutdown
!
router ospf 1
 network 10.50.100.0 0.0.0.63 area 0
```

#### 検証方法
`/26` サブネット（255.255.255.192）に対するワイルドカードマスクが `0.0.0.63` に正しく動的計算されてレンダリング出力されるか検証する（Ansible コントロールノードで `python3-netaddr` モジュールが要インストール）。

---

### 🧪 ラボ 5: 変数スコープ (`namespace`) によるループ内状態維持

#### 問題
複数インターフェイスの設定ループ処理の中で、特定条件（アクティブなインターフェイス数）を集計し、ループ終了後にその結果をサマリーとしてコンフィグコメントに反映する。

#### 要件
1. `namespace` オブジェクトを使用して、`{% for %}` ループの内部で更新したカウンターをループ外部へ持ち出すこと。
2. `enabled: true` の物理ポート数および `Loopback` ポート数をカウントすること。

#### 変数定義 (`host_vars/R4.yml`)
```yaml
host_name: "R4-AGG"
ports:
  - name: "GigabitEthernet1"
    type: "physical"
    enabled: true
  - name: "GigabitEthernet2"
    type: "physical"
    enabled: false
  - name: "GigabitEthernet3"
    type: "physical"
    enabled: true
  - name: "Loopback0"
    type: "logical"
    enabled: true
  - name: "Loopback1"
    type: "logical"
    enabled: true
```

#### Jinja2 テンプレート (`templates/namespace_scope.j2`)
```jinja2
hostname {{ host_name }}
!
{# Namespace オブジェクトの宣言 #}
{% set ns = namespace(physical_cnt=0, logical_cnt=0) %}
!
{% for p in ports -%}
{% if p.enabled -%}
{% if p.type == 'physical' -%}
  {% set ns.physical_cnt = ns.physical_cnt + 1 -%}
{% elif p.type == 'logical' -%}
  {% set ns.logical_cnt = ns.logical_cnt + 1 -%}
{% endif -%}
interface {{ p.name }}
 no shutdown
!
{% endif -%}
{% endfor -%}
!
{# ループ外部での集計結果出力 #}
! Summary: Active Physical Ports = {{ ns.physical_cnt }}, Active Logical Ports = {{ ns.logical_cnt }}
```

#### レンダリング出力結果
```text
hostname R4-AGG
!
interface GigabitEthernet1
 no shutdown
!
interface GigabitEthernet3
 no shutdown
!
interface Loopback0
 no shutdown
!
interface Loopback1
 no shutdown
!
!
! Summary: Active Physical Ports = 2, Active Logical Ports = 2
```

#### 検証方法
Jinja2 の Block Scope 制約を回避するために `namespace()` オブジェクトが使用され、ループ終了後のサマリー行に正確なカウント数値（Physical = 2, Logical = 2）が出力されているか確認する。

---

### 🧪 ラボ 6: QoS MQC (Class-Map / Policy-Map) テンプレート化

#### 問題
企業標準の QoS MQC パイプライン (Class-Map / Policy-Map) を Jinja2 テンプレート化し、拠点ルータの出口帯域（Shaping Rate）に応じた分類・帯域制御コンフィグを自動生成する。

#### 要件
1. Class-Map の DSCP マッチ条件を自動生成すること。
2. Policy-Map 内で Priority Queue (LLQ) および Bandwidth Remaining (CBWFQ) を正しく設定すること。
3. 出口 WAN インターフェイスへの Parent Policy (`shape average`) アタッチ設定を出力すること。

#### 変数定義 (`host_vars/R5.yml`)
```yaml
host_name: "R5-WAN"
wan_interface: "GigabitEthernet0/0/1"
shaping_rate_bps: 100000000  # 100 Mbps
qos_classes:
  - name: "VOICE_CLASS"
    match_dscp: ["ef"]
    priority_percent: 20
  - name: "VIDEO_CLASS"
    match_dscp: ["af41", "af42"]
    bandwidth_percent: 30
  - name: "CALL_SIGNALING"
    match_dscp: ["cs3"]
    bandwidth_percent: 10
```

#### Jinja2 テンプレート (`templates/qos_mqc.j2`)
```jinja2
hostname {{ host_name }}
!
{# 1. Define Class-Maps #}
{% for qclass in qos_classes -%}
class-map match-any CM_{{ qclass.name }}
{% for dscp in qclass.match_dscp -%}
 match ip dscp {{ dscp }}
{% endfor -%}
!
{% endfor -%}
!
{# 2. Define Child Policy-Map #}
policy-map PM_CHILD_QOS
{% for qclass in qos_classes -%}
 class CM_{{ qclass.name }}
{% if qclass.priority_percent is defined -%}
  priority percent {{ qclass.priority_percent }}
{% elif qclass.bandwidth_percent is defined -%}
  bandwidth remaining percent {{ qclass.bandwidth_percent }}
{% endif -%}
{% endfor -%}
 class class-default
  fair-queue
!
{# 3. Define Parent Policy-Map #}
policy-map PM_PARENT_WAN
 class class-default
  shape average {{ shaping_rate_bps }}
  service-policy PM_CHILD_QOS
!
{# 4. Apply to Interface #}
interface {{ wan_interface }}
 service-policy output PM_PARENT_WAN
```

#### レンダリング出力結果
```text
hostname R5-WAN
!
class-map match-any CM_VOICE_CLASS
 match ip dscp ef
!
class-map match-any CM_VIDEO_CLASS
 match ip dscp af41
 match ip dscp af42
!
class-map match-any CM_CALL_SIGNALING
 match ip dscp cs3
!
policy-map PM_CHILD_QOS
 class CM_VOICE_CLASS
  priority percent 20
 class CM_VIDEO_CLASS
  bandwidth remaining percent 30
 class CM_CALL_SIGNALING
  bandwidth remaining percent 10
 class class-default
  fair-queue
!
policy-map PM_PARENT_WAN
 class class-default
  shape average 100000000
  service-policy PM_CHILD_QOS
!
interface GigabitEthernet0/0/1
 service-policy output PM_PARENT_WAN
```

#### 検証方法
Class-Map 内で複数 DSCP マッチ条件がネストして展開され、Child Policy 内で `priority` と `bandwidth remaining` が適切に分岐処理されているか確認する。

---

### 🧪 ラボ 7: BGP Dynamic Peer Group ＆ Neighbor テンプレート展開

#### 問題
データセンター Core ルータにおいて、Peer-Group テンプレートと個別の iBGP / eBGP ネイバー設定を Jinja2 で一括動的生成する。

#### 要件
1. BGP Autonomous System 番号および Router-ID を動的にアサインすること。
2. Peer-Group 設定を出力し、各 Neighbor で参照すること。
3. `route_map_in` や `route_map_out` が定義されている場合のみ適用構文を出力すること。

#### 変数定義 (`host_vars/DC1-R1.yml`)
```yaml
host_name: "DC1-R1"
bgp_asn: 65001
router_id: "10.255.255.1"
peer_groups:
  - name: "SPINE_PEERS"
    remote_as: 65001
    update_source: "Loopback0"
bgp_neighbors:
  - ip: "10.255.255.2"
    peer_group: "SPINE_PEERS"
    description: "Spoke-2 Loopback"
  - ip: "192.168.254.1"
    remote_as: 65002
    description: "eBGP to External ISP"
    route_map_in: "RM_ISP_IN"
    route_map_out: "RM_ISP_OUT"
```

#### Jinja2 テンプレート (`templates/bgp_peers.j2`)
```jinja2
hostname {{ host_name }}
!
router bgp {{ bgp_asn }}
 bgp router-id {{ router_id }}
 bgp log-neighbor-changes
!
{# Define Peer Groups #}
{% for pg in peer_groups -%}
 neighbor {{ pg.name }} peer-group
 neighbor {{ pg.name }} remote-as {{ pg.remote_as }}
{% if pg.update_source is defined -%}
 neighbor {{ pg.name }} update-source {{ pg.update_source }}
{% endif -%}
!
{% endfor -%}
{# Define Neighbors #}
{% for nbr in bgp_neighbors -%}
 neighbor {{ nbr.ip }} description {{ nbr.description }}
{% if nbr.peer_group is defined -%}
 neighbor {{ nbr.ip }} peer-group {{ nbr.peer_group }}
{% else -%}
 neighbor {{ nbr.ip }} remote-as {{ nbr.remote_as }}
{% endif -%}
{% if nbr.route_map_in is defined -%}
 neighbor {{ nbr.ip }} route-map {{ nbr.route_map_in }} in
{% endif -%}
{% if nbr.route_map_out is defined -%}
 neighbor {{ nbr.ip }} route-map {{ nbr.route_map_out }} out
{% endif -%}
!
{% endfor -%}
```

#### レンダリング出力結果
```text
hostname DC1-R1
!
router bgp 65001
 bgp router-id 10.255.255.1
 bgp log-neighbor-changes
!
 neighbor SPINE_PEERS peer-group
 neighbor SPINE_PEERS remote-as 65001
 neighbor SPINE_PEERS update-source Loopback0
!
 neighbor 10.255.255.2 description Spoke-2 Loopback
 neighbor 10.255.255.2 peer-group SPINE_PEERS
!
 neighbor 192.168.254.1 description eBGP to External ISP
 neighbor 192.168.254.1 remote-as 65002
 neighbor 192.168.254.1 route-map RM_ISP_IN in
 neighbor 192.168.254.1 route-map RM_ISP_OUT out
!
```

#### 検証方法
iBGP Peer-Group 経由のネイバーと、直接 `remote-as` を定義する eBGP ネイバーの両パターンが、Jinja2 の `{% if nbr.peer_group is defined %}` 条件分岐により正確にコンフィグ分離展開されるか確認する。

---

### 🧪 ラボ 8: RESTCONF 用 JSON ペイロード動的生成テンプレート

#### 問題
Jinja2 テンプレートを使用して Cisco IOS XE RESTCONF API（`ietf-interfaces:interfaces`）に PATCH 送信するための JSON データ構造ペイロードを動的に生成する。

#### 要件
1. 有効な JSON 構造を出力すること（ダブルクォートの厳格適用、末尾カンマの排除）。
2. インターフェイス名、IP アドレス、サブネットマスク、状態（Boolean）を変数から動的に埋め込むこと。

#### 変数定義 (`host_vars/restconf_var.yml`)
```yaml
intf_name: "GigabitEthernet2"
intf_desc: "Configured via RESTCONF Jinja2 Payload"
ip_addr: "172.16.100.1"
netmask: "255.255.255.0"
is_enabled: true
```

#### Jinja2 テンプレート (`templates/restconf_interface.json.j2`)
```jinja2
{
  "ietf-interfaces:interface": {
    "name": "{{ intf_name }}",
    "description": "{{ intf_desc }}",
    "type": "iana-if-type:ethernetCsmacd",
    "enabled": {{ is_enabled | lower }},
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "{{ ip_addr }}",
          "netmask": "{{ netmask }}"
        }
      ]
    }
  }
}
```

#### レンダリング出力結果
```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet2",
    "description": "Configured via RESTCONF Jinja2 Payload",
    "type": "iana-if-type:ethernetCsmacd",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "172.16.100.1",
          "netmask": "255.255.255.0"
        }
      ]
    }
  }
}
```

#### 検証方法
`is_enabled: true` が Python/YAML の大文字 `True` ではなく、Jinja2 フィルタ `lower` により JSON 規格適合の小文字 `true`（クォートなしの Boolean）として正しくレンダリングされているか、Python `json.loads()` を通して妥当性を検証する。

---

### 🧪 ラボ 9: NETCONF 用 XML ペイロード動的生成テンプレート

#### 問題
NETCONF `<edit-config>` 操作用に、Cisco Native YANG スキーマに適合する XML コンフィグレーションペイロードを Jinja2 テンプレートで構築する。

#### 要件
1. 正しい XML ネームスペース (`xmlns="urn:cisco:params:xml:ns:yang:Cisco-IOS-XE-native"`) を含めること。
2. `<Loopback>` インターフェイスの `<name>` および `<ip><address><primary>` 構造を正確に組み込むこと。

#### 変数定義 (`host_vars/netconf_var.yml`)
```yaml
loopback_id: "100"
ip_address: "10.255.100.1"
netmask: "255.255.255.255"
```

#### Jinja2 テンプレート (`templates/netconf_loopback.xml.j2`)
```jinja2
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="urn:cisco:params:xml:ns:yang:Cisco-IOS-XE-native">
    <interface>
      <Loopback>
        <name>{{ loopback_id }}</name>
        <ip>
          <address>
            <primary>
              <address>{{ ip_address }}</address>
              <mask>{{ netmask }}</mask>
            </primary>
          </address>
        </ip>
      </Loopback>
    </interface>
  </native>
</config>
```

#### レンダリング出力結果
```xml
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="urn:cisco:params:xml:ns:yang:Cisco-IOS-XE-native">
    <interface>
      <Loopback>
        <name>100</name>
        <ip>
          <address>
            <primary>
              <address>10.255.100.1</address>
              <mask>255.255.255.255</mask>
            </primary>
          </address>
        </ip>
      </Loopback>
    </interface>
  </native>
</config>
```

#### 検証方法
Python `ncclient` ライブラリの `m.edit_config(target='running', config=rendered_xml)` へ直接引き渡し、NETCONF サーバーから `<ok/>` レスポンスが返却されることを検証する。

---

### 🧪 ラボ 10: Multi-VRF ＆ Subinterface 一括自動展開

#### 問題
サービスプロバイダ・マルチテナント網向けに、VRF 定義、802.1Q サブインターフェイス、VRF バインド、IP アドレス設定を一括動的生成する大規模型テンプレートを作成する。

#### 要件
1. `vrfs` リストから `vrf definition <NAME>`、RD (Route Distinguisher)、および Route-Target (Import/Export) を出力すること。
2. 各サブインターフェイスに対して `encapsulation dot1Q <VLAN_ID>` および `vrf forwarding <NAME>` を順次割り当てること。

#### 変数定義 (`host_vars/PE1.yml`)
```yaml
host_name: "PE1-ROUTER"
vrfs:
  - name: "TENANT_A"
    rd: "65000:100"
    rt_import: "65000:100"
    rt_export: "65000:100"
  - name: "TENANT_B"
    rd: "65000:200"
    rt_import: "65000:200"
    rt_export: "65000:200"
subinterfaces:
  - physical_intf: "GigabitEthernet0/0/2"
    sub_id: 100
    vlan_id: 100
    vrf_name: "TENANT_A"
    ip_address: "10.100.1.1"
    netmask: "255.255.255.0"
  - physical_intf: "GigabitEthernet0/0/2"
    sub_id: 200
    vlan_id: 200
    vrf_name: "TENANT_B"
    ip_address: "10.200.1.1"
    netmask: "255.255.255.0"
```

#### Jinja2 テンプレート (`templates/multi_vrf.j2`)
```jinja2
hostname {{ host_name }}
!
{# 1. Configure VRF Definitions #}
{% for vrf in vrfs -%}
vrf definition {{ vrf.name }}
 rd {{ vrf.rd }}
 !
 address-family ipv4
  route-target import {{ vrf.rt_import }}
  route-target export {{ vrf.rt_export }}
 exit-address-family
!
{% endfor -%}
!
{# 2. Configure Subinterfaces #}
{% for sub in subinterfaces -%}
interface {{ sub.physical_intf }}.{{ sub.sub_id }}
 description Subinterface for {{ sub.vrf_name }}
 encapsulation dot1Q {{ sub.vlan_id }}
 vrf forwarding {{ sub.vrf_name }}
 ip address {{ sub.ip_address }} {{ sub.netmask }}
 no shutdown
!
{% endfor -%}
```

#### レンダリング出力結果
```text
hostname PE1-ROUTER
!
vrf definition TENANT_A
 rd 65000:100
 !
 address-family ipv4
  route-target import 65000:100
  route-target export 65000:100
 exit-address-family
!
vrf definition TENANT_B
 rd 65000:200
 !
 address-family ipv4
  route-target import 65000:200
  route-target export 65000:200
 exit-address-family
!
!
interface GigabitEthernet0/0/2.100
 description Subinterface for TENANT_A
 encapsulation dot1Q 100
 vrf forwarding TENANT_A
 ip address 10.100.1.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet0/0/2.200
 description Subinterface for TENANT_B
 encapsulation dot1Q 200
 vrf forwarding TENANT_B
 ip address 10.200.1.1 255.255.255.0
 no shutdown
!
```

#### 検証方法
VRF アタッチ手順における Cisco IOS XE の仕様に従い、`vrf forwarding` の後に `ip address` が正しく配置されているか（`ip address` を先に設定すると IP アドレスが自動消去される問題を考慮した順序構成）を検証する。

---

## ❓ 想定試験問題

CCIE EI v1.1 ラボ試験および筆記試験を意識した実践的な問題 8 問を提示します。

---

### ❓ 問 1 (コンフィグ読解・トラブルシューティング)
Ansible プレイブック実行時、以下のテンプレートレンダリングエラーが発生した。

```text
fatal: [R1]: FAILED! => {"msg": "AnsibleUndefinedError: 'dict object' has no attribute 'description'"}
```

テンプレート内の該当行は以下である。
`description {{ interface.description }}`

#### 設問
変数 `interface.description` が一部の物理インターフェイスで未定義の場合でも、エラーで処理が停止せずにデフォルト値 `Managed_by_Automation` を補完して処理を続行させる正しい Jinja2 記述を選べ。

* A. `description {{ interface.description | default('Managed_by_Automation') }}`
* B. `description {{ interface.description or 'Managed_by_Automation' }}`
* C. `description {{ interface.description if defined else 'Managed_by_Automation' }}`
* D. `description {{ default(interface.description, 'Managed_by_Automation') }}`

#### 正解
**A**

#### 解説
Jinja2 において未定義変数に対する安全なデフォルト値代入は `default()` フィルタ（別名 `d()`）を使用します。`{{ variable | default('value') }}` の記述により、キーが存在しない場合に `UndefinedError` の発生を防止できます。

---

### ❓ 問 2 (トラブルシューティング / Jinja2 変数スコープ)
以下の Jinja2 テンプレートを実行したところ、レンダリング結果の最終行 `Active Port Count: 0` となり、ループ内のカウントアップが反映されなかった。

```jinja2
{% set active_count = 0 %}
{% for port in ports %}
{% if port.status == 'up' %}
{% set active_count = active_count + 1 %}
{% endif %}
{% endfor %}
Active Port Count: {{ active_count }}
```

#### 設問
ループ内での状態変更をループ外に反映させるための正当な修復手順を選べ。

* A. `active_count` を `global active_count = 0` と宣言する。
* B. `namespace()` オブジェクトを使い、`{% set ns = namespace(count=0) %}` と宣言してループ内で `{% set ns.count = ns.count + 1 %}` と更新する。
* C. `{% for port in ports export active_count %}` と記述する。
* D. `active_count` を `{{ active_count | increment }}` フィルタで更新する。

#### 正解
**B**

#### 解説
Jinja2 の `{% for %}` ループ内での `{% set %}` はブロックローカルスコープを持つため、ループ外部の同名変数には影響を与えません。ループを跨いで変数の値を保持・更新するには `namespace()` オブジェクトを使用する必要があります。

---

### ❓ 問 3 (Design / アーキテクチャ)
大規模型エンタープライズ網において、1,000 台の Cisco Catalyst スイッチへ配備するコンフィグを自動生成するにあたり、Jinja2 テンプレートエンジンを採用する最大の技術的利点はどれか。

* A. スイッチ本体の IOS XE 内で直接 Jinja2 スクリプトを常駐実行し、自己コンフィグ生成が行える点。
* B. コンフィグ生成時にリアルタイムでスイッチへ SSH 接続し、状態に応じて動的に設定行を直接流し込める点。
* C. 「ネットワークパラメータ (YAML/JSON 形式の変数データ)」と「コンフィグ構造 (Jinja2 テンプレート)」を完全分離でき、テンプレートのコード再利用性とテスト容易性が大幅に向上する点。
* D. 生成されたコンフィグに対して自動的に構文チェックを行い、IOS XE の CLI エラーを全自動で自己修復する点。

#### 正解
**C**

#### 解説
Jinja2 を導入する最大の利点は「データとプレゼンテーションロジックの完全分離 (Data-Model Separation)」です。変数は YAML / JSON ファイルで管理し、コンフィグ構文は .j2 テンプレートに集約することで、1,000 台の機器に対しても同一テンプレートと個別の変数ファイルを組み合わせるだけで均一かつ高品質なコンフィグを自動生成できます。

---

### ❓ 問 4 (実装 / 空白制御)
Cisco IOS XE コンフィグ生成時、Jinja2 の `{% for %}` や `{% if %}` 制御ブロックの直後に不要な空行が大量に出力されてしまう現象を防ぐための最も適切な対処法を選べ。

* A. テンプレートファイルを単一行の文字列として圧縮記述する。
* B. 制御タグの開始・終了位置にハイフン記号を付与 (`{%-` または `-%}`) するか、環境設定で `trim_blocks=True` および `lstrip_blocks=True` を有効化する。
* C. 各制御行の末尾にセミコロン `;` を付与する。
* D. テンプレートのファイル拡張子を `.j2` から `.jinja_strip` に変更する。

#### 正解
**B**

#### 解説
Jinja2 では制御構文タグの配置された行の改行コードがデフォルトでそのままテキスト出力されます。これを抑止するには、タグ記号の内側にハイフンを付与 (`{%-` / `-%}`) して前後空白・改行を削るか、レンダリングエンジン側で `trim_blocks=True` / `lstrip_blocks=True` を有効化します。

---

### ❓ 問 5 (コンフィグ読解 / JSON 生成)
RESTCONF 用の JSON ペイロードを Jinja2 で生成する際、変数 `is_active: true` (Boolean) を展開するとき、`"enabled": {{ is_active }}` と記述したところ、Python から `True` とレンダリングされてしまい JSON パースエラーとなった。

#### 設問
JSON 規格に適合する小文字の `true` / `false` を出力するための正しい Jinja2 フィルタの組み合わせを選べ。

* A. `"enabled": {{ is_active | lower }}`
* B. `"enabled": {{ is_active | json_bool }}`
* C. `"enabled": {{ is_active | string }}`
* D. `"enabled": {{ is_active | to_json }}` (または `lower`)

#### 正解
**A** (および D)

#### 解説
Python 環境でレンダリングを行うと、Boolean 型 `True` / `False` は文字表記 `True` / `False` として展開されます。JSON 規格は小文字 `true` / `false`（引用符なし）を要求するため、`{{ is_active | lower }}` や `to_json` フィルタを通して小文字変換を行う必要があります。

---

### ❓ 問 6 (トラブルシューティング / リスト操作)
Ansible Playbook で Trunk インターフェイスの `allowed_vlans` 変数（YAML のリスト形式 `[10, 20, 30, 99]`）を Jinja2 テンプレート内で展開したところ、`allowed vlan [10, 20, 30, 99]` と出力されてしまい、IOS XE CLI で構文エラーとなった。

#### 設問
IOS XE CLI 規格適合の `switchport trunk allowed vlan 10,20,30,99` 形式で出力させるための正しいテンプレート記述を選べ。

* A. `switchport trunk allowed vlan {{ allowed_vlans | join(',') }}`
* B. `switchport trunk allowed vlan {{ allowed_vlans | split(',') }}`
* C. `switchport trunk allowed vlan {{ allowed_vlans | to_string }}`
* D. `switchport trunk allowed vlan {{ allowed_vlans | flatten }}`

#### 正解
**A**

#### 解説
Jinja2 の `join('delimiter')` フィルタは、配列・リストの全要素を指定した区切り文字（この場合はカンマ `,`）で結合した単一の文字列へ変換します。これによりリスト `[10, 20, 30]` が `10,20,30` へ正しく整形されます。

---

### ❓ 問 7 (Design / 可読性と保守性)
Jinja2 テンプレート内に複雑なビジネスロジック、高度な文字列パース処理、多重のネスト条件分岐を埋め込んだ結果、コードの可読性が著しく低下した。この設計問題を解消するためのベストプラクティスとして最も適切なものはどれか。

* A. テンプレートファイルを複数の小さな `.j2` ファイルに分割し、`{% include %}` タグでカスケード読み込みさせる。
* B. 複雑なデータパースやビジネスロジック処理は、事前処理として Python スクリプトや Ansible フィルタープラグイン側に集約し、テンプレートには整理済みの変数のみを渡す。
* C. テンプレート内の全ロジックを `{% macro %}` にカプセル化し、同一ファイル内で再定義する。
* D. Jinja2 の使用を完全に廃止し、すべて C 言語のコンパイラで事前ビルドする。

#### 正解
**B**

#### 解説
Jinja2 の設計原則において、テンプレートは「純粋なテキスト成形と表示」に専念させるべきです。複雑なデータの加工、計算、パースなどのビジネスロジックは、呼び出し元の Python スクリプトや Ansible の Filter Plugin 側に集約し、テンプレートへはレンダリングに最適化されたシンプルな変数を渡すことが推奨されます。

---

### ❓ 問 8 (実装 / マクロ)
複数のインターフェイス設定ブロックで共通して使用する「LLDP 有効化および Security 記述」の共通 CLI ブロックを Jinja2 テンプレート内で再利用可能にするための構造化構文を選べ。

* A. `{% set_function ... %}`
* B. `{% macro apply_security(desc) %} ... {% endmacro %}`
* C. `{% class security_block %} ... {% endclass %}`
* D. `{% import_block security %} ... {% endimport_block %}`

#### 正解
**B**

#### 解説
Jinja2 の `{% macro %}` タグは、プログラミング言語における関数（Function）のように再利用可能なコンフィグブロックを定義できます。引数（Parameter）を受け取ることも可能であり、テンプレート内での重複コード削減に貢献します。

---

## 🔗 参考リソース

CCIE Enterprise Infrastructure v1.1 試験対策に有用な Cisco 公式資料、Cisco Live セッション、開発者ドキュメントを以下にまとめます。

### Cisco 公式ドキュメント ＆ ガイド
* Cisco DNA Center / Catalyst Center Template Programmer Application Guide
* Cisco SD-WAN Controller CLI Template Configuration Guide
* Cisco DevNet Learning Labs: Introduction to Jinja2 Templates for Network Automation

### Cisco Live セッション ＆ スライド
* **DEVNET-1011:** Hands-on Network Automation with Ansible and Jinja2
* **BRKDEV-2001:** Advanced Jinja2 Templating Mechanics for Network Engineers
* **DEVNET-2030:** Model-Driven Programmability with RESTCONF and Jinja2 Payloads

### 開発者規格 ＆ ツールリソース
* Jinja2 Official Documentation (Pallets Projects)
* Ansible Network Guide: Using Jinja2 Templates in Ansible Playbooks
* RFC 8040 - RESTCONF Protocol Specification

---

## 📝 **補足（Notes）**

### 1. 学習メモ：Jinja2 制御ブロックとハイフン位置のルール

```text
1. {% for x in list %}  -> 制御行自体の改行が出力される (空行が発生しやすい)
2. {%- for x in list %} -> タグより「前」の改行・空白を削除
3. {% for x in list -%} -> タグより「後」の改行・空白を削除
4. {%- for x in list -%} -> 前後の改行・空白を完全削除
```

### 2. 図解：Ansible ＋ Jinja2 ＋ IOS XE パイプライン

```text
+-------------------+      +-----------------------+
| host_vars/R1.yml  |      | templates/router.j2   |
| (Structured Data) |      | (Jinja2 Logic)        |
+-------------------+      +-----------------------+
          \                            /
           \                          /
            v                        v
      +------------------------------------+
      |  Ansible Control Node              |
      |  ansible.builtin.template Module   |
      +------------------------------------+
                        |
                        v [Render Memory Buffer]
      +------------------------------------+
      | Generated Cisco IOS XE CLI Text    |
      +------------------------------------+
                        |
                        v [SSH Transport via cisco.ios.ios_config]
      +------------------------------------+
      | Cisco Catalyst / ISR Router        |
      | Running-Config updated             |
      +------------------------------------+
```

### 3. 注意点：Ansible 2.9+ における Jinja2 処理の変化
Ansible 2.9 以降では、`jinja2_native: True` オプションを `ansible.cfg` で有効化することで、Jinja2 テンプレートの評価結果を単純な文字列（String）ではなく、元の Python データ型（List, Dict, Bool）のまま保持することが可能です。型変換のトラブルを激減させるテクニックとして覚えておくと有用です。




