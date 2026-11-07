# ASO plan for 2.0 (App Store and Google Play)

Written 2026-11-05. Companion to `DECISION_PACK.md` (section 4, en-US keywords and ar/es/de notes), `COMPETITOR_RESEARCH.md` (positioning) and `ROADMAP.md` (section F). The store copy itself lives in `fastlane/metadata_v2/` and uses the token `{{APP_NAME}}` until the name is final.

Positioning in one line: **everyone, every phone, every country.** Scan it, say who had what, every cent accounted for, friends pay from a link, settle in fewer payments, any currency in 22 languages, no daily limit.

## 1. What is in `fastlane/metadata_v2/`

| Store | Locales | Files per locale |
|---|---|---|
| App Store (28) | ar-SA, da, de-DE, en-US, en-GB, en-AU, en-CA, es-ES, es-MX, fr-FR, fr-CA, hi, id, it, ja, ko, no, nl-NL, pl, pt-BR, pt-PT, ru, sv, th, tr, vi, zh-Hans, zh-Hant | `name.txt`, `subtitle.txt`, `keywords.txt`, `promotional_text.txt`, `description.txt`, `release_notes.txt`, plus `marketing_url.txt`, `support_url.txt`, `privacy_url.txt` copied unchanged from `fastlane/metadata/en-US` |
| Google Play (26) | ar, da-DK, de-DE, en-US, en-GB, es-ES, es-419, fr-FR, hi-IN, id, it-IT, ja-JP, ko-KR, no-NO, nl-NL, pl-PL, pt-BR, pt-PT, ru-RU, sv-SE, th, tr-TR, ur, vi, zh-CN, zh-TW | `title.txt`, `short_description.txt`, `full_description.txt`, `changelogs/24.txt` (pubspec is `1.2.0+23`, so the next versionCode is 24; rename the file if the 2.0 build number ends up different) |

Notes on the locale map:

- **Urdu has no App Store Connect locale.** The app's 22 languages map to 28 ASC locales (English ×4, Spanish ×2, French ×2, Portuguese ×2, Chinese ×2) and 26 Play locales. The old `fastlane/metadata/ur` folder is never uploaded (it is not in `IOS_APP_STORE_LOCALES` in the Fastfile) and `fastlane/metadata/hr` is English copy that should be removed when `metadata_v2` replaces `metadata`.
- Play en-AU, en-CA, fr-CA and es-US were not written; Play falls back to en-US / fr-FR / es-419 for those storefronts. Add them later if a Play experiment shows a lift from local spelling.
- Since 2.0 the Fastfile reads `fastlane/metadata_v2` (iOS, all 28 locales) and `fastlane/metadata_v2/android`. `fastlane/metadata` is the 1.2.x copy and is no longer uploaded; remove it after the 2.0 release ships.

### Generator and validator

The copy is generated from Python data modules (one dict per language, with `{NAME}`, `{PAY}` and `{LEGAL}` tokens) and validated by a script that counts Unicode code points after NFC normalisation, substitutes `{{APP_NAME}}` with a 9-character placeholder, and checks:

- App Store: name ≤ 30, subtitle ≤ 30, keywords ≤ 100 (no space after commas, no duplicates, no word repeated from name or subtitle, no competitor or payment-brand trademarks), promotional text ≤ 170, description and release notes ≤ 4000, every locale has the three URL files.
- Google Play: title ≤ 30, short description ≤ 80, full description ≤ 4000, changelog ≤ 500, no "Apple ID" or "Apple Cash" in the Play text.

The scripts live in `tool/aso/` (`gen.py`, `validate.py`, `copy_en.py`, `copy_eu.py`, `copy_asia.py`) and write the final name "Evens" directly. Current result: 28 iOS locales, 26 Play locales, 0 errors. The per-market keyword map is in `ASO_KEYWORDS.md`.

### Title rule

The name is **Evens** (5 characters), so every title suffix may be up to 23 characters. English titles use the long form `Evens: Split Bills & Receipts` with subtitle `AI Scanner, Groups & Settle Up`; the other markets carry their top phrase plus, where it fits, the second one (section 9 and `ASO_KEYWORDS.md`).

## 2. Keyword strategy per market

The per-locale fields as shipped in 2.0 (titles, subtitles, keyword fields, Play titles and short descriptions, and the cross-localization map) are in `ASO_KEYWORDS.md`; the market notes below explain the intent behind them and some field values here predate the final name.

General rules that apply everywhere:

