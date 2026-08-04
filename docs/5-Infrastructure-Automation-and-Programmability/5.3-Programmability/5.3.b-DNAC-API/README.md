---
layout: default
title: 5.3.b-DNAC-API
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.3.b Interaction with Cisco DNA Center API

本ページでは、Cisco のインテントベースネットワーク（IBN）の中核を担う **Cisco DNA Center (Catalyst Center)** の REST API 操作について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲（5.3.b）に基づき詳述します。Python の `requests` ライブラリおよび **Postman** を用いた、高度なネットワーク自動化スキルの習得を目的とします。

---

## 📘 概要

**Cisco DNA Center REST API** は、ネットワークの設計、ポリシー適用、プロビジョニング、および保証（Assurance）の各フェーズを外部からプログラム制御するためのインターフェイスです。SD-Access (SDA) ファブリックの管理において、GUI 操作を自動化し、数千台のデバイスに対する一括操作や動的な状態監視を可能にします。

操作は標準的な HTTP メソッド（GET, POST, PUT, DELETE）を介して行われ、データ形式として **JSON** が使用されます。CCIE レベルでは、単一の API 呼び出しだけでなく、認証トークンの取得から、タスク ID を追跡して非同期処理の完了を待機する一連のワークフローの実装能力が問われます。

---

## 🔑 要点

### 1. 認証と認可 (Token-based Auth)

DNA Center API を利用するには、まず一時的な **認証トークン** を取得する必要があります。
*   **認証フロー:** `POST /dna/system/api/v1/auth/token` に対して、HTTP Basic Authentication（ユーザー名とパスワード）を使用してリクエストを送信します。
*   **トークンの利用:** 取得したトークン（Token）を、その後のリクエストの HTTP ヘッダー `X-Auth-Token` に含めて送信します。トークンには有効期限があるため、スクリプト内で動的に更新するロジックが重要です。

### 2. HTTP メソッドの使い分け

*   **GET:** デバイスインベントリ、サイト情報、タスクステータス、健康状態（Assurance）の取得。
*   **POST:** 新しいサイトの作成、デバイスの追加、インテントのプッシュ、アクションの実行。
*   **PUT:** 既存のリソース（設定やポリシー、ユーザー情報）の更新。
*   **DELETE:** デバイス、サイト、ポリシーなどの削除。

### 3. API 応答とステータスコード

*   **200 OK:** リクエスト成功。
*   **201 Created:** リソースの作成に成功。
*   **202 Accepted:** リクエストは受理されたが、処理がバックグラウンドで継続中（非同期処理）。**Task ID** が返されます。
*   **401 Unauthorized:** 認証エラー。トークンが不正または期限切れ。

### 4. フィルタリングとページネーション

大規模環境では、`offset`（開始位置）や `limit`（取得数）といったクエリパラメータを使用して、API 応答のデータ量を制御します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、SD-Access セクションの構成や、自動化セクションでの「特定の情報を抽出し、それに基づいた操作を行う」タスクが想定されます。

### 1. 認証トークン取得関数の実装

試験環境では、汎用的な `dnac_login` 関数を Python で記述できることが前提となります。`urllib3.disable_warnings()` を使用した自己署名証明書の警告抑制も必須の手法です。

### 2. 非同期タスク（Async Task）のハンドリング

DNA Center の多くの操作（プロビジョニング等）は `202 Accepted` を返します。
*   **対策:** 応答に含まれる `taskId` を抽出し、`/api/v1/task/{taskId}` をポーリング（定期的な GET）して、`isError` が false かつ処理が完了（`endTime` が存在する等）したかを確認するコードを書ける必要があります。

### 3. データの抽出と加工

API 応答の巨大な JSON から、特定の情報（例：`managementIpAddress` や `id`）を Python の辞書操作やリスト内包表記で正確に取り出すスキルが試されます。

### 4. Postman の活用

プログラムを書く前に、Postman でエンドポイントのパス、必要なヘッダー、JSON ペイロードの構造を素早く確認する手順を確立してください。

---

## 🛠 設定・検証コマンド

DNA Center 側の API 関連設定と、Python スクリプトにおける標準的な実装ロジックです。

### DNA Center 側（GUI/CLI）

| 目的 | 確認・操作箇所 |
| :--- | :--- |
| **APIユーザーの作成** | System ➔ User Management で ROLE_ADMIN 権限を持つユーザーを確認。 |
| **APIドキュメントの参照** | DNA Center メニュー ➔ Platform ➔ Developer Toolkit (Swagger)。 |
| **REST APIの有効性** | デフォルトで HTTPS (TCP 443) でリッスン。 |

### Python requests による API 実装パターン

| 目的 | コード・論理構成例 |
| :--- | :--- |
| **認証リクエスト** | <code>requests.post(url, auth=HTTPBasicAuth(u, p), verify=False)</code> |
| **トークンの取得** | <code>token = response.json()['Token']</code> |
| **インベントリ取得** | <code>requests.get(url, headers={'X-Auth-Token': token})</code> |
| **JSONデータの送信** | <code>requests.post(url, json=payload, headers=headers)</code> |

---

## 🧪 ラボ学習・設定サンプル例

CCIE ラボ試験のシナリオを想定した、実戦的な Python スクリプトおよび API ワークフローの 12 例です。

### 1. 認証トークンの取得 (Python)

**【課題】** DNA Center (10.1.1.250) にアクセスし、認証トークンを文字列として返せ。
```python
import requests
from requests.auth import HTTPBasicAuth

def get_dnac_token():
    url = "https://10.1.1.250/api/system/v1/auth/token"
    # 自己署名証明書の警告を無視
    response = requests.post(url, auth=HTTPBasicAuth('admin', 'Cisco123!'), verify=False)
    return response.json()['Token']
```

