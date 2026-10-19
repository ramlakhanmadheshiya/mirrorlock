#!/usr/bin/env python3
"""The in-app products Mirrorlock sells, and a way to create them on Google Play.

  python3 store/play_products.py list                  # print every product and price
  python3 store/play_products.py csv > products.csv    # the same, as CSV
  python3 store/play_products.py create KEY.json       # create them through the API

`create` uses the Google Play Android Developer API (in-app products) with a
service account JSON key (Play Console > Users and permissions: invite the service
account with permission to manage the app's products). It needs:
  python3 -m pip install google-auth requests
Products that already exist are skipped, so it is safe to run again.

Prices are set in Indian rupees; Play converts them for other countries.
The product IDs must match game/autoload/store.gd.
"""
import csv
import json
import sys

PACKAGE = "com.theramlakhan.mirrorlock"
CURRENCY = "INR"

# One-time packs (kept forever, restorable).
PACKS = [
    ("complete_pack", "Complete pack", "No ads, 6 free hints a day, all themes and mirror styles, 1,000 coins and 5 level keys.", 449),
    ("supporter_pack", "Supporter pack", "No banner ads, and 6 free hints every day.", 249),
    ("theme_pack", "Theme pack", "Eleven colour themes for the whole app, light and dark.", 149),
    ("style_pack", "Mirror styles", "Six new looks for the twin pieces.", 149),
]

# Coin bags (consumable): id, coins, name, price in rupees. Must match Store.COIN_PACKS.
COINS = [
    ("coins_100", 100, "Pinch", 29), ("coins_250", 250, "Little pile", 69), ("coins_300", 300, "Handful", 79),
    ("coins_500", 500, "Purse", 119), ("coins_750", 750, "Bag", 139), ("coins_1000", 1000, "Pouch", 149),
    ("coins_1500", 1500, "Sack", 199), ("coins_2000", 2000, "Big sack", 229), ("coins_2500", 2500, "Chest", 249),
    ("coins_6000", 6000, "Treasure", 449),
]

CHAPTER_KEY_PRICE = 99  # per chapter key
CHAPTER_KEY_MAX = 5
KEY_PRICE = 30          # per key
KEY_BULK = 5            # buying this many or more ...
KEY_DISCOUNT = 0.10     # ... takes 10% off
KEY_MAX = 10
TIP_MIN, TIP_MAX, TIP_STEP = 10, 1000, 10


def products():
    out = []
    for pid, title, desc, price in PACKS:
        out.append({"id": pid, "title": title, "description": desc, "price": price, "kind": "pack"})
    for pid, coins, name, price in COINS:
        out.append({"id": pid, "title": f"{coins:,} coins", "description": f"A {name.lower()} of {coins:,} coins for hints and hearts.", "price": price, "kind": "consumable"})
    for n in range(1, CHAPTER_KEY_MAX + 1):
        out.append({
            "id": f"chapter_keys_{n}",
            "title": f"{n} chapter key" + ("s" if n > 1 else ""),
            "description": "Opens a locked chapter at its level 1." if n == 1 else f"{n} keys. Each opens a locked chapter at its level 1.",
            "price": n * CHAPTER_KEY_PRICE,
            "kind": "consumable",
        })
    for n in range(1, KEY_MAX + 1):
        price = n * KEY_PRICE * (1 - KEY_DISCOUNT if n >= KEY_BULK else 1)
        out.append({
            "id": f"keys_{n}",
            "title": f"{n} level key" + ("s" if n > 1 else ""),
            "description": "A key opens any locked level for good." if n == 1 else f"{n} keys. Each opens any locked level for good.",
            "price": round(price),
            "kind": "consumable",
        })
    for r in range(TIP_MIN, TIP_MAX + 1, TIP_STEP):
        out.append({
            "id": f"tip_{r}",
            "title": f"Tip ₹{r}",
            "description": "A thank-you to the developer. Opens nothing new.",
            "price": r,
            "kind": "consumable",
        })
    return out


def cmd_list():
    for p in products():
        print(f"{p['id']:16s} ₹{p['price']:<5d} {p['kind']:10s} {p['title']}")
    print(f"\n{len(products())} products")


def cmd_csv():
    w = csv.writer(sys.stdout)
    w.writerow(["product_id", "title", "description", "price_inr", "kind"])
    for p in products():
        w.writerow([p["id"], p["title"], p["description"], p["price"], p["kind"]])


def cmd_create(key_path):
    from google.oauth2 import service_account
    from google.auth.transport.requests import AuthorizedSession

    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    session = AuthorizedSession(creds)
    base = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PACKAGE}/inappproducts"
    existing = set()
    token = None
    while True:
        r = session.get(base, params={"token": token} if token else {})
        r.raise_for_status()
        data = r.json()
        existing |= {p["sku"] for p in data.get("inappproduct", [])}
        token = data.get("tokenPagination", {}).get("nextPageToken")
        if not token:
            break
    made = 0
    for p in products():
        if p["id"] in existing:
            print(f"skip   {p['id']} (exists)")
            continue
        body = {
            "packageName": PACKAGE,
            "sku": p["id"],
            "status": "active",
            "purchaseType": "managedUser",
            "defaultLanguage": "en-US",
            "listings": {"en-US": {"title": p["title"], "description": p["description"]}},
            "defaultPrice": {"priceMicros": str(p["price"] * 1_000_000), "currency": CURRENCY},
        }
        r = session.post(base, params={"autoConvertMissingPrices": "true"}, data=json.dumps(body),
                         headers={"Content-Type": "application/json"})
        if r.ok:
            made += 1
            print(f"create {p['id']} ₹{p['price']}")
        else:
            print(f"FAILED {p['id']}: {r.status_code} {r.text[:300]}")
    print(f"\nCreated {made}, skipped {len(existing & {p['id'] for p in products()})}.")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        cmd_list()
    elif sys.argv[1] == "csv":
        cmd_csv()
    elif sys.argv[1] == "create" and len(sys.argv) == 3:
        cmd_create(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(1)