1. Title and subtitle carry the two highest-volume phrases of the market (usually *split bills* + *receipt scanner* / *settle up*). The keyword field holds single words that combine with them; Apple matches across fields, so *expense* + *Split* gives *split expense*.
2. Never put competitor names (Splitwise, Tricount, Settle Up, Splid, Tab, Spliit) or payment brands in the keyword field. They are allowed in the description only as integrations we actually have (Venmo, Pix, UPI, Swish), and in landing-page comparison pages.
3. Search volumes below are **unverified**. Before locking each market, check Apple Search Ads popularity (free with an Apple Search Ads account) and, if budget allows, one ASO tool (AppTweak, Astro or Sensor Tower). Replace the two lowest-popularity words per field with the two best suggestions.
4. Several storefronts index a second locale's keyword field. The best-known pair is **US ↔ es-MX** (so es-MX is a second 100-character field for the US). Confirm the others in an ASO tool's locale map before relying on them; do not duplicate words across the two fields of one storefront.
5. Google Play has no keyword field. The ranking signals we control are the title, the first 80 characters (short description), the first lines of the full description, and the section headers, which is why every `full_description.txt` repeats the core phrases as headers ("Scan it", "Friends pay from a link", "Settle in fewer payments").

### United States (en-US, plus es-MX as the second field)

- Intent: *split bill app*, *split the bill*, *bill splitter*, *receipt splitter*, *split expenses with roommates*, *group trip expenses*, *IOU*, *who owes what*. US users also search *tip calculator* and *check splitter*.
- Title: `{{APP_NAME}}: Split Group Bills`. Subtitle: `AI Receipt Scanner & Settle Up`.
- Keywords (99): `expense,trip,roommate,friends,dinner,tip,owe,iou,share,travel,voice,dutch,pay,calculator,debt,check`. "voice" and "dutch" are deliberate: nobody else ranks for *voice* in this category, and *go dutch* is a real query. "check" covers *split the check*.
- es-MX (second US field): `gastos,compartidos,grupo,viaje,amigos,roomies,cena,propina,vaquita,pagar,ia,reparto,cuentas claras`. *vaquita* and *cuentas claras* are LATAM idioms with no competitor coverage.
- Context: Splitwise Itemize (free, US and UK) and Apple Cash Split Bill (US only) mean "scan a receipt" is no longer a differentiator here. Lead screenshots with *say who had what* and *friends pay from a link, any phone*.

### United Kingdom (en-GB), Australia (en-AU), Canada (en-CA)

- UK intent adds *flatmate*, *holiday*, *kitty*, *bill splitting app*, *split the bill restaurant*. AU: *housemate*, *mates*, *shout*. CA: *etransfer* (people search it as one word), *roommate*, *cottage trip*.
- Keywords: en-GB `expense,holiday,flatmate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,kitty`; en-AU swaps in `housemate,mates`; en-CA swaps in `etransfer`.
- Description payment line names the local rails (Faster Payments and Monzo; PayID; Interac e-Transfer). This is the "every country" proof point and it is unique in the category.

### Germany, Austria, Switzerland (de-DE)

- German is compound-heavy: *Rechnung teilen*, *Kosten teilen*, *Ausgaben teilen*, *Gruppenkasse*, *Reisekasse*, *WG Kosten*, *Kassenbon scannen*, *Beleg*. Tricount and Splid are very strong in DACH on the generic terms, so the long tail around scanning (*Kassenbon scannen*, *Beleg*) and voice is where we can rank first.
- Title: `{{APP_NAME}}: Rechnungen teilen`. Subtitle: `Kassenbon scannen & abrechnen`.
- Keywords (100): `kosten,ausgaben,gruppe,reise,wg,urlaub,freunde,essen,trinkgeld,schulden,splitten,reisekasse,beleg,ki`. *Gruppenkasse* was cut for length; "gruppe" + "kasse" is not an exact match, so test re-adding *gruppenkasse* in place of *reisekasse* in a later keyword iteration.
- CH: TWINT is copy-only in the app (no public link), so do not promise "pay with TWINT in one tap" in Swiss creative; "copies the TWINT number and amount" is accurate.

### Netherlands and Belgium (nl-NL)

- Intent: *rekening splitsen*, *kosten delen*, *wie betaalt wat*, *uitgaven delen*, *potje*, *huisgenoten*, *etentje*. Tikkie is the cultural reference; the app opens a stored Tikkie link, so the description can say "Tikkie-link" but the keyword field must not (trademark).
- Title: `{{APP_NAME}}: Rekening splitsen`. Subtitle: `Bonnetje scannen & verrekenen`.
- Keywords (100): `kosten,delen,uitgaven,groep,vakantie,vrienden,etentje,huisgenoten,schuld,reis,fooi,verdelen,potje,ai`.
- Wero replaces Payconiq in BE during 2026; the description already names Wero and SEPA-QR.

### Nordics (sv, da, no)

- Small, high-paying markets where local payment rails are the hook: Swish (SE, prefilled app-switch link), MobilePay (DK, copy), Vipps (NO, copy). Intent: *dela notan*, *dela på notan*, *splitta kostnader*, *del regningen*, *dele udgifter*, *dele regningen*.
- Titles: `Dela notan` / `Del regningen` / `Del regningen`. Subtitles name scanning plus *gör upp* / *afregn* / *gjør opp*.
- Keywords avoid the rail brands and carry *kompisar/venner*, *semester/ferie*, *kollektiv/bofæller*, *dricks/drikkepenge/tips*, *skuld/gæld/gjeld*.
- Danish and Finnish MobilePay become Vipps from January 2027: plan a metadata refresh then (description only).