### 2. デバイスインベントリの全取得

**【課題】** 管理下の全デバイスのホスト名とシリアル番号を一覧表示せよ。
```python
token = get_dnac_token()
url = "https://10.1.1.250/api/v1/network-device"
headers = {'X-Auth-Token': token, 'content-type': 'application/json'}
devices = requests.get(url, headers=headers, verify=False).json()['response']

for dev in devices:
    print(f"Host: {dev['hostname']}, Serial: {dev['serialNumber']}")
```

### 3. 特定の IP アドレスを持つデバイス ID の検索

**【課題】** IP 10.1.1.1 のデバイス ID (UUID) を取得せよ。これは他の操作（タグ付け等）で必要になります。
```python
url = "https://10.1.1.250/api/v1/network-device/ip-address/10.1.1.1"
dev_id = requests.get(url, headers=headers, verify=False).json()['response']['id']
```

### 4. サイト階層の作成 (POST)

**【課題】** "Global/USA/San Jose" という名前のサイトを新規作成せよ。
```python
url = "https://10.1.1.250/api/v1/site"
payload = {
    "type": "area",
    "site": { "area": { "name": "San Jose", "parentName": "Global/USA" } }
}
response = requests.post(url, json=payload, headers=headers, verify=False)
```

### 5. 非同期タスクのステータス確認 (GET)

**【課題】** POST 処理で返された `taskId` を用いて、処理が完了するまでループで監視せよ。
```python
import time
task_id = response.json()['response']['taskId']
while True:
    task_url = f"https://10.1.1.250/api/v1/task/{task_id}"
    status = requests.get(task_url, headers=headers, verify=False).json()['response']
    if status['isError'] == False and 'endTime' in status:
        print("Task Completed Success!")
        break
    time.sleep(2)
```

### 6. デバイス設定のインターフェイス情報の取得

**【課題】** 特定のデバイス ID に属する全インターフェイスの状態（Up/Down）を取得せよ。
```python
url = f"https://10.1.1.250/api/v1/interface/network-device/{dev_id}"
interfaces = requests.get(url, headers=headers, verify=False).json()['response']
```

### 7. デバイスへの CLI コマンド発行 (Command Runner)

**【課題】** 指定したデバイス ID に対して `show ip interface brief` を実行せよ。
```python
url = "https://10.1.1.250/api/v1/network-device-poller/cli-read-request"
payload = { "commands": ["show ip interface brief"], "deviceUuids": [dev_id] }
# 応答のTask IDから結果を取得するフローへ続く
```

### 8. プール情報の取得とフィルタリング

**【課題】** DNA Center で定義されている IP アドレスプールのうち、"SDA" という名前を含むものを抽出せよ。
```python
url = "https://10.1.1.250/api/v1/ip-pool"
pools = requests.get(url, headers=headers, verify=False).json()['response']
sda_pools = [p for p in pools if "SDA" in p['ipPoolName']]
```

### 9. 既存リソースの更新 (PUT)

**【課題】** 既存の SNMP 構成（Credential）のコミュニティストリングを更新せよ。
```python
url = f"https://10.1.1.250/api/v1/snmp-v2-read-community/{credential_id}"
payload = { "instanceTenantId": "...", "description": "Updated", "readCommunity": "ccie_ro" }
requests.put(url, json=payload, headers=headers, verify=False)
```

### 10. インベントリのページネーション処理

**【課題】** 100 台以上のデバイスがある環境で、最初の 50 台を取得した後に次の 50 台を取得せよ。
```python
# 最初の50台
params1 = {'offset': 1, 'limit': 50}
# 次の50台
params2 = {'offset': 51, 'limit': 50}
requests.get(url, headers=headers, params=params2, verify=False)
```

### 11. サイトヘルス情報の取得 (Assurance)

**【課題】** 全体のネットワークヘルススコアを取得せよ。
```python
url = "https://10.1.1.250/api/v1/network-health"
health_data = requests.get(url, headers=headers, verify=False).json()
```

### 12. リソースの削除 (DELETE)

**【課題】** 不要になったテンプレートやサイトを ID 指定で削除せよ。
```python
url = f"https://10.1.1.250/api/v1/site/{site_id}"
requests.delete(url, headers=headers, verify=False)
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRT-1385: The CCIE in an SDN World - Programmability Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE EI 試験における DNA Center プログラマビリティの重要性を解説。
*   [**BRKOPS-2431: Network Automation in Theory and Practice**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   API 通信とデータモデルの関係性についての詳細。

### Configuration ガイド
*   [**Cisco Catalyst Center (DNA Center) Platform API Reference**](https://developer.cisco.com/docs/dna-center/)
    *   全エンドポイントの仕様とデータ構造の公式ドキュメント。
*   [**Programmability Configuration Guide, Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg.html)。

### テクニカルドキュメント・設定例
*   [**Cisco DevNet: Introduction to Cisco DNA Center APIs**](https://developer.cisco.com/learning/tracks/dnac-programmability-basics)
    *   Python を使用した実践的なハンズオンシナリオ。
*   [**Task Management and Async Operations in DNA Center (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-understanding-cisco-dna-center-tasks-and.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において **「コントローラベースの自動化をパケットおよびコードレベルでいかに制御するか」** という視点を提供しています。ラボ試験では、GUI で可能な操作を Python requests で再現できることが合格への絶対条件となります。API の応答構造を Python で素早くデバッグ（`print(json.dumps(data, indent=4))`）する習慣をつけてください。


