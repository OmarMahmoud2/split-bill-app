# Keyword map for Evens 2.0 (App Store and Google Play)

Written 2026-11-07. Source of truth for the copy is `tool/aso/copy_*.py`; `python3 tool/aso/gen.py` writes `fastlane/metadata_v2/`, `python3 tool/aso/validate.py` checks the limits. The Fastfile reads `metadata_v2` for both stores since 2.0.

How the fields work:

- **App Store.** Name (30), subtitle (30) and the hidden keyword field (100 characters, counted in Unicode code points, which is how App Store Connect counts) are the only indexed text. Apple combines words across the three fields, so `Split` (name) + `expense` (keywords) ranks for *split expense*; a word is never repeated across them. Singular forms only (Apple matches plurals), no app name, no competitor or payment-brand trademarks (Apple rejects those).
- **Google Play.** No keyword field. Title (30), short description (80) and the full description (first 167 characters shown, headings repeated) are indexed. Keyword density for the market's main phrase sits around 2–3 % of the full description; the phrase is in the title, in the first sentence, in one heading and in the free-plan paragraph.
- Volumes are **unverified**: they come from the terms people use for the category in each language (search suggestions, competitor titles, category checks) and not from a paid tool. Before locking a market, read Apple Search Ads popularity for the field's words and swap the two weakest.

## Cross-localization (which keyword fields a storefront indexes)

Apple indexes the storefront's primary locale plus one or more secondary locales, so each storefront effectively has 200+ keyword characters. The widely published map (AppTweak, AppFollow, MobileAction; confirm in one tool before relying on a pair):

| Storefront | Primary | Also indexed | Rule we apply |
|---|---|---|---|
| United States | en-US | es-MX (plus, per several tools, ar, zh-Hans, zh-Hant, fr-FR, de-DE, ja, ko, pt-BR, ru, vi) | es-MX is the second US field: LATAM idioms (*vaquita*, *roomies*, *cuentas claras*) with no English words. The other secondaries are different scripts, so no overlap is possible. |
| United Kingdom | en-GB | en-AU | en-GB carries the generic English words; en-AU carries *housemate, mates* so the pair does not duplicate. |
| Australia / Canada | en-AU / en-CA | en-GB / fr-CA + en-GB | Same: no word is in both en-AU and en-GB, or in both en-CA and en-GB. |
| Germany, Austria, Switzerland | de-DE | en-GB (CH also fr-FR, it) | German compounds in de-DE; English long tail (*splitter, expense, iou*) comes free from en-GB. |
| France, Belgium, Netherlands, Nordics, Italy, Spain, Portugal, Poland, Turkey | local | en-GB | Same pattern: the local field never spends characters on English words. |
| Mexico and Spanish LATAM | es-MX | en-GB | |
| Brazil | pt-BR | en-GB | |
| Japan | ja | en-US | ja field has no English words except *AI* (katakana queries dominate). |
| Korea | ko | en-GB | |
| Saudi Arabia, UAE, Kuwait, Qatar, Egypt | ar | en-GB | Arabic field is bare nouns; the title carries the definite forms (الفاتورة, المصاريف), which Apple treats as separate tokens. English queries ("split bill", "instapay") are covered by en-GB. |
| India | en-GB (primary) | hi | Hindi field mixes Latin Hinglish (*udhaar, hisab, kharcha*) and English (*split, bill, expense*) because Indian users type both. |
| Indonesia, Thailand, Vietnam | id / th / vi | en-GB | id title itself is "Split Bill & Patungan" because Indonesians search in English. |
| China mainland / Taiwan, Hong Kong | zh-Hans / zh-Hant | en-GB | |
| Russia | ru | en-GB, uk | |

Consequence: **en-GB is the second field for almost every non-English storefront**, so it holds the generic English category words (*expense, splitter, iou, debt, calculator*). en-US is tuned for the US only.

## Per-locale map

Fields: **N** = App Store name suffix after "Evens: ", **S** = subtitle, **K** = keyword field, **PT/PS** = Play title / short description. Primary term = the phrase we expect most installs from; secondary = the next two.

### English

| Locale | Primary | Secondary | N | S | K |
|---|---|---|---|---|---|
| en-US | split bills, bill splitter, receipt splitter | split expenses, settle up, group bills | Split Bills & Receipts | AI Scanner, Groups & Settle Up | expense,trip,roommate,friends,dinner,tip,owe,iou,travel,voice,splitter,pay,calculator,debt,check |
| en-GB | split bills, bill splitting app | flatmate, holiday, kitty | same | same | expense,holiday,flatmate,friends,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,kitty,splitter |
| en-AU | split bills | housemate, mates, shout | same | same | expense,holiday,housemate,mates,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,kitty,splitter |
| en-CA | split bills | roommate, etransfer | same | same | expense,trip,roommate,friends,dinner,tip,owe,iou,travel,voice,pay,calculator,debt,etransfer,splitter |