### Gulf and MENA (ar-SA, with the English field as the second locale)

- The Saudi, UAE, Kuwait and Qatar storefronts index Arabic and an English locale, so Arabic and English never need to duplicate each other. Arabic intent in MSA and Gulf dialect: *تقسيم الفاتورة*, *تقسيم المصاريف*, *نص نص*, *حاسبة القسمة*, *كم عليك*. Egyptians also search in Latin script ("split bill", "instapay").
- Title: `{{APP_NAME}}: قسّم الفاتورة`. Subtitle: `امسح الإيصال وسوّي الحساب`.
- Keywords (100): `مصاريف,مشتركة,مجموعة,رحلة,أصدقاء,عشاء,نص نص,ديون,تقسيم,حاسبة,ذكاء اصطناعي,سكن,سفر,ادفع,كم عليك`. Apple treats the definite-article form (الـ) and the bare form as different tokens; the title has الفاتورة, the field has bare nouns, so both forms are covered.
- Description names sarie, STC Bank, urpay (SA), Aani (AE), InstaPay and Vodafone Cash (EG). Ramadan and Eid in-app events (section 4) are the seasonal lever here. Arabic screenshots must be RTL-mirrored, not just translated.

### Japan (ja)

- Japanese users search *割り勘* (warikan) overwhelmingly, then *割り勘 アプリ*, *立て替え*, *精算*, *飲み会*, *幹事*. Katakana and hiragana variants (*ワリカン*, *わりかん*) are separate tokens; the field includes *ワリカン*.
- Title: `{{APP_NAME}}: 割り勘アプリ`. Subtitle: `レシートをAIで読み取り精算`.
- Keywords (59, room to grow): `立て替え,旅行,飲み会,グループ,友達,ルームシェア,計算,幹事,支払い,共有,経費,ワリカン,送金,合宿,家計,請求`. Candidate additions after popularity checks: *わりかん*, *旅費*, *会計*, *おごり*.
- PayPay is copy-only (no public P2P link). Copy says "PayPay で支払い" which is accurate because the payer opens PayPay with the ID and amount on the clipboard.

### Korea (ko)

- Intent: *더치페이*, *엔빵* / *n빵* / *1/n*, *정산*, *회비*, *모임 통장*, *총무*. Toss opens as a recipient link; KakaoPay is copy-only.
- Title: `{{APP_NAME}}: 더치페이 정산`. Subtitle: `영수증 스캔, 누가 얼마 냈는지`.
- Keywords (58, room to grow): `엔빵,n빵,1/n,계산,모임,여행,회비,친구,룸메이트,회식,송금,공동,경비,가계부,ai,총무,나누기,공금`. Candidate additions: *더치*, *정산앱*, *모임통장*.

### Other locales in the set (summary)

| Locale | Title suffix | Idioms used in keywords |
|---|---|---|
| es-ES | Dividir la cuenta | *a medias*, *bote*, *piso* |
| fr-FR / fr-CA | Partager l'addition / Séparer la facture | *coloc*, *note*, *dettes*, *virement* (CA) |
| it | Dividi il conto | *alla romana*, *coinquilini* |
| pt-BR / pt-PT | Dividir a conta | *rachar*, *vaquinha*, *rateio* / *partilha* |
| pl | Dzielenie rachunku | *kto ile*, *rozliczenie*, *wspólne* |
| ru | Делим счёт | *скинуться*, *поровну*, *кто сколько* |
| tr | Hesap Bölüşme | *ortak masraf*, *ev arkadaşı*, *gider* |
| hi | बिल बांटें | Hinglish: *udhaar*, *hisab*, *kharcha*, *split*, *expense* (India searches in English and Hinglish) |
| id | Bagi Tagihan | *patungan*, *split bill*, *kos* |
| th | หารบิล | *หารกัน*, *ค่ากิน*, *ใครกิน* |
| vi | Chia hóa đơn | *hùn*, *góp*, *quỹ*, *share* |
| zh-Hans / zh-Hant | AA制分账 / 分帳拆帳 | *分摊/分攤*, *均摊/均分*, *合租*, *代墊* (TW) |

## 3. Screenshot caption set (v3 design)

Seven captions per locale, in this order. Screens 1–6 are mandatory; screen 7 ("Free, no daily limits") is the conversion closer and can be dropped on the 5.5-inch set. Captions are headline only; the sub-caption (smaller) is the same for all: the app name plus a short proof line, which the production script fills from the table.

