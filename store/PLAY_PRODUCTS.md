# Google Play products for Mirrorlock

Every id below must exist in the Play Console (Monetize › Products › In-app products)
before the shop works in a Play build. Prices are set in the Console; the game shows
Google Play's localised price and falls back to the regional prices in
`game/autoload/store.gd` until Play answers. `python3 store/play_products.py create KEY.json`
creates all of them (see `store/PLAY_CONSOLE.md`).

| Product id | Type | What it gives | Price |
|---|---|---|---|
| `complete_pack` | One-time (non-consumable) | Everything: no banner ads, 6 free hints a day, all themes and mirror styles, plus 1,000 coins and 5 level keys (granted once) | ₹449 / $5.99 |
| `supporter_pack` | One-time | No banner ads, 6 free hints a day instead of 3 | ₹249 / $2.99 |
| `theme_pack` | One-time | 11 colour themes (1-hour trial from a video) | ₹149 / $1.99 |
| `style_pack` | One-time | 6 mirror styles for the twin pieces (1-hour trial from a video) | ₹149 / $1.99 |
| `coins_100` | Consumable | 100 coins | ₹29 / $0.49 |
| `coins_250` | Consumable | 250 coins | ₹69 / $0.89 |
| `coins_300` | Consumable | 300 coins | ₹79 / $0.99 |
| `coins_500` | Consumable | 500 coins | ₹119 / $1.49 |
| `coins_750` | Consumable | 750 coins | ₹139 / $1.79 |
| `coins_1000` | Consumable | 1,000 coins | ₹149 / $1.99 |
| `coins_1500` | Consumable | 1,500 coins | ₹199 / $2.49 |
| `coins_2000` | Consumable | 2,000 coins | ₹229 / $2.79 |
| `coins_2500` | Consumable | 2,500 coins | ₹249 / $2.99 |
| `coins_6000` | Consumable | 6,000 coins | ₹449 / $5.99 |
| `chapter_keys_1` … `chapter_keys_5` | Consumable | 1–5 chapter keys (₹99 / $1.29 each): each opens a locked chapter at its level 1 | ₹99 × n |
| `keys_1` … `keys_10` | Consumable | 1–10 level keys (₹30 / $0.49 each, 10% off for 5+) | ₹30 × n |
| `tip_10` … `tip_1000` (steps of 10), `tip_1100` … `tip_10000` (steps of 100) | Consumable | A tip: nothing unlocked (priced in rupees; Play shows each player their own currency) | ₹ in the id |

219 products in all. Consumables are consumed after granting, so they can be bought
again. One-time packs are acknowledged and restored on every launch and from
**Restore purchases**.

Coins buy hints (30 coins, once the 3 free ones each day are used) and an extra heart
after running out (40 coins).

## Tip ids (190)

Each is a consumable priced at the rupee amount in its id; Google Play converts it for
other countries, and the game shows each player Play's price in their own currency.

`tip_10`, `tip_20`, `tip_30`, `tip_40`, `tip_50`, `tip_60`, `tip_70`, `tip_80`, `tip_90`, `tip_100`, `tip_110`, `tip_120`, `tip_130`, `tip_140`, `tip_150`, `tip_160`, `tip_170`, `tip_180`, `tip_190`, `tip_200`, `tip_210`, `tip_220`, `tip_230`, `tip_240`, `tip_250`, `tip_260`, `tip_270`, `tip_280`, `tip_290`, `tip_300`, `tip_310`, `tip_320`, `tip_330`, `tip_340`, `tip_350`, `tip_360`, `tip_370`, `tip_380`, `tip_390`, `tip_400`, `tip_410`, `tip_420`, `tip_430`, `tip_440`, `tip_450`, `tip_460`, `tip_470`, `tip_480`, `tip_490`, `tip_500`, `tip_510`, `tip_520`, `tip_530`, `tip_540`, `tip_550`, `tip_560`, `tip_570`, `tip_580`, `tip_590`, `tip_600`, `tip_610`, `tip_620`, `tip_630`, `tip_640`, `tip_650`, `tip_660`, `tip_670`, `tip_680`, `tip_690`, `tip_700`, `tip_710`, `tip_720`, `tip_730`, `tip_740`, `tip_750`, `tip_760`, `tip_770`, `tip_780`, `tip_790`, `tip_800`, `tip_810`, `tip_820`, `tip_830`, `tip_840`, `tip_850`, `tip_860`, `tip_870`, `tip_880`, `tip_890`, `tip_900`, `tip_910`, `tip_920`, `tip_930`, `tip_940`, `tip_950`, `tip_960`, `tip_970`, `tip_980`, `tip_990`, `tip_1000`, `tip_1100`, `tip_1200`, `tip_1300`, `tip_1400`, `tip_1500`, `tip_1600`, `tip_1700`, `tip_1800`, `tip_1900`, `tip_2000`, `tip_2100`, `tip_2200`, `tip_2300`, `tip_2400`, `tip_2500`, `tip_2600`, `tip_2700`, `tip_2800`, `tip_2900`, `tip_3000`, `tip_3100`, `tip_3200`, `tip_3300`, `tip_3400`, `tip_3500`, `tip_3600`, `tip_3700`, `tip_3800`, `tip_3900`, `tip_4000`, `tip_4100`, `tip_4200`, `tip_4300`, `tip_4400`, `tip_4500`, `tip_4600`, `tip_4700`, `tip_4800`, `tip_4900`, `tip_5000`, `tip_5100`, `tip_5200`, `tip_5300`, `tip_5400`, `tip_5500`, `tip_5600`, `tip_5700`, `tip_5800`, `tip_5900`, `tip_6000`, `tip_6100`, `tip_6200`, `tip_6300`, `tip_6400`, `tip_6500`, `tip_6600`, `tip_6700`, `tip_6800`, `tip_6900`, `tip_7000`, `tip_7100`, `tip_7200`, `tip_7300`, `tip_7400`, `tip_7500`, `tip_7600`, `tip_7700`, `tip_7800`, `tip_7900`, `tip_8000`, `tip_8100`, `tip_8200`, `tip_8300`, `tip_8400`, `tip_8500`, `tip_8600`, `tip_8700`, `tip_8800`, `tip_8900`, `tip_9000`, `tip_9100`, `tip_9200`, `tip_9300`, `tip_9400`, `tip_9500`, `tip_9600`, `tip_9700`, `tip_9800`, `tip_9900`, `tip_10000`

## Ads (AdMob)

Set three repository secrets so CI builds use the real units (otherwise Google's test
units are used): `ADMOB_APP_ID`, `ADMOB_BANNER_ID` (anchored adaptive banner) and
`ADMOB_REWARDED_ID` (rewarded video). Banners show at the bottom of every screen
except for Supporters, with their space reserved so the layout never jumps; they load
a fresh ad when the player changes screens, at most once every 30 seconds. Rewarded
videos only play when the player asks (a hint or a heart when out of coins, free coins,
a free level or chapter key, or a 1-hour pack trial). There are no full-screen ads
between levels.
