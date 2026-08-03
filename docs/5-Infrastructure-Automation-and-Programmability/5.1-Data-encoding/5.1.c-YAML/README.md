---
layout: default
title: 5.1.c-YAML
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 3
---

# 5.1.c YAML

本ページでは、ネットワーク自動化、特に Ansible や Cisco SD-WAN (vManage) の変定義において標準的に使用されるデータエンコーディング形式である **YAML (YAML Ain't Markup Language)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**YAML** は、「人間にとっての読みやすさ」を最優先に設計されたデータシリアル化フォーマットです。XML や JSON と比較して構造が簡潔であり、コメントを記述できるため、ネットワークエンジニアが自動化スクリプトの設定ファイルや変定義ファイルを作成する際に最も好まれる形式です。

CCIE EI v1.1 のコンテキストでは、主に以下の用途で使用されます：
*   **Ansible Playbook:** ネットワークデバイスの構成を管理するための手順書。
*   **Cisco SD-WAN (vManage):** デバイステンプレートの変数（Variable）をバルクインポート/エクスポートする際のデータ形式。
*   **Infrastructure as Code (IaC):** ネットワークの状態を宣言的に定義するファイル形式。

---

## 🔑 要点

YAML の構文は非常に厳格であり、わずかなミスが自動化ツールのエラーに直結します。

### 1. 基本的なデータ構造

*   **スカラー (Scalar):** 単一の値（文字列、数値、真偽値）。
*   **マッピング (Mapping/Dictionary):** 「キー: 値」のペア。コロンの後に必ず **半角スペース** が必要です。
*   **シーケンス (Sequence/List):** ハイフン（-）から始まるリスト形式。

### 2. インデントのルール

*   YAML は **スペースによるインデント** を使用して階層構造を表現します。
*   **タブ文字（Tab）の使用は厳禁** です。通常、1 階層につき 2 つまたは 4 つのスペースを使用します。

### 3. 特殊な構文

*   **ドキュメントの開始/終了:** `---` でドキュメントの開始を、`...` で終了（任意）を明示します。
*   **コメント:** `#` 以降がコメントとして扱われます。
*   **複数行の文字列:** `|`（改行を保持）または `>`（改行をスペースに置換）を使用して長いテキスト（バナー等）を記述できます。

### 4. JSON との関係

YAML は JSON のスーパーセットであり、理論上、全ての JSON ファイルは有効な YAML ファイルとして扱えます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験の「Infrastructure Automation and Programmability」セクションにおいて、YAML に関しては以下の実践的な対応力が求められます。

### 1. Ansible Playbook の修正

試験問題として提供された Playbook が動作しない場合、インデントのズレや、リストと辞書の組み合わせミスを特定して修正する能力が問われます。
*   **チェックポイント:** `tasks:` の配下に正しく `- name:` が並んでいるか、`loop:` のデータ構造が正しいかを確認します。

### 2. SD-WAN vManage 変数ファイルの構築

vManage の Feature Template で定義した変数（例: `{{source_ip}}`）に対応する値を、YAML 形式のファイルとして正しく記述できる必要があります。
*   **ポイント:** 多数のデバイスに対する変数をリスト形式で定義し、各要素に System-IP などのキーを含める構造を習得してください。

### 3. 複雑なネスト構造の理解

BGP のネイバー設定や OSPF のエリア設定など、リストの中に辞書が含まれる（List of Dictionaries）構造を正確に読み書きできる必要があります。
*   **例:** `router_bgp` の下に複数の `neighbors` をリストとして定義する構造など。

### 4. データ型の意識

IP アドレスや VLAN ID が文字列として扱われているか、数値として扱われているかにより、後続の Python スクリプトや Ansible モジュールの挙動が変わる可能性があることを意識してください。

---

## 🛠 設定・検証コマンド

YAML 自体はデバイス上のコマンドではありませんが、YAML を扱うためのツールや、デバイス側でデータを整形して表示するコマンドが存在します。

### 自動化ツールでの検証

| 目的 | コマンド・ツール |
| :--- | :--- |
| **Ansible構文チェック** | <code>ansible-playbook [FILE.yml] --syntax-check</code> |
| **Playbookの実行** | <code>ansible-playbook -i [INVENTORY] [FILE.yml]</code> |
| **YAMLの妥当性確認** | <code>yamllint [FILE.yml]</code>（外部ツール） |
| **Pythonでの読み込み** | <code>import yaml; data = yaml.safe_load(open('file.yml'))</code> |

### IOS-XE での関連操作 (JSON/XMLからの推論)
現在、IOS-XE 自体には `format yaml` という標準コマンドはありませんが、ゲストシェル内の Python を使用して JSON 出力を YAML に変換する等の操作が想定されます。

---

## 🧪 ラボ学習・設定サンプル例

CCIE ラボ環境で遭遇し得る、実戦的な YAML 構成例 12 選です。

### 1. インターフェイス基本設定 (Ansible 変数)

**【課題】** 各インターフェイスの説明文と IP アドレスを定義せよ。
```yaml
interfaces:
  - name: GigabitEthernet1
    description: "Link to CORE-01"
    ipv4: 10.1.1.1
    mask: 255.255.255.252
  - name: GigabitEthernet2
    description: "Link to ACCESS-01"
    ipv4: 192.168.10.1
    mask: 255.255.255.0
```

### 2. VLAN 一括作成用リスト

**【課題】** 作成すべき VLAN ID と名前のリストを作成せよ。
```yaml
vlan_list:
  - { id: 10, name: "USERS" }
  - { id: 20, name: "VOICE" }
  - { id: 99, name: "MGMT" }
```

### 3. Ansible Playbook: VLAN 設定の実行

**【課題】** ターゲットデバイスに EIGRP 設定を流し込む Playbook。
```yaml
- name: Configure EIGRP 100 on R1
  hosts: cisco_routers
  tasks:
    - name: Apply EIGRP Configuration
      cisco.ios.ios_config:
        lines:
          - router eigrp 100
          - network 10.1.1.0 0.0.0.255
          - no auto-summary
```

### 4. SD-WAN vManage 変数インポート用ファイル

**【課題】** cEdge デバイス 2 台分の初期変数を定義せよ。
```yaml
devices:
  - system_ip: 1.1.1.1
    host_name: BR1-R1
    site_id: 100
  - system_ip: 1.1.1.2
    host_name: BR2-R1
    site_id: 200
```

### 5. BGP ネイバー定義 (複雑なネスト)

**【課題】** 1 つの AS 内に複数のピアを定義する構造。
```yaml
bgp_config:
  as_number: 65001
  router_id: 10.255.255.1
  neighbors:
    - ip: 10.1.1.2
      remote_as: 65001
      description: "iBGP Peer R2"
    - ip: 192.168.1.1
      remote_as: 65002
      description: "eBGP Peer ISP"
```

### 6. 複数行のバナー設定 (Literal Block)

**【課題】** 改行を含む MOTD バナーを定義せよ。
```yaml
banner_motd: |
  *********************************
  Authorized Access Only!
  Device: {{ inventory_hostname }}
  *********************************
```

### 7. SNMP コミュニティとホストの設定

**【課題】** セキュリティ制限付きの SNMP 設定。
```yaml
snmp_settings:
  communities:
    - name: "public"
      access: "ro"
    - name: "private"
      access: "rw"
  traps:
    - host: 10.10.10.100
      community: "SNMP-MON"
```

### 8. Ansible インベントリファイル (YAML形式)

**【課題】** グループ化されたデバイスリストを作成せよ。
```yaml
all:
  children:
    campus_switches:
      hosts:
        SW1:
          ansible_host: 10.1.1.11
        SW2:
          ansible_host: 10.1.1.12
    branch_routers:
      hosts:
        R10:
          ansible_host: 172.16.1.1
```

### 9. OSPF エリアとネットワークの定義

**【課題】** 階層的なルーティング定義。
```yaml
ospf_process:
  id: 1
  areas:
    - id: 0
      networks:
        - 10.1.0.0/24
        - 10.2.0.0/24
    - id: 10
      networks:
        - 192.168.1.0/24
```

### 10. YAML アンカーとエイリアスの利用 (再利用)

**【課題】** 共通の設定を複数の箇所で使い回す高度な構文。
```yaml
common_settings: &base_config
  dns: 8.8.8.8
  ntp: 10.1.1.1

router_r1:
  <<: *base_config
  hostname: R1

router_r2:
  <<: *base_config
  hostname: R2
```

### 11. 複数のドキュメントを 1 ファイルに集約

**【課題】** 設定用データと、検証用期待値を分離して記述。
```yaml
---
# Part 1: Configuration Data
vlan: 10
---
# Part 2: Verification Data
expected_state: "up"
...
```

### 12. 条件付き設定 (Ansible variables)

**【課題】** 特徴に基づいたフラグ管理。
```yaml
device_features:
  is_mpls_enabled: true
  is_ipv6_ready: false
  mtu_size: 9000
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKOPS-2431: Network Automation in Theory and Practice**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   YANG モデル、NETCONF、RESTCONF と並び、YAML による変数管理の重要性を解説。
*   [**BRKCRT-1385: The CCIE in an SDN World**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE EI 試験におけるプログラマビリティの価値と、YAML を含むデータ形式の基礎を網羅。

### Configuration ガイド
*   [**Ansible for Cisco IOS Documentation**](https://docs.ansible.com/ansible/latest/collections/cisco/ios/index.html)
    *   YAML ベースの Playbook 構成に関する詳細リファレンス。
*   [**Cisco vManage API / Template Documentation**](https://developer.cisco.com/docs/sdwan/)
    *   SD-WAN 環境での YAML/JSON 変数ファイルの扱い。

### テクニカルドキュメント・設定例
*   [**YAML.org Official Specification**](https://yaml.org/spec/1.2.2/)
    *   構文ルールの厳密な定義（インデント、予約語など）。
*   [**Cisco DevNet: Introduction to Ansible for IOS**](https://developer.cisco.com/learning/modules/ansible-ios-basics)
    *   YAML 形式の Playbook を使用したネットワーク設定の基礎演習。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「正確なデータの構造化」** を目的としています。試験本番では、Ansible Playbook のインデント一つでスクリプト全体が停止するため、ハイフン（-）とコロン（:）の後のスペースの有無を常に確認する習慣をつけてください。