| Locale | 1 Scan | 2 Voice | 3 Breakdown | 4 Guest link | 5 Settle | 6 Currency | 7 Free |
|---|---|---|---|---|---|---|---|
| en-US / en-CA | Scan it | Say who had what | Every cent accounted for | Friends pay from a link | Settle in fewer payments | Any currency, 22 languages | Free, no daily limits |
| en-GB / en-AU | Scan it | Say who had what | Every penny accounted for | Mates pay from a link | Settle in fewer payments | Any currency, 22 languages | Free, no daily limits |
| de-DE | Scannen | Sagen, wer was hatte | Jeder Cent nachvollziehbar | Freunde zahlen per Link | Mit weniger Zahlungen ausgleichen | Jede Währung, 22 Sprachen | Kostenlos, ohne Tageslimit |
| nl-NL | Scan de bon | Zeg wie wat had | Elke cent verantwoord | Vrienden betalen via een link | Verrekenen met minder betalingen | Elke valuta, 22 talen | Gratis, zonder daglimiet |
| sv | Skanna | Säg vem som tog vad | Varje öre redovisat | Vänner betalar via en länk | Gör upp med färre betalningar | Alla valutor, 22 språk | Gratis, utan dagsgräns |
| da | Scan | Sig hvem der fik hvad | Hver øre gjort op | Venner betaler via et link | Afregn med færre betalinger | Alle valutaer, 22 sprog | Gratis, uden dagligt loft |
| no | Skann | Si hvem som fikk hva | Hvert øre gjort rede for | Venner betaler via en lenke | Gjør opp med færre betalinger | Alle valutaer, 22 språk | Gratis, uten dagsgrense |
| fr-FR | Scannez | Dites qui a pris quoi | Chaque centime justifié | Vos amis paient depuis un lien | Réglez en moins de paiements | Toutes les devises, 22 langues | Gratuit, sans limite quotidienne |
| fr-CA | Scannez | Dites qui a pris quoi | Chaque cent justifié | Vos amis paient depuis un lien | Réglez en moins de paiements | Toutes les devises, 22 langues | Gratuit, sans limite quotidienne |
| es-ES | Escanéalo | Di quién pidió qué | Cada céntimo justificado | Tus amigos pagan desde un enlace | Salda con menos pagos | Cualquier moneda, 22 idiomas | Gratis, sin límite diario |
| es-MX / es-419 | Escanéalo | Di quién pidió qué | Cada centavo justificado | Tus amigos pagan desde un enlace | Salda con menos pagos | Cualquier moneda, 22 idiomas | Gratis, sin límite diario |
| it | Scansiona | Di' chi ha preso cosa | Ogni centesimo giustificato | Gli amici pagano da un link | Salda con meno pagamenti | Qualsiasi valuta, 22 lingue | Gratis, senza limite giornaliero |
| pt-BR | Escaneie | Diga quem pediu o quê | Cada centavo justificado | Seus amigos pagam por um link | Acerte com menos pagamentos | Qualquer moeda, 22 idiomas | Grátis, sem limite diário |
| pt-PT | Digitaliza | Diz quem pediu o quê | Cada cêntimo justificado | Os amigos pagam por um link | Acerta com menos pagamentos | Qualquer moeda, 22 idiomas | Grátis, sem limite diário |
| pl | Zeskanuj | Powiedz, kto co zamówił | Każdy grosz rozliczony | Znajomi płacą z linku | Rozlicz mniejszą liczbą przelewów | Każda waluta, 22 języki | Za darmo, bez dziennego limitu |
| ru | Сканируйте | Скажите, кто что брал | Каждая копейка учтена | Друзья платят по ссылке | Меньше переводов при расчёте | Любая валюта, 22 языка | Бесплатно, без дневного лимита |
| tr | Tara | Kim ne aldı söyle | Her kuruşun hesabı belli | Arkadaşların bağlantıdan öder | Daha az ödemeyle hesaplaş | Her para birimi, 22 dil | Ücretsiz, günlük sınır yok |
| ar-SA / ar | امسح الإيصال | قل من أخذ ماذا | كل قرش محسوب | أصدقاؤك يدفعون من رابط | سوّي الحساب بتحويلات أقل | أي عملة، 22 لغة | مجاني، بلا حد يومي |
| hi / hi-IN | स्कैन करें | बोलें किसने क्या लिया | हर पैसे का हिसाब | दोस्त लिंक से चुकाते हैं | कम पेमेंट में हिसाब चुकता | कोई भी करेंसी, 22 भाषाएं | मुफ़्त, कोई दैनिक सीमा नहीं |
| ur (Play) | اسکین کریں | بولیں کس نے کیا لیا | ہر پیسے کا حساب | دوست لنک سے ادا کرتے ہیں | کم ادائیگیوں میں حساب برابر | کوئی بھی کرنسی، 22 زبانیں | مفت، کوئی روزانہ حد نہیں |
| id | Pindai | Sebut siapa makan apa | Tiap rupiah jelas | Teman bayar lewat tautan | Lunasi dengan lebih sedikit transfer | Mata uang apa pun, 22 bahasa | Gratis, tanpa batas harian |
| ja | レシートを撮る | 誰が何を食べたか話す | 1円まで明細に | 友達はリンクから支払い | 最少回数で精算 | あらゆる通貨、22言語 | 無料、1日の上限なし |
| ko | 영수증 스캔 | 누가 뭘 먹었는지 말하기 | 1원까지 정확하게 | 친구는 링크에서 송금 | 더 적은 송금으로 정산 | 모든 통화, 22개 언어 | 무료, 하루 제한 없음 |
| th | สแกน | บอกว่าใครกินอะไร | ทุกสตางค์มีที่มา | เพื่อนจ่ายจากลิงก์ | เคลียร์ด้วยการโอนที่น้อยลง | ทุกสกุลเงิน 22 ภาษา | ฟรี ไม่จำกัดต่อวัน |
| vi | Quét | Nói ai ăn gì | Từng đồng rõ ràng | Bạn bè trả qua link | Thanh toán với ít lần chuyển hơn | Mọi loại tiền, 22 ngôn ngữ | Miễn phí, không giới hạn mỗi ngày |
| zh-Hans / zh-CN | 扫小票 | 说一句谁吃了什么 | 每一分钱都有去向 | 朋友点开链接付款 | 用更少的转账结清 | 任何货币，22 种语言 | 免费，不限每日次数 |
| zh-Hant / zh-TW | 掃收據 | 說一句誰吃了什麼 | 每一塊錢都有去向 | 朋友點開連結付款 | 用更少的轉帳結清 | 任何貨幣，22 種語言 | 免費，不限每日次數 |

