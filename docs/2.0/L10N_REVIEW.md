# Localization review — Split Bill 2.0

Branch `l10n/review` (from `release/2.0.0` @ b9a3800). Scope: `assets/translations/*.json`, 22 locales × 2,129 keys. Keys and placeholders are unchanged everywhere; `flutter test test/localization` and the full `flutter test` pass.

## Method

1. `en.json` was fixed first (source of truth): broken keys, product naming, terminology, punctuation.
2. Every other locale was reviewed key by key against English with a batch-dump tool, patched through a validator (placeholders must match `en`, no empty values, key set/order identical), and committed per locale.
3. Automated checks per file: placeholder parity, literal `\n`/`nwatch`-style artefacts, `Premium` leftovers, untranslated values (the remaining identical-to-English values are brands, ISO codes, placeholder-only strings and words that are the same in the target language).

## Global glossary decisions

| Concept | Rule |
|---|---|
| Product tier | **Pro** everywhere (never "Premium"). "Go Pro" / "Upgrade to Pro". |
| Ad/scan currency | **points** (never "credits"). A receipt scan and a voice command each cost **2 points** (`FeatureCosts`). |
| App name | **Split Bill** in Latin script in every locale (no transliteration, no translation). |
| Brands | PayPal, Revolut, InstaPay, Apple Cash, Venmo, Zelle, Wise, M-Pesa, Cash App, Vodafone Cash, WhatsApp, App Store, Google Play stay as is. |
| Host | the person who created / paid the bill. Guest = participant without the app paying via web link. |
| Plurals | no ICU plurals: counts use plural-safe forms (`Items: {count}`, abbreviations, or forms valid for 1 and many). |
| Legal strings | `subscription_auto_renew_disclosure`, `subscription_lifetime_disclosure`, `pw_legal_*`, `prof_delete_body`, `acct_legal_line` verified in every locale: auto-renews unless cancelled ≥ 24 h before the period ends, charged to the store account, cancel in store subscription settings, lifetime = one-time purchase, no renewal. |

## en (source) — 171 values changed

- Premium → Pro in all 30 affected keys (admin filters, paywall, status, grant/revoke).
- credits → points; `just_say_who_ate_what_cost_1_credit` and `voice_command_cost` now say 2 points; `1_point_1_scan` → "2 points = 1 scan".
- Repaired broken values: `you_need_1_point_…_nwatch…` (literal "n"), `select_nyour_name`, `item_s` ("Item s"), `scan_friend_s_qr`, `re_record`, `no_keep_it`, `i_paid_skip_proof`, `need_help_contact_us`, `manage_users_fcm_and_bills`, `user_missing_fcm_token`.
- Run-on sentences punctuated (`add_the_ways_you_prefer…`, `choose_how_friends_can_pay_you…`, `this_action_is_irreversible…`, `this_participant_marked…`, etc.).
- `splitbill` / `split_bill_premium` → "Split Bill" / "Split Bill Pro"; `logout` → "Sign out" (matches the rest of the app).
- Legacy Title Case labels moved to sentence case ("Add Method" → "Add method"); shouting caps removed (`got_it`, `setup_bill`).
- Voice keys that were raw key names ("Voice did you say") rewritten; `voice_reference` → "People and items"; `you_earned_1_point…` no longer claims one point unlocks a scan.

## Per-locale summary

Changed = values that differ from `release/2.0.0`.