PT `Evens: Split Bills & Receipts`; PS `Split bills with AI: scan the receipt, say who had what, friends pay by link.` Why *splitter*: "bill splitter" is a medium-difficulty US term (Sonar, July 2026) that no field covered before; *dutch* and *share* were dropped for it. *check* covers "split the check" (US); *kitty* (GB/AU) and *etransfer* (CA, typed as one word) are local.

### European languages

| Locale | Primary | Secondary | N | S | K |
|---|---|---|---|---|---|
| de-DE | Rechnung teilen, Rechnungen teilen | Kosten teilen, Ausgaben teilen, Gruppenkasse, Kassenbon scannen | Rechnungen teilen | Kassenbon scannen & abrechnen | kosten,ausgaben,gruppe,reise,wg,urlaub,freunde,essen,trinkgeld,schulden,splitten,gruppenkasse,ki |
| nl-NL | rekening splitsen | kosten delen, bonnetje scannen, potje | Rekening splitsen | Bonnetje scannen & verrekenen | kosten,delen,uitgaven,groep,vakantie,vrienden,etentje,huisgenoten,schuld,reis,fooi,verdelen,potje,ai |
| sv | dela notan, dela kostnader | dela på notan, splitta, kvitto | Dela notan & kostnader | Skanna kvitton & gör upp | utgifter,grupp,resa,vänner,middag,skuld,dricks,splitta,kompisar,semester,ai,betala,räkning,hyra |
| da | del regningen | dele udgifter, kvittering, bofæller | Del regningen | Scan kvitteringer & afregn | udgifter,gruppe,rejse,venner,middag,gæld,drikkepenge,splitte,ferie,bofæller,ai,betal,fælles,tur |
| no | del regningen, dele regningen | dele utgifter, kvittering, kollektiv | Del regningen | Skann kvitteringer & gjør opp | utgifter,gruppe,reise,venner,middag,gjeld,tips,splitte,ferie,kollektiv,ai,betal,regnskap,felles,tur |
| fr-FR | partager l'addition | partager les frais, dépenses de groupe, coloc, scanner ticket | Partager l'addition | Scanner de tickets & dépenses | partage,frais,groupe,voyage,coloc,amis,pourboire,dettes,note,compte,vacances,ia,diviser,resto,doit |
| fr-CA | séparer la facture | partager les dépenses, virement, coloc | Séparer la facture | Scanner de reçus & dépenses | partage,frais,groupe,voyage,coloc,amis,pourboire,dettes,note,compte,ia,diviser,virement,resto,doit |
| es-ES | dividir cuenta, dividir gastos | gastos compartidos, a medias, bote, piso | Dividir cuenta y gastos | Escanea tickets, salda deudas | compartidos,grupo,viaje,amigos,piso,cena,propina,pagar,ia,bote,reparto,vacaciones,quién debe |
| es-MX | dividir cuenta, dividir gastos | gastos compartidos, vaquita, roomies, cuentas claras | Dividir cuenta y gastos | Escanea recibos, salda deudas | compartidos,grupo,viaje,amigos,roomies,cena,propina,vaquita,pagar,ia,cuentas claras,quién debe |
| it | dividere il conto, dividere le spese | spese condivise, alla romana, coinquilini | Dividi conto e spese | Scansiona scontrini, salda | condivise,gruppo,viaggio,amici,coinquilini,cena,mancia,debiti,pagare,ia,vacanza,alla romana,chi deve |
| pt-BR | dividir conta, dividir gastos | rachar a conta, despesas, vaquinha, república | Dividir conta e gastos | Escaneie a nota, acerte rápido | despesas,grupo,viagem,amigos,república,jantar,gorjeta,dívidas,pagar,ia,rachar,vaquinha,quem deve |
| pt-PT | dividir a conta | despesas partilhadas, talão, colegas de casa | Dividir a conta | Lê talões e acerta contas | despesas,gastos,grupo,viagem,amigos,colegas,jantar,gorjeta,dívidas,pagar,ia,rachar,férias,partilha |
| pl | dzielenie rachunku | wspólne wydatki, rozliczenie, kto ile | Dzielenie rachunku | Skanuj paragony i rozliczaj | wydatki,wspólne,grupa,wyjazd,znajomi,kolacja,napiwek,długi,zapłać,ai,podział,kto ile,rozliczenie |
| ru | делим счёт, разделить счёт | общие расходы, скинуться, поровну, кто сколько | Делим счёт и расходы | Скан чеков, расчёт долгов | общие,группа,поездка,друзья,ужин,чаевые,скинуться,поровну,ии,кто сколько,соседи,сплит,траты |
| tr | hesap bölüşme | ortak masraf, fiş tarayıcı, gider, ev arkadaşı | Hesap Bölüşme ve Masraf | Fiş Tarayıcı, Hesaplaşma | ortak,grup,seyahat,arkadaş,ev arkadaşı,yemek,bahşiş,borç,yapay zeka,paylaş,tatil,gider,kim ne kadar |