Design rules (v3 "Quiet ledger"): one device per frame, caption top-left in the display face, the accent colour only on the one element the caption is about (the voice chip, the share breakdown, the pay button). Screen 4 shows the guest web page on a second, different phone (Android frame on the iOS listing and the reverse) to make "any phone" visible. Screen 6 shows an Arabic RTL screen next to a Japanese one on the English listings.

## 4. App Store in-app events

Up to five published at once per app; each has a 30-character name, 50-character short description, 120-character long description, and its own localisations. All are "Special Event" or "New Feature" types unless noted.

| Event | Window | Regions | Angle | Deep link |
|---|---|---|---|---|
| Ramadan iftar nights | ~2 weeks before Ramadan to Eid al-Fitr (2027: mid-Feb to mid-Mar) | SA, AE, KW, QA, BH, OM, EG, JO, PK, ID, MY, TR | Big group iftars, one person pays, everyone settles by link (sarie, InstaPay, Raast) | Opens a new bill with the voice sheet |
| Summer trips | 1 Jun – 31 Aug | US, GB, DE, NL, SE, NO, DK, FR, ES, IT | Trip group with running balance, multi-currency Pro trial | Opens "new group" with the trip preset |
| Back to uni, new flat | 15 Aug – 30 Sep (NH), 15 Feb – 15 Mar (AU) | US, GB, CA, AU, DE, NL, PL | Rent and utilities as recurring bills, flatmate balances | Opens "new group" with the household preset |
| Holiday dinners | 1 Dec – 2 Jan | Global | Scan the big dinner receipt, no daily limit | Opens the scanner |
| Lunar New Year | 2 weeks around the date (2027: 6 Feb) | CN, TW, HK, SG, MY, KR, VN | Family dinners, red-envelope style settle up | Opens the scanner |
| Golden Week (JP) and Chuseok (KR) | 29 Apr – 5 May; Chuseok week (2027: 15 Sep) | JP; KR | 合宿 / 旅行 group settle | Opens "new group" |
| Voice assignment (New Feature) | 2.0 launch, 14 days | All | "Say who had what" | Opens a sample bill with the voice sheet |

Keep the event cards in the same visual system as the screenshots. Events are indexed by search, so the event name should carry the market's top term where it fits ("Ramadan: split the iftar bill").

## 5. Custom product pages (App Store)

Three pages at launch, each with its own screenshot order, promotional text and preview; all point Apple Search Ads campaigns and the landing-page use-case pages at the matching CPP.

| CPP | First three screens | Promotional text (≤170) | Traffic |
|---|---|---|---|
| Trips | Settle in fewer payments, Any currency, Friends pay from a link | "One group for the whole trip. Any currency, daily rates, settle in the fewest transfers. Friends pay from a link in their country's apps." | Search Ads: trip, travel, holiday, vacation keywords; landing `/use/trips` |
| Roommates and households | Friends pay from a link, Every cent accounted for, Settle in fewer payments (with a recurring rent bill visible) | "Rent, utilities and groceries in one running balance. Every cent accounted for, gentle reminders, no daily limit." | Search Ads: roommate, flatmate, rent, household; landing `/use/roommates` |
| Dinners | Scan it, Say who had what, Every cent accounted for | "Scan the receipt, say who had what, done. Tax and tip split fairly, friends pay from a link, no app needed." | Search Ads: dinner, restaurant, receipt, tip; landing `/use/dinners` |