| Locale | Changed | Register | bill / share / settle up / owe | points / Pro / host / guest / proof |
|---|---|---|---|---|
| ar | 329 | neutral MSA, 2nd sg. masc.; Western digits; ، ؟ «» | فاتورة / حصة / تسوية الحساب / عليك · مستحق لك | نقاط / Pro / المضيف / ضيف / إثبات الدفع |
| da | 126 | du | regning / andel / gøre op / skylder · til gode | point / Pro / vært / gæst / bevis |
| de | 346 | du | Rechnung / Anteil / abrechnen / schulden · dir geschuldet | Punkte / Pro / Gastgeber / Gast / Nachweis |
| es | 168 | tú (LatAm/Spain-neutral) | cuenta / parte / saldar / debes · te deben | puntos / Pro / anfitrión / invitado / comprobante |
| fr | 293 | vous | addition / part / régler / devoir · on vous doit | points / Pro / hôte / invité / preuve |
| hi | 381 | आप; danda । | बिल / हिस्सा / हिसाब चुकाएँ / आपको देना है · आपको मिलना है | पॉइंट / Pro / होस्ट / गेस्ट / प्रमाण |
| id | 509 | Anda (casual-modern tone) | tagihan / bagian / lunasi / berutang · piutang Anda | poin / Pro / host / tamu / bukti |
| it | 251 | tu | conto / quota / saldare / devi · ti devono | punti / Pro / host / ospite / prova |
| ja | 655 | polite です/ます; full-width punctuation | 会計 / 負担額 / 精算 / 支払う金額 · 受け取る金額 | ポイント / Pro / 幹事 / ゲスト / 支払い証明 |
| ko | 643 | 해요체 (legal strings 합니다체) | 계산서 / 몫 / 정산 / 갚을 돈 · 받을 돈 | 포인트 / Pro / 호스트 / 게스트 / 증빙 |
| nb | 142 | du | regning / andel / gjøre opp / skylder · til gode | poeng / Pro / vert / gjest / bevis |
| nl | 172 | je/jij | rekening / aandeel / afrekenen / schuldig zijn · te ontvangen | punten / Pro / host / gast / bewijs |
| pl | 304 | ty (lowercase) | rachunek / część / rozliczyć się / masz do zapłaty · należy ci się | punkty / Pro / organizator / gość / dowód |
| pt | 216 | você (pt-BR) | conta / parte / acertar / deve · devem a você | pontos / Pro / anfitrião / convidado / comprovante |
| ru | 316 | вы (lowercase); « » ё | счёт / доля / рассчитаться / вы должны · вам должны | баллы / Pro / организатор / гость / подтверждение |
| sv | 135 | du | nota / andel / göra upp / vara skyldig · att få | poäng / Pro / värd / gäst / bevis |
| th | 142 | คุณ; no sentence-final full stops | บิล / ส่วนแบ่ง / เคลียร์ยอด / ค้าง · ยอดที่คุณจะได้รับ | แต้ม / Pro / เจ้าของบิล / แขก / หลักฐาน |
| tr | 432 | siz; sentence case | hesap / pay / ödeşmek / borçlu · alacağınız | puan / Pro / hesap sahibi / misafir / kanıt |
| ur | 288 | آپ; ۔ ، ؟ | بل / حصہ / حساب چکائیں / آپ کو دینے ہیں · آپ کو ملنے ہیں | پوائنٹس / Pro / میزبان / مہمان / ثبوت |
| vi | 90 | bạn | hóa đơn / phần / thanh toán / nợ · được nợ | điểm / Pro / chủ hóa đơn / khách / bằng chứng |
| zh | 671 | 你; full-width punctuation | 账单 / 份额 / 结清 / 欠 · 别人欠你 | 积分 / Pro / 发起人 / 访客 / 凭证 |

Other per-locale glossary: group/trip/IOU/nudge — ar مجموعة/رحلة/دَين/تذكير · da gruppe/rejse/gæld/påmindelse · de Gruppe/Reise/Schuldnotiz/Erinnerung · es grupo/viaje/deuda/aviso · fr groupe/voyage/dette/relance · hi ग्रुप/ट्रिप/उधार/रिमाइंडर · id grup/perjalanan/catatan utang/pengingat · it gruppo/viaggio/debito/promemoria · ja グループ/旅行/貸し借り/リマインド · ko 그룹/여행/빌린 돈/리마인더 · nb gruppe/tur/gjeldsnotat/påminnelse · nl groep/reis/schuld/herinnering · pl grupa/wyjazd/dług/przypomnienie · pt grupo/viagem/dívida/lembrete · ru группа/поездка/долг/напоминание · sv grupp/resa/skuld/påminnelse · th กลุ่ม/ทริป/รายการยืม/เตือน · tr grup/gezi/borç notu/hatırlatma · ur گروپ/سفر/ادھار/ریمائنڈر · vi nhóm/chuyến đi/khoản nợ/lời nhắc · zh 群组/旅行/欠条/提醒.