Play titles equal `Evens: ` + N. Short descriptions start with the primary phrase in its verb form ("Rechnung teilen:", "Divide la cuenta:", "Dziel rachunek:") so the first 80 characters carry it.

### Middle East and Asia

| Locale | Primary | Secondary | N | S | K |
|---|---|---|---|---|---|
| ar-SA | تقسيم الفاتورة, قسّم الفاتورة | تقسيم المصاريف, نص نص, حاسبة القسمة, كم عليك | قسّم الفاتورة والمصاريف | امسح الإيصال وسوّي الحساب | مصاريف,مشتركة,مجموعة,رحلة,أصدقاء,عشاء,نص نص,ديون,تقسيم,حاسبة,ذكاء اصطناعي,سكن,سفر,ادفع,كم عليك,قسمة |
| hi | split bill, बिल बांटें | kharcha, hisab, udhaar, expense | बिल और खर्च बांटें | रसीद स्कैन करें, हिसाब चुकता | split,bill,expense,group,trip,roommate,udhaar,hisab,kharcha,dinner,tip,settle,पैसे,हिस्सा,बराबर |
| ur (Play only) | بل بانٹیں | خرچ, حساب | PT `Evens: بل اور خرچ بانٹیں` | – | – |
| id | split bill, patungan | bagi tagihan, pengeluaran bersama, kos | Split Bill & Patungan | Pindai Struk, Lunasi Utang | pengeluaran,bersama,grup,liburan,teman,kos,makan,tip,bayar,ai,hitung,nota,bagi tagihan,hutang,trip |
| ja | 割り勘, 割り勘 アプリ | 立て替え, 精算, 飲み会, 幹事, ワリカン/わりかん | 割り勘・立て替え精算 | レシート読み取り・グループ送金 | 旅行,飲み会,友達,ルームシェア,計算,幹事,支払い,共有,経費,ワリカン,合宿,家計,請求,わりかん,旅費,会計,おごり,音声,スキャン,AI |
| ko | 더치페이, 정산 | 엔빵/n빵/1/n, 회비, 모임통장, 총무 | 더치페이·정산·엔빵 | 영수증 스캔, 누가 얼마 냈는지 | n빵,1/n,계산,모임,여행,회비,친구,룸메이트,회식,송금,공동,경비,가계부,ai,총무,나누기,공금,모임통장,음성 |
| th | หารบิล, หารค่าใช้จ่าย | หารกัน, ใครกิน, ค่ากิน, ทริป | หารบิล หารค่าใช้จ่าย | สแกนใบเสร็จ บอกใครกินอะไร | แชร์,ทริป,เพื่อน,กลุ่ม,กินข้าว,เที่ยว,หารกัน,รูมเมท,หนี้,ทิป,โอน,คำนวณ,แบ่ง,ai,ค่ากิน,เสียง |
| vi | chia hóa đơn, chia tiền | chia tiền ăn, hùn, góp, quỹ nhóm | Chia hóa đơn, chia tiền | Quét bill, ai trả bao nhiêu | nhóm,du lịch,bạn bè,ăn uống,share,phòng trọ,nợ,chuyển khoản,tính,góp,quỹ,đều,hùn,giọng nói |
| zh-Hans | AA制, 分账, 均摊 | 分摊, 记账, 聚餐, 旅行, 合租 | AA制分账·聚餐旅行均摊 | 扫小票，说一句谁吃了什么 | 分摊,记账,朋友,群,合租,算账,费用,报销,账单,语音,结算,ai,出游,室友,吃饭,转账,拼单,同事,差旅,公费 |
| zh-Hant | 分帳, 拆帳, 均分 | 分攤, 記帳, 聚餐, 代墊 | 分帳拆帳·聚餐旅行均分 | 掃描收據，說一句誰吃了什麼 | 分攤,記帳,朋友,群組,合租,算帳,費用,帳單,語音,結算,ai,出遊,室友,代墊,同事,公費,出差,聚會 |

CJK and Thai fields have room (53–91 characters): after a popularity check add the next katakana/hiragana variants (ja), *정산앱* / *더치* cannot be added because the title already contains them as substrings, and zh fields can take *拼饭*, *团购* if the data supports it.

## Field limits as applied

- App Store: name ≤ 30, subtitle ≤ 30, keywords ≤ 100 code points (Latin-script fields are also ≤ 100 UTF-8 bytes; Arabic, Cyrillic, Devanagari, Thai and CJK fields exceed 100 bytes by nature, which App Store Connect accepts), promotional text ≤ 170, description ≤ 4000.
- Google Play: title ≤ 30, short description ≤ 80, full description ≤ 4000, changelog ≤ 500. Nothing in the Play text names Apple ID / Apple Cash.
- `python3 tool/aso/validate.py` enforces all of the above plus the no-repeat and no-trademark rules; current result 28 iOS locales, 26 Play locales, 0 errors.