Add a fourth CPP for the Gulf (Arabic-first screens, sarie/InstaPay in frame) once the Arabic screenshots exist, and a fifth for India (UPI QR in frame, Hinglish captions) if India traffic is material.

Product page optimization (A/B on the default page), one test at a time, 90% confidence, at least 7 days each:

1. First screenshot caption: "Scan it" vs "Say who had what" (tests whether voice or scanning converts better now that scanning is table stakes).
2. Subtitle: "AI Receipt Scanner & Settle Up" vs "Scan, Say Who Had What, Settle".
3. Icon: the two finalist marks from the design pass.

## 6. Google Play store listing experiments

Play allows one default-listing experiment and localised experiments in parallel. Run them in this order, each for 7 days minimum or until Play reports 90% confidence; stop early only on a clear loss.

1. **Short description (default, en-US)**: current ("Scan receipts, say who had what, settle up. Friends pay from a link, no app.") vs "Split bills with anyone, on any phone, in any country. Free, no daily limit." Measures whether the "everyone, every phone" claim beats the feature list.
2. **First screenshot (default)**: Scan vs Voice, mirroring PPO test 1 so the two stores can be compared.
3. **Icon (default)**: same two finalists as the App Store.
4. **Localised experiments**: de-DE short description ("Kassenbon scannen, sagen wer was hatte, abrechnen" vs "Rechnungen teilen ohne Tageslimit. Freunde zahlen per Link."), nl-NL (Tikkie-link mention vs none), sv-SE (Swish mention vs none). These tell us whether naming local rails in the first 80 characters lifts installs.

Custom store listings (Play lets you target by country and by install state): India (UPI QR screenshot first, Hinglish captions), Brazil (Pix first), Gulf (Arabic listing already covers it; add a KSA-specific listing only if the ar experiment shows a lift), Indonesia (GoPay and DANA first). Also use **promotional content (LiveOps)** for the same windows as the in-app events in section 4, and keep the app eligible for Play Points.

Pre-registration is not needed; 2.0 ships as an update to the existing package.

## 7. Screenshot production plan (no real demo account)

Goal: one command renders every screenshot for every locale and both platforms from seeded demo data, so the set can be regenerated whenever a screen or a caption changes.

### Pieces

1. **Firebase emulator.** `firebase.json` already configures the Firestore emulator on port 8080 (`singleProjectMode: true`). Add the Auth emulator (port 9099) to the same block so sign-in works without a real account; the screenshot run signs in with an emulator-only user created by the seed script. The app needs a `--dart-define=USE_FIREBASE_EMULATOR=true` switch that points Firestore and Auth at `localhost` (10.0.2.2 on the Android emulator). Backend calls (receipt scan, voice assign, FX) are not needed for screenshots because the seeded bills are already scanned and assigned; the screenshot build stubs the backend client with fixtures.
2. **Seed script** (`tool/seed_demo.dart`, run with the emulator up). It writes one dataset in the shape the 2.0 domain layer expects (`lib/domain`: money in minor units, shares, ledgers, payments):
   - Users: "You" (signed in), friends Ali, Mona, Sara, Omar; avatars from bundled placeholder images.
   - Group "Lisbon weekend" (EUR) with four bills and a running balance that produces exactly two settle-up transfers (screen 5).
   - Bill "Sea Breeze Grill" (screen 1–3): a scanned receipt with 6 items, service 10%, tip, two shared items; voice sheet state "Ali had the burger, Mona and I shared the fries" (screen 2); a share breakdown for Mona showing items, tax and tip lines and one edit in history (screen 3).
   - Guest link for Mona with payment methods for the storefront's country (screen 4): the seed sets the group country per locale (US → Venmo and Cash App, GB → Faster Payments and Monzo, DE → PayPal and GiroCode, SA → sarie, IN → UPI, BR → Pix, SE → Swish, JP → PayPay, KR → Toss) using `countryPaymentMethodIds` from `lib/payments/`, and one payment already recorded with proof.
   - Group "Flat 4B" (local currency) with recurring rent and utilities (for the Roommates CPP) and a multi-currency trip "Tokyo + Seoul" (JPY, KRW, USD) for screen 6.
   - Amounts are chosen so every total divides cleanly in each currency's decimals (JPY and KRW have none) and never show a rounding artefact.