## Notable fixes per locale

- **ar**: `scan_points` "مسح النقاط" meant *wipe the points* → "نقاط المسح"; `1_point_1_scan` "مسح 1.1" → "نقطتان = مسح واحد"; app title was translated → "Split Bill"; بريميوم/المميز → Pro; رصيد → نقاط; sentences that started with a Latin name reordered verb-first so RTL layout doesn't break (`payment_received_body`, `settle_pays`, `friend_owes_you`, `rem_preview_title`); transliterated brands (باي بال, فودافون كاش, آبل) → Latin; plural-safe "X: {count}" forms; LRM before "+20…" phone hints.
- **da**: `owed_to_you` "Skylder dig" had the wrong direction → "Til gode"; `bf_voice_server_note` "omskrivning" (rewriting) → "transskription"; proof vs receipt (`activity_proof_attached`); `pw_legal_cancel` made precise; reklame → annonce; caps labels → sentence case.
- **de**: 16 "Sie" leftovers → du; Guthaben → Punkte; Posten/zuordnen → Artikel/zuweisen (~45 keys); "Beleg" for proof → "Nachweis" so it no longer collides with receipt; Schulden → Schuldnotiz (IOU); gender-neutral `bf_split_caption_items`; `rem_when_sub` "Ihre Ortszeit" → "Ortszeit der Empfänger"; "Split-Bill-…" compounds → "… von Split Bill".
- **es**: `app_title` "Divide la cuenta" → "Split Bill"; broken "nver un anuncio" repaired; `acct_onb_scan_title` "leídos por ti" (read *by you*) → "leídos automáticamente"; `no_keep_it` "No, gracias" → "No, mantener"; `voice_try_example` "entre yo y Juan" → "entre Juan y yo"; `pw_perk_export` "Facturas" → "Cuentas recurrentes"; gender-neutral greetings and "Marcado como pagado: {name}".
- **fr**: ~50 tu strings → vous; `mercy_shown…` "Merci accordée" (thanks) → "Grâce accordée"; `scan_points` "Scanner des points" → "Points de scan"; squad/note/facture unified to groupe/addition; `payment_handle_invalid` gender clash → "{kind} non valide."; `subscription_period_*` "période de 6 mois" → "6 mois"; « » quotes, spaces before ? ! :.
- **hi**: `scan_points` "पॉइंट्स स्कैन करें" (scan the points) → "स्कैन पॉइंट्स"; `rem_nudge` had the reversed meaning; `owed/owes you` disambiguated ("आपके देनदार हैं"); untranslated "awkward math" → "हिसाब की झंझट"; तुम्हें/masculine → आप neutral; double "ने" in history strings avoided; samूह → ग्रुप, अतिथि → गेस्ट, मेज़बान → होस्ट.
- **id**: `apple` was "Apel" (the fruit) → "Apple"; `tip` "Tips" (advice) → "Tip"; `big_loser` "Pecundang besar" (insulting) → "Paling apes"; kamu/-mu → Anda (file majority); pindai → scan, tangkapan layar → screenshot, tuan rumah → host; stiff MT delete warning rewritten.
- **it**: `say_your_command` "Dì" (= day) → "Di'" (imperative); "Salva e esci" → "Salva ed esci"; `receipt_ready` "Ricevuta" → "Scontrino"; "conti imbarazzanti" → "Basta calcoli complicati!"; `bf_edit_assign_mode_share` "Condividi" (share a link) → "In comune"; articolo → voce, portafoglio → wallet; gender-neutral "sei in debito".
- **ja**: three competing words for bill (請求書/明細/支払い) → 会計; ホスト/主催者 → 幹事; 項目/アイテム/商品 → 品目; クレジット → ポイント; casual 〜しよう/〜だね → polite; `pardon_them` 許可する (allow) → 免除する; `owed_to_you` ambiguous あなたへの支払い → 受け取る金額; full-width punctuation, no spaces around placeholders.
- **ko**: `let_s_go` 가자 (반말) → 시작하기; 청구서/영수증 used for bill → 계산서; 크레딧 → 포인트; particles after placeholders removed ({name}님, "{item} 항목", "변경: {from} → {to}"); 비율 (clashed with %) → 지분 for the Shares split mode; 당신 (rude) → 나; 최대 패배자 → 당첨자; legal disclosures kept in 합니다체.
- **nb**: "samboere" (cohabiting partners) used for roommates → "kollektivet"; garpegenitiv "{name} sin andel" → "Andelen til {name}"; "Én til til {name}" → "Én mer til {name}"; MVA/Mva/mva. unified; kreditter → poeng; no Swedish/Danish forms found.
- **nl**: 26 history strings used the perfect tense after "Jij" (ungrammatical) → simple past; "Delen" for Shares clashed with Share → "Aandelen"; verrekend/vereffenen → afgerekend; bonnetje → bon; `rec_then_monthly` ordinal "{day}e" → "op dag {day}"; tegoed → punten; gender-neutral rewrites.
- **pl**: ~100 capitalised Ci/Twój → lowercase; user-facing past-tense forms made gender-neutral (Zapłacone, Zdobyto, Masz do zapłaty); "uchwyty płatności" (MT for handle) → "identyfikatory"; `scan_points` "Skanuj punkty" → "Punkty na skany"; "konto-to-konto" → "z konta na konto"; `item_s` "Pozycja y" → "Pozycje"; slang "którzy mi wiszą" removed; plural-safe "Członkowie: {count}", "{count} dn. temu".
- **pt**: `start_with_the_receipt…` "Comece pela conta" (bill) → "pelo recibo"; `guest_see_receipt` likewise; digitalizar/leitura → escanear (16 keys); iOS "Ajustes" → "Configurações"; Partes → Cotas for the Shares mode; gender-safe "Formato inválido para {kind}."; plural-safe "Adicionados: {count}".
- **ru**: `1_point_1_scan` "1 точка 1 скан" (точка = dot) → "2 балла = 1 скан"; proof was "чек" (collided with receipt) → "подтверждение"; Хост/хозяин → организатор; товар/пункт/предмет → позиция; 34 ты strings + ты-imperatives → вы; `scan_points` "Сканировать баллы" → "Баллы за сканирование"; MT "крайне разрушительно" rewritten; gender-neutral «оплатил(а)».
- **sv**: `bf_edit_delete_body` said receipts ("kvitton") would be deleted instead of proofs → "bevis"; `owed_to_you` "Skyldiga dig" → "Att få"; vara/post → artikel; betalsätt → betalningsmetod; `pw_legal_renews` made legally precise (24 timmar, butikskonto); "Kalkylark" → "Sheets" (brand); ”…” quotes.
- **th**: เจ้าภาพ (party host, implies paying for everyone) → เจ้าของบิล; `voice_reference` literal "อ้างอิงเสียง" → "คนและรายการ"; คะแนน/เครดิต → แต้ม; ผู้เยี่ยมชม/แขก → แขก; `appearance` "ลักษณะที่ปรากฏ" → "ธีม"; "FCM token" → "พุชโทเค็น"; `insights_week_short` "ส{n}" → "สัปดาห์ {n}".
- **tr**: ~55 sen strings → siz (file majority); `pw_ad_promise` "bir hesabı bölmez" read as *splits a bill* → "kesintiye uğratmaz"; `owed_to_you` "Size Borçlu" → "Alacağınız"; suffixes glued to placeholders removed ("{price}'den" → "ayda {price} ile başlar", "%{percent}'i" → "%{percent} kadarı"); `bf_edit_discard` "Sil" (delete) → "Vazgeç"; fatura → hesap; dekont → kanıt; kredi → puan; ~70 Title Case labels → sentence case.
- **ur**: `owed_to_you` "واجب الادا" meant *payable by you* → "آپ کو ملنے ہیں"; app title was translated → "Split Bill"; untranslated "awkward حساب" → "حساب کی جھنجھٹ"; transliterated brands → Latin; `voice_reference` mistranslation → "لوگ اور آئٹمز"; English button names inside `manual_entry_quick_tips` → Urdu; two-line title line-break order fixed; اشیا/شے → آئٹم, اطلاعات → نوٹیفکیشن.
- **vi**: "lượt" (turns) used for the points currency → "điểm"; chủ bàn → chủ hóa đơn; `voice_reference` literal "Tham chiếu giọng nói" → "Người và món"; `bf_split_seg_exact` "Chính xác" → "Số tiền"; "Thanh toán xã hội nhanh" (MT) → "Chuyển tiền nhanh giữa bạn bè tại Mỹ"; all-caps labels → sentence case.
- **zh**: host was 房主/主持人 (landlord / MC) → 发起人 (~15 keys); `1_point_1_scan` "1点1扫" → "2积分 = 1次扫描"; 您 → 你; 高级版 → Pro; 额度/点 → 积分; 结算 → 结清; 收据/小票 → 小票; `notification_via_method` glued suffix → "（{method}）"; `pw_cta_*` restructured ("订阅：每年{price}"); ~60 half-width punctuation marks → full-width.

