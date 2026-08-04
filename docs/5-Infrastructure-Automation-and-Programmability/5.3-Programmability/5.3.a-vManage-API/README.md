---
layout: default
title: 5.3.a-vManage-API
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.3.a Interaction with vManage API

本ページでは、Cisco SD-WAN ソリューションの管理プレーンである **vManage (Cisco Catalyst SD-WAN Manager)** とのプログラマブルな対話手法について詳述します。CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲（5.3.a）に基づき、REST API を使用したモニタリングと構成管理の自動化に焦点を当てます。

---

## 📘 概要

**vManage REST API** は、Cisco SD-WAN ファブリックの運用、監視、および構成をプログラムから制御するためのインターフェイスです。すべての操作は標準的な HTTPS プロトコルを介して行われ、データ交換形式としては **JSON** が採用されています。

CCIE レベルのプログラマビリティでは、単に API を叩くだけでなく、認証トークンの管理、複雑な JSON データのパース（解析）、および特定の「ジョブ（作業）」のステータス確認を含む一連のワークフローを Python スクリプトで完結させる能力が求められます。

---

## 🔑 要点

### 1. 認証ワークフロー (i)

vManage API を利用するには、まず認証を通過してセッションを確立する必要があります。
*   **認証プロセス:** `https://<vmanage>/j_security_check` に対して POST リクエストを送信し、ユーザー名とパスワードを渡します。
*   **Cookie とトークン:** 認証に成功すると、サーバから **JSESSIONID** (Cookie) が返されます。さらに、最新のバージョンでは CSRF 対策として **X-XSRF-TOKEN** の取得と、その後の POST/PUT/DELETE 操作での付与が必須となります。

### 2. Python requests ライブラリと Postman (i)

*   **Postman:** API のエンドポイントをテストし、応答（Response Body）の構造を把握するためのグラフィカルなツールです。
*   **Python requests:** スクリプト内で HTTP リクエスト（GET, POST, PUT, DELETE）を処理するための標準的なライブラリです。

### 3. Monitoring エンドポイント (ii)

ネットワークの健全性や統計情報を取得するために使用されます。
*   **デバイス一覧:** `/dataservice/device`
*   **アラーム/イベント:** `/dataservice/event` や `/dataservice/alarm`
*   **インターフェイス統計:** `/dataservice/device/interface`

### 4. Configuration エンドポイント (iii)

テンプレートの作成、編集、およびデバイスへの適用に使用されます。
*   **デバイステンプレート:** `/dataservice/template/device`
*   **テンプレートの適用（アタッチ）:** `/dataservice/template/device/config/attachfeature`
*   **ポリシー管理:** `/dataservice/template/policy/vsmart`

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、SD-WAN セクションと自動化セクションが組み合わさった高度なタスクが出題されます。

### 1. セッション管理の完全自動化

「ログインし、トークンを取得し、それを使用して情報を取得する」という一連の流れを Python で正確に記述できる必要があります。
*   **ポイント:** `requests.Session()` オブジェクトを使用して Cookie を自動保持させつつ、`headers` に `X-XSRF-TOKEN` を明示的に追加する手順が重要です。

### 2. 大規模データのフィルタリング

`/dataservice/device` などの応答は非常に大きくなることがあります。
*   **ポイント:** `offset` や `limit` といったクエリパラメータを使用して、必要な範囲のデータのみを効率的に取得するスキルが問われます。

### 3. 設定変更後のステータス確認

テンプレートをデバイスにプッシュ（Attach）する API コールは、非同期で処理されます。
*   **ポイント:** API 応答で返される `processId` を使用して、別のエンドポイント（`/dataservice/device/action/status/<processId>`）を定期的にポーリングし、設定が「Success」になったかを確認するロジックの実装が求められます。

### 4. JSON からの特定データの抽出

「全デバイスの中から、Site ID が 100 の cEdge の System-IP のみを取得せよ」といった条件付きのデータ抽出は、Python のリスト内包表記や `filter()` などを駆使して迅速に行う必要があります。

---

## 🛠 設定・検証コマンド

API 操作はルータ上の CLI コマンドではなく、Python プログラム内の論理として実装されます。

### API 呼び出しの基本ロジック (Python)

| 目的 | コード・論理構成 |
| :--- | :--- |
| **セッションの開始** | <code>sess = requests.Session()</code> |
| **ログインPOST** | <code>sess.post(auth_url, data={'j_username': user, 'j_password': pwd})</code> |
| **X-XSRFトークン取得** | <code>token = sess.get(token_url).text</code> |
| **GETリクエスト(監視)** | <code>resp = sess.get(api_url).json()</code> |
| **POSTリクエスト(構成)** | <code>sess.post(api_url, json=payload, headers={'X-XSRF-TOKEN': token})</code> |

### vManage 上での API 関連設定

| 目的 | コマンド |
| :--- | :--- |
| **REST APIの有効化** | vManage の管理画面上でデフォルトで有効。 |
| **APIユーザーの作成** | vManage ➔ Administration ➔ Users で API 権限を持つユーザーを作成。 |

---

## 🧪 ラボ学習・設定サンプル例

CCIE ラボ試験のシナリオを想定した、vManage API と Python を活用した 12 個の実装例です。

### 1. 認証とログインの自動化

