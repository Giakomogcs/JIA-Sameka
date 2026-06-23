#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Captura screenshots do front Sameka (servido em 127.0.0.1:5501) com Playwright.

Usa o canal do navegador já instalado (msedge/chrome) para evitar download.
Salva PNGs em clients/<slug>/screenshots/ com os nomes referenciados no content.json.
"""
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:5501/front-sameka.html"
SLUG = "sameka"
SHOTS = Path(__file__).resolve().parent.parent / "clients" / SLUG / "screenshots"
SHOTS.mkdir(parents=True, exist_ok=True)


def launch(p):
    for channel in ("msedge", "chrome"):
        try:
            return p.chromium.launch(channel=channel, headless=True)
        except Exception:
            continue
    return p.chromium.launch(headless=True)


def main():
    with sync_playwright() as p:
        browser = launch(p)
        page = browser.new_page(viewport={"width": 1366, "height": 860})
        page.goto(URL, wait_until="networkidle", timeout=30000)
        page.wait_for_timeout(1500)

        # 00 / 05 — tela de login (overlay visível ao abrir)
        page.screenshot(path=str(SHOTS / "00-front-login.png"))
        page.screenshot(path=str(SHOTS / "05-smoke-login.png"))
        print("OK 00-front-login.png")
        print("OK 05-smoke-login.png")

        # 00 — tela de chat: tenta dispensar o overlay de login para revelar o app
        try:
            page.evaluate(
                "() => { const o = document.getElementById('loginOverlay');"
                " if (o) o.style.display = 'none'; }"
            )
            page.wait_for_timeout(800)
        except Exception:
            pass
        page.screenshot(path=str(SHOTS / "00-front-chat.png"))
        print("OK 00-front-chat.png")

        browser.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"FALHA captura: {e}")
        sys.exit(1)