## Strings that still deserve a human native speaker

Cross-locale (same root cause, every language):
- `insights_payback_slowest` ("{name} takes {count}.") — English does not say whether `{count}` carries a unit; several locales chose "{name}: {count}" or assume a bare number. Confirm what the app passes and align.
- `widget_updated_at` ("Updated {time}") — correct phrasing depends on whether `{time}` is a clock time or a relative string (de/it/nl/pt flagged it).
- `bf_edit_amount_invalid` ("Enter a number, like 12.50") — pt, ru and vi use the locale decimal comma ("12,50"); revert to "12.50" if the amount field only accepts a point.
- Concatenated fragments (`watch_a_short_video_to_get` + `plus_1_point`, `for_your_next_receipt_scan`, `made_with`, `for_smart_spenders`, `you_owe_to`, `home_settle_with`, `bf_bill_collected` + `bf_bill_of_owed`, `bf_bill_history_*` with a name prefix) — word order is language-dependent (verb-final ur/tr/ja/ko, pl/ru case inflection, hi "आप ने"). Verify on screen; consider merging them into single keys with placeholders.
- `payment_handle_invalid` / `pm3_invalid_handle` — `{kind}` is a noun with gender/case; all locales now use a neutral "Invalid format for {kind}" shape.
- Localised example data (`groups_name_hint_trip`, `prof_phone_hint`, `acct_onb_receipt_caption`, voice examples) — several locales use local trips/phone formats/names (ar مطعم النسيم, ru Сочи, pl Zakopane, zh 三亚, pt/ru/pl/es local phone prefixes); confirm this is wanted or revert to the English samples.