3. **Integration-test screenshot driver** (`integration_test/screenshots_test.dart` + `test_driver/screenshots_driver.dart`, same pattern as the existing `startup_smoke` pair). The test receives `LOCALE` and `COUNTRY` through `--dart-define`, sets the app locale, signs in to the emulator user, navigates to each of the seven screens and calls `binding.takeScreenshot('<n>-<slug>')`. It also toggles dark mode for the one dark frame used on the listing and sets the RTL locale for the Arabic and Urdu runs. The driver writes PNGs to `build/screenshots/<platform>/<device>/<locale>/`.
4. **Runner** (`tool/screenshots.sh`): starts the emulator with `firebase emulators:exec --only firestore,auth`, seeds, then loops over the device matrix and the 22 locales (28 iOS folders are produced by copying the English, Spanish, French, Portuguese and Chinese runs to their sibling locales; Play gets its 26). Devices: iPhone 17 Pro Max (6.9-inch, required), iPhone 8 Plus (5.5-inch, still accepted and useful for the shorter 6-screen set), iPad Pro 13-inch only if the app declares iPad support; Pixel 9 Pro (phone), Pixel Tablet (10-inch) and a 7-inch tablet for Play. Use the `ios-simulator` tooling for iOS and `flutter drive -d <emulator>` for Android.
5. **Framing and captions** (`tool/frame_screenshots.py`): reads the raw PNGs, places them in the v3 device frames, draws the caption from `tool/aso/captions.json` (the table in section 3, exported as JSON with the same keys) with the display font, mirrors layout for RTL locales, and writes to `fastlane/screenshots/<ios-locale>/` and `fastlane/metadata_v2/android/<locale>/images/phoneScreenshots/`. The Fastfile already uploads `fastlane/screenshots` through `deliver`; Play uses `supply` with `skip_upload_screenshots: false`.

### Checklist before the first run

- Add the Auth emulator to `firebase.json` and the `USE_FIREBASE_EMULATOR` switch to the Firebase bootstrap in `lib/main.dart`.
- Make the backend client injectable so the screenshot build can swap in fixtures (no network, no OpenAI or Anthropic calls, no cost).
- Hide the status bar clock variance: set the simulator status bar with `xcrun simctl status_bar ... override --time 9:41 --batteryLevel 100 --cellularBars 4 --wifiBars 3`, and the Android demo mode (`adb shell settings put global sysui_demo_allowed 1` then the `demo` broadcasts).
- Keep the same five fake names and merchants across locales; translate only captions and UI, so the frames stay comparable in experiments.
- App Store preview video (optional for launch): record the voice flow on the 6.9-inch simulator with the same seed, 20 seconds, captions burned in per locale from the same JSON.

## 8. Claims checklist (what must ship for the copy to stay honest)

Every description makes these claims. Each must be true on the 2.0 build that goes to review, or the line is cut from the copy before upload.

| Claim in the copy | Depends on |
|---|---|
| Voice assignment ("say who had what") | Anthropic voice/assign route live, on-device speech input (ROADMAP decision 6) |
| Subtotal and total rows kept out of items | Smart receipt cleanup (ROADMAP quick win 4) |
| Split by item, equally, exact, percentage, shares; quick IOUs | ROADMAP A split methods and quick win 5 |
| Every cent accounted for, edit history | Quick win 3 |
| Guest web link, share cards, proof of payment | ROADMAP A personalized guest links, quick win 2 |
| Payment methods per country, amount prefilled where supported, "more than 60 countries" | `lib/payments/` (PAYMENT_METHODS.md lists 65 country rows); keep the Apple Cash and Zelle wording as "copy and open" if the Messages hand-off is not shipped |
| Running balances, settle up in the fewest transfers, record payments | ROADMAP A ledgers |
| Reminders at most once a week | ROADMAP C smart nudges |
| Every world currency with the right decimals | ROADMAP E currencies (full ISO 4217) |
| 22 languages, Arabic and Urdu RTL, dark mode | ROADMAP E and design tokens |
| No daily limit, no interstitial ads, free monthly AI and voice allowance, rewarded ad adds more | ROADMAP decision 4 (free tier) |
| Pro: unlimited AI and voice, multi-currency with daily rates, recurring bills, CSV and PDF export, monthly / yearly with trial / lifetime | ROADMAP A Pro items, decision 3 pricing |

Prices are intentionally not in the copy (they vary per storefront). The iOS descriptions end with the auto-renewal sentence Apple expects and the privacy and terms URLs; the Play descriptions omit Apple-specific text and have no legal block (Play shows the privacy policy from the console field).

## 9. 2.0 listing changes (2026-11-07)

What changed in `fastlane/metadata_v2` and why:

