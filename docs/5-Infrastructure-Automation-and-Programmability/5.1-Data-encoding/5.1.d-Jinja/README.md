---
layout: default
title: 5.1.d-Jinja
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 4
---



# 5.1.d Jinja

本ページでは、ネットワーク自動化における「構成のテンプレート化」の中核を担う **Jinja2** テンプレートエンジンについて、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**Jinja2** は、Python で広く利用されているモダンでデザイナーフレンドリーなテンプレートエンジンです。ネットワーク自動化においては、デバイスの構成（設定コマンド）の「骨組み（テンプレート）」と、個別のデバイスごとに異なる「データ（変数：IPアドレスやホスト名など）」を分離するために使用されます。

CCIE EI v1.1 の試験範囲（5.1.d）において、Jinja2 は単独で動作するものではなく、通常は以下のエコシステムの一部として機能します：
*   **Ansible:** `template` モジュールを使用して、Jinja2 形式の `.j2` ファイルから実際のコンフィグを生成します。
*   **Python (Custom Scripts):** `jinja2` ライブラリをインポートし、YAML や JSON 形式のデータファイルを読み込んでコンフィグをレンダリングします。
*   **SD-WAN (vManage):** デバイステンプレートの内部的な構成要素として、変数の埋め込みに Jinja2 形式の構文が採用されています。

Jinja2 を活用することで、数千行に及ぶ複雑なコンフィグを、共通の論理構造（ループや条件分岐）を用いて効率的かつ正確に管理することが可能になります。

---

## 🔑 要点

Jinja2 の構文は、主に 3 つの「デリミタ（区切り文字）」によって構成されます。

### 1. 構文の基本

* **<code>&#123;&#123; ... &#125;&#125;</code> (Expressions):**  変数の展開や計算結果を出力するために使用します（例：<code>hostname &#123;&#123; device_name #125;&#125;</code>）
* **<code>&#123;% ... %&#125;</code> (Statements):**  （例：if による条件分岐や for によるループ）。
* **<code>&#123;# ... #&#125;</code> (Comments):**   テンプレート内にメモを残すために使用します。この内容はレンダリング後のコンフィグには出力されません。

### 2. 制御構造 (Control Structures)

*   **For ループ:** リスト形式のデータを反復処理し、VLAN やインターフェイスを効率的に生成します。
*   **If 条件分岐:** デバイスの役割（例：Spoke か Hub か）や特定の機能の有効/無効フラグに基づき、設定の出力を動的に変更します。

### 3. ホワイトスペース（空白・改行）の制御

Jinja2 はデフォルトではテンプレート内の改行をそのまま出力します。ルータのコンフィグとして不適切な空行を避けるために、<code>&#123;%-</code> や <code>&#123;-%</code> （マイナス記号の付与）を使用して、前後の空白や改行を削除するテクニックが重要です。

### 4. フィルタ (Filters)

変数の値を加工する機能です。パイプ記号（`|`）を使用します。
*   <code>&#123;&#123; name | upper &#125;&#125;</code> : 大文字に変換。
*   <code>&#123;&#123; ip_addr | default('10.1.1.1') &#125;&#125;</code> : 変数が未定義の場合のデフォルト値を指定。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE EI ラボ試験の自動化セクション（15%）において、Jinja2 に関しては以下の実践的なスキルが問われます。

### 1. YAML データとのマッピング能力

試験では「提供された YAML ファイルのデータ構造を読み解き、それを正確に出力する Jinja2 テンプレートを完成させよ」という形式のタスクが想定されます。
*   **ポイント:** リスト内の辞書（List of Dictionaries）を、`for` ループ内でどのように `item.key` の形式で参照するかを習得してください。

### 2. 複雑なコンフィグの動的生成

BGP のネイバー設定や、多数のスタティックルート、VRF ごとのインターフェイス設定など、繰り返し要素の多い構成をテンプレート化する能力が求められます。

### 3. 構成の論理性

「特定の VRF が定義されている場合のみ、その配下の BGP アドレスファミリーを出力する」といった、入れ子（ネスト）構造の `if` 分岐を正確に構築できる必要があります。

### 4. トラブルシューティング

「生成されたコンフィグに構文エラーがある（例：必要な `!` が抜けている、あるいは空行が多すぎる）」場合に、テンプレート側のループ処理や改行制御を修正させる問題が考えられます。

---

## 🛠 設定・検証コマンド

Jinja2 自体はデバイスのコマンドではありませんが、自動化環境での実行・検証には以下の操作が伴います。

### レンダリング結果の検証 (Python)

| 目的 | コード例 |
| :--- | :--- |
| **ライブラリのインポート** | <code>from jinja2 import Environment, FileSystemLoader</code> |
| **テンプレートの読み込み** | <code>template = env.get_template('config.j2')</code> |
| **データの流し込み(Render)** | <code>rendered_config = template.render(data_dict)</code> |

### Ansible での利用