Per locale:
- **ar**: dual / 3–10 / 11+ number agreement can't be perfect without ICU plurals (`groups_budget_left_days`, `insights_payback_days`, `bf_scan_review_items_other`); `*_portion` نصيب vs `*_share` حصة if both appear side by side; Vodafone Cash / InstaPay kept Latin although Egyptians also read فودافون كاش / إنستاباي (product decision).
- **da**: IOU → "gæld" is slightly heavy (alternative "skyldseddel"); annonce vs reklame brand voice; tildel vs fordel for assign across old/new screens.
- **de**: IOU → "Schuldnotiz" (product decision); `bf_scan_review_by_what_each_had` "nach Artikeln"; "Handle" vs "Benutzername" mixed in onboarding.
- **es**: `voice_did_you_say` "¿Dijiste" prefix has no closing "?" because the UI appends text; "Costo de envío" / "al centavo" are neutral choices Spain may word differently; Spain example phone (+34).
- **fr**: `settle_recap_share_text` colloquial "On est quittes"; "en deux clics" for "2 taps"; `bf_voice_settings_hint` Android "Paramètres" vs iOS "Réglages".
- **hi**: chandrabindu vs anusvara spellings (हटाएँ/हटाएं) are mixed (both accepted); terse chart labels `insights_week_short` "ह{n}", `bf_assign_note_each`; segmented-control widths for `bf_edit_assign_mode_*`.
- **id**: "host" loanword vs "pembuat tagihan"; scan vs pindai is a global style choice; "Perjalanan" chip is longer than "Trip".
- **it**: `bf_split_seg_equal` "Uguale" is terse; masculine defaults (Bentornato, Benvenuto in Pro, Sei pronto) — Italian has no neutral form.
- **ja**: Shares split mode → 比率 next to 割合 (percent); `group_type_home` 住まい vs ルームシェア; katakana example names (アリ・サラ) vs Japanese names.
- **ko**: IOU "빌린 돈" is direction-ambiguous (alternatives 주고받을 돈 or keep "IOU"); 리마인더 loanword vs 재촉/알림; 호스트 vs 결제한 사람; `bf_bill_history_*` start with "님이 …" assuming the actor name is prefixed.
- **nb**: singular "them" in `activity_you_owe_them` / IOU toggles; "gjeldsnotat" formal vs "skyldlapp"; fordel vs tildel for assign (~60 strings); "skuls" colloquial.
- **nl**: "host" kept (gastheer is gendered; "organisator" is an alternative); `payment_handle_invalid` slightly formal.
- **pl**: 26 history keys keep "utworzył(a) / usunął(-ęła)" split forms (Polish past tense can't be neutral); names in placeholders that need genitive/dative are written nominative with separators (`guest_pay_host`, `settle_pays`, `friend_you_owe`, `iou_cta_i_owe`, `activity_owes`).
- **pt**: colloquial "te" + "você" mix in short balance rows (standard pt-BR, not normative); Brazilian example phone.
- **ru**: `pw_out_body` "{points} балла" is only correct for 2; gender-neutral bracket forms «оплатил(а)» / «должен(на)» are a compromise.
- **sv**: IOU toggle labels without pronoun ("Jag är skyldig" / "Är skyldig mig"); "hen" for singular they; "Klara/klar" chips vs "Kvitt/uppgjord" for settled; Radera vs Ta bort both used.
- **th**: sign-in mixes "เข้าสู่ระบบ" (older keys) and "ลงชื่อเข้าใช้" (acct_ flow) — pick one; IOU "รายการยืม" judgement call; `rec_then_weekly` assumes Thai weekday values; "สัปดาห์ {n}" axis width.
- **tr**: host "hesap sahibi" vs account "hesap"; mixed ' and ’ apostrophes; reordered fragments need an on-screen check.
- **ur**: `activity_owes` / `friend_owes_you` use a مقروض construction relying on the prepended name; `insights_week_short` "ہ{n}"; Pakistani example phone (+92).
- **vi**: `receipt_thank_you` "CẢM ƠN QUÝ KHÁCH" (mock receipt only?); `bf_bill_collected` + `bf_bill_of_owed` read together.
- **zh**: `insights_payback_slowest` needs 天 if `{count}` is a bare number; "每{period} {price}" composition in the paywall.

## Verification

- `flutter test test/localization`: 67 tests passed (key sets, placeholders, no empty values, Info.plist locales, aliases).
- `flutter test` (full suite): 915 tests passed.
- No native builds were run; only `assets/translations/*.json` and this document changed.