- **Name is final.** Every title is `Evens: <market's top phrase>`; with a 5-character name the English titles moved to the long form `Evens: Split Bills & Receipts` (29) and the subtitle to `AI Scanner, Groups & Settle Up`, as planned in section 1. Spanish, Italian, Portuguese (BR), Russian, Turkish, Swedish, Arabic, Hindi, Thai, Vietnamese, Japanese, Korean and Chinese titles gained a second phrase (*gastos*, *spese*, *расходы*, *masraf*, *kostnader*, *المصاريف*, *खर्च*, *ค่าใช้จ่าย*, *chia tiền*, *立て替え精算*, *엔빵*, *聚餐旅行均摊*). Subtitles were rewritten wherever a word now repeated the title (the validator rejects repeats).
- **Keyword fields** were rebalanced per the map in `ASO_KEYWORDS.md`: words that moved into a title left the field, *splitter* entered the English fields, *gruppenkasse* replaced *reisekasse* (de), CJK fields dropped title substrings (*더치*, *정산앱*, *立て替え*, *送金*, *旅行*, *聚餐*) and added *音声* / *わりかん* / *拼单* style long tail. No field exceeds 100 characters; Latin-script fields also stay within 100 bytes.
- **Promotional text** is now a timely 2.0 line in every language: "New in 2.0: say who had what and Evens splits the receipt for you. Friends pay from a link in the apps their country uses, no app needed. Typing a bill is always free."
- **Descriptions** keep the hook and the scannable blocks but now state the facts of the shipped free plan (welcome points for AI scans and voice, a short rewarded ad adds more, typing a bill is always free, no interstitial ads) instead of the earlier "monthly allowance / no daily limit" wording; they name **158 currencies** and **80+ local payment apps** instead of "every currency / 60+ countries", add the *who pays?* roulette to the settle-up block, and end with a PRIVACY block (Evens never holds money, receipts never train AI) before the Pro auto-renewal line. Prices stay out of the copy.
- **Release notes and Play changelogs** are six short lines (voice, pay from a link in 80+ apps, groups and trips settle in the fewest payments with IOUs and reminders, roulette, 158 currencies / 22 languages / dark mode, Pro).
- **Play short descriptions** open with the market's primary phrase ("Split bills with AI: …", "Rechnung teilen: …", "Divide la cuenta: …") so the indexed 80 characters carry it.
- **Fastfile** now uploads `metadata_v2` (both stores) and all 28 iOS locales; `hr` is gone.

### Product page optimization tests (App Store), one at a time, 7+ days, 90 % confidence

1. Subtitle `AI Scanner, Groups & Settle Up` vs `Scan, Say Who Had What, Settle` (feature list vs the voice story).
2. First screenshot "Scan it" vs "Say who had what".
3. Promotional text: the 2.0 line vs "Free to use: typing a bill is always free. Friends pay from a link in 80+ local apps, no download." (new-feature vs free-plan angle).
4. Icon: the two finalists from the Midnight & Mint pass.

### Play store listing experiments

1. Short description (en-US default): current vs "Split bills with anyone, on any phone, in any country. Friends pay from a link." (feature list vs the "everyone, every phone" claim).
2. First screenshot Scan vs Voice (mirrors PPO test 2).
3. Localised short-description tests that name the local rail in the first 80 characters: de-DE ("… Freunde zahlen per Link" vs "… per PayPal-Link"), nl-NL (Tikkie-link named vs not), sv-SE (Swish named vs not), pt-BR (Pix named vs not), hi-IN (UPI named vs not). These decide whether the brand-in-short-description lift is real before we spend screenshot frames on it.

### Custom product pages and custom store listings per market

| Market | App Store custom product page | Play custom store listing |
|---|---|---|
| US, GB, AU, CA | Trips / Roommates / Dinners CPPs from section 5, promotional text swapped to the 2.0 line of each use case | Default listing; Roommates variant for the back-to-uni window |
| Gulf (SA, AE, KW, QA) and Egypt | "Iftar and gatherings" CPP: Arabic-first screens, sarie / STC Bank / InstaPay in frame, Ramadan in-app event linked to it | KSA and Egypt listings with the same first screenshot; Egypt short description names InstaPay |
| India | "UPI split" CPP: UPI QR in frame, Hinglish captions, `hi` promotional text "दोस्त लिंक से UPI पर चुकाते हैं" | India listing, UPI first; Hinglish short description A/B |
| Brazil | "Pix" CPP: guest page with Pix copia e cola first | Brazil listing, Pix first |
| Indonesia | "Patungan" CPP: GoPay / DANA in frame | Indonesia listing, GoPay first |
| Japan / Korea | Golden Week and Chuseok event CPPs: 合宿 / 모임 group settle, PayPay / Toss in frame | Seasonal LiveOps cards, same art |
| DACH / Benelux / Nordics | Summer-trips CPP with the local rail (GiroCode, Tikkie, Swish, MobilePay, Vipps) on the guest-page frame | Localised experiments above decide whether to add rail-named listings |

## 10. Open items

- Verify keyword popularity per market in Apple Search Ads before upload; swap the two weakest words per field (fields and candidates are in `ASO_KEYWORDS.md`).
- Confirm the secondary-locale indexing map for GB, DE, NL, JP, KR and the Gulf storefronts in an ASO tool.
- Export the caption table to `tool/aso/captions.json` (`tool/store/captions.json` already exists for the screenshot script; keep one).
- Remove `fastlane/metadata` (1.2.x copy, includes `hr` and the unused iOS `ur` folder) once 2.0 is live.
- Danish and Finnish MobilePay → Vipps rename (January 2027) needs a description refresh in da and fi (fi is not in the 22 yet).
- `APP_REVIEW_NOTES` in the Fastfile still describe the 1.2.0 security update; rewrite them for the 2.0 submission.
