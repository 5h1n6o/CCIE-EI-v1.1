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