| 目的 | モジュール・タスク例 |
| :--- | :--- |
| **テンプレートの適用** | <code>- name: Generate Config</code><br><code>  ansible.builtin.template:</code><br><code>    src: core_config.j2</code><br><code>    dest: /tmp/rendered.conf</code> |
| **ドライラン(検証)** | <code>ansible-playbook -i inv.yml playbook.yml --check --diff</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. ホスト名とバナーの基本設定

**【要件】** デバイス名と警告メッセージを変数から生成せよ。

```jinja2
hostname {{ hostname }}
!
banner motd ^C
*****************************************
  Unauthorized access to {{ hostname }} 
  is strictly prohibited.
*****************************************
^C
```

### 2. VLAN の一括生成（Forループ）

**【要件】** リスト `vlan_list` に含まれる全ての VLAN を生成せよ。
```jinja2
{% for vlan in vlan_list -%}
vlan {{ vlan.id }}
 name {{ vlan.name }}
{% endfor %}
```

### 3. インターフェイスの条件付き設定（If分岐）

**【要件】** `is_trunk` が true の場合のみトランク設定を、それ以外はアクセス設定を出力せよ。
```jinja2
interface {{ int_name }}
 description Connected to {{ peer_name }}
{% if is_trunk -%}
 switchport mode trunk
 switchport trunk allowed vlan all
{% else -%}
 switchport mode access
 switchport access vlan {{ vlan_id }}
{% endif -%}
 no shutdown
```


### 4. BGP ネイバーの動的生成（複雑な辞書）

**【要件】** 複数のネイバーと AS 番号をループで構成せよ。
```jinja2
router bgp {{ local_as }}
 bgp router-id {{ loopback0_ip }}
{% for neighbor in bgp_neighbors -%}
 neighbor {{ neighbor.ip }} remote-as {{ neighbor.as }}
 neighbor {{ neighbor.ip }} description {{ neighbor.desc }}
{% endfor -%}
```

### 5. OSPF エリアとネットワークの階層構成

**【要件】** エリアごとに定義されたネットワークを構成せよ。
```jinja2
router ospf {{ process_id }}
{% for area in ospf_areas %}
 ! Area {{ area.id }} Configuration
 {% for net in area.networks -%}
 network {{ net.network }} {{ net.wildcard }} area {{ area.id }}
 {% endfor %}
{% endfor %}
```

### 6. VRF 定義とインターフェイスへの紐付け

**【要件】** VRF リストを読み込み、定義と IF 適用を同時に行え。
```jinja2
{% for vrf in vrfs -%}
vrf definition {{ vrf.name }}
 address-family ipv4
 exit-address-family
!
interface {{ vrf.interface }}
 vrf forwarding {{ vrf.name }}
 ip address {{ vrf.ip }} {{ vrf.mask }}
{% endfor %}
```

### 7. スタティックルートのリスト生成

**【要件】** 宛先、マスク、ネクストホップのリストからルートを生成せよ。
```jinja2
{% for route in static_routes -%}
ip route {{ route.dest }} {{ route.mask }} {{ route.next_hop }}
{% endfor %}
```

### 8. QoS Class-map と Policy-map

**【要件】** クラス名と DSCP 値のペアから QoS ポリシーを構築せよ。
```jinja2
{% for class in qos_classes -%}
class-map match-any CM-{{ class.name }}
 match ip dscp {{ class.dscp }}
{% endfor %}
!
policy-map PM-OUT
{% for class in qos_classes -%}
 class CM-{{ class.name }}
  bandwidth percent {{ class.bw_percent }}
{% endfor %}
```

### 9. NTP サーバーリストの正規化（Filter利用）

**【要件】** 大文字小文字が混在するサーバー名を小文字にして設定せよ。
```jinja2
{% for server in ntp_servers -%}
ntp server {{ server | lower }}
{% endfor %}
```

---

## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**BRKCRT-1385: The CCIE in an SDN World - Programmability Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE EI 試験における Jinja2 を含む自動化ツールの位置付け。
*   [**BRKOPS-2431: Network Automation in Theory and Practice**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   YANG モデルと Jinja2 テンプレートの連携に関する詳細。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Programmability Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg.html)
*   [**Ansible Template Module Documentation**](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)

### テクニカルドキュメント・設定例
*   [**Jinja2 Official Documentation (Template Designer Provost)**](https://jinja.palletsprojects.com/)
*   [**Cisco DevNet: Render your first network configuration template using Python and Jinja2**](https://developer.cisco.com/learning/modules/intro-python-jinja2)

---

## 📝 補足

- この学習メモは、CCIE EI ラボ試験において **「単なるコマンドの暗記ではなく、インフラ構成をいかに論理的に抽象化し、自動化のフローに乗せられるか」** を問う Jinja2 の重要性を網羅しています。実技試験では、テンプレート内の 1 文字のミス（例：`{% endfor %}` の欠落）が設定全体の失敗に繋がるため、構文の正確性を常に意識して演習を繰り返してください。