**【課題】** vManage にログインし、認証済みのセッションオブジェクトを作成せよ。
```python
import requests
import urllib3
requests.packages.urllib3.disable_warnings()

vmanage_ip = '10.1.1.1'
base_url = f'https://{vmanage_ip}:8443'
session = requests.Session()

login_data = {'j_username': 'admin', 'j_password': 'Cisco123!'}
session.post(f'{base_url}/j_security_check', data=login_data, verify=False)
```

### 2. CSRF トークンの取得

**【課題】** 設定変更（POST）に必要な X-XSRF-TOKEN を取得せよ。
```python
token_resp = session.get(f'{base_url}/dataservice/client/token', verify=False)
xsrf_token = token_resp.text
session.headers.update({'X-XSRF-TOKEN': xsrf_token})
```

### 3. デバイスインベントリの取得 (Monitoring)

**【課題】** ファブリック内の全デバイスのホスト名と Reachability をリストアップせよ。
```python
devices = session.get(f'{base_url}/dataservice/device', verify=False).json()
for dev in devices['data']:
    print(f"Host: {dev['host-name']}, Status: {dev['reachability']}")
```

### 4. 特定サイトのデバイスフィルタリング

**【課題】** Site ID 200 に属するデバイスのみを抽出せよ。
```python
site_200_devs = [d for d in devices['data'] if d['site-id'] == '200']
```

### 5. デバイス統計情報の取得

**【課題】** 特定のデバイス (System-IP: 1.1.1.1) の CPU 使用率を取得せよ。
```python
cpu_url = f"{base_url}/dataservice/device/system/cpu?deviceId=1.1.1.1"
stats = session.get(cpu_url, verify=False).json()
```

### 6. デバイステンプレートの一覧取得 (Configuration)

**【課題】** vManage に登録されている全テンプレートの名前と ID を取得せよ。
```python
templates = session.get(f'{base_url}/dataservice/template/device', verify=False).json()
for t in templates['data']:
    print(f"Template Name: {t['templateName']}, ID: {t['templateId']}")
```

### 7. 未使用テンプレートの特定
**【課題】** どのデバイスにもアタッチされていないテンプレートを探せ。
```python
unused = [t['templateName'] for t in templates['data'] if t['devicesAttached'] == 0]
```

### 8. アラーム情報の抽出
**【課題】** 過去 24 時間以内に発生した「Critical」アラームの数をカウントせよ。
```python
alarms = session.get(f'{base_url}/dataservice/alarm', verify=False).json()
critical_count = len([a for d in alarms['data'] if a['severity'] == 'Critical'])
```

### 9. デバイステンプレートのアタッチ（非同期実行）

**【課題】** テンプレートをデバイスに適用し、返された `processId` を取得せよ。
```python
payload = {
    "templateId": "uuid-xxxx-yyyy",
    "deviceIds": ["1.1.1.1"]
}
attach_resp = session.post(f'{base_url}/dataservice/template/device/config/attachfeature', json=payload).json()
task_id = attach_resp['id']
```

### 10. ジョブステータスのポーリング監視

**【課題】** 上記 `task_id` の進捗を 5 秒おきに確認し、完了まで待機せよ。
```python
import time
while True:
    status = session.get(f'{base_url}/dataservice/device/action/status/{task_id}').json()
    if status['summary']['status'] == 'done':
        print("Configuration push successful!")
        break
    time.sleep(5)
```

### 11. API によるデバイスのリブート要請

**【課題】** 特定の cEdge を API 経由で再起動せよ。
```python
reboot_payload = {"deviceType": "vbolt", "devices": [{"deviceIP": "1.1.1.1"}]}
session.post(f'{base_url}/dataservice/device/action/reboot', json=reboot_payload)
```

### 12. 応答データのエラーハンドリング

**【課題】** API コールが失敗した場合にステータスコードを確認するロジック。
```python
resp = session.get(api_url)
if resp.status_code != 200:
    print(f"Error occurred: {resp.status_code}, Msg: {resp.text}")
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**DEVNET-2096: Demystifying Cisco SD-WAN APIs to Automate Cloud OnRamp**](https://www.ciscolive.com/global/on-demand-library.html?search=DEVNET-2096)
*   [**BRKCRT-1385: The CCIE in an SDN World - SD-WAN Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)

### Configuration ガイド
*   [**Cisco SD-WAN vManage API Reference (DevNet)**](https://developer.cisco.com/docs/sdwan/#!api-reference)
*   [**Cisco IOS XE 17.x: SD-WAN Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/sdwan-xe-gs-book/m-sdwan-xe-gs-book-wrapper.html)

### テクニカルドキュメント・設定例
*   [**Working with Cisco SD-WAN REST API (Learning Lab)**](https://developer.cisco.com/learning/modules/sdwan-rest-api)
*   [**Authentication and Authorization for vManage API**](https://www.cisco.com/c/en/us/support/docs/routers/sdwan/214643-vmanage-rest-api-authentication.html)

---
## 📝 補足

この学習メモは、CCIE EI 実技試験において **「SD-WAN の運用管理をいかに効率化し、正確な状態把握を行うか」** というプログラマビリティの真髄を網羅しています。ラボ試験では、API を通じたテンプレート操作の正確性と、非同期ジョブの管理能力が合格への分かれ目となります。

- 補足情報をここに追加してください。

