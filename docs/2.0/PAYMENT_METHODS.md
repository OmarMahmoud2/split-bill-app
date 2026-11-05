# Payment methods for settling up (2.0)

Research and verification date: **2026-11-05**. The code is in `lib/payments/`, and the tests are in `test/payments/`.

## Capability legend

- **Prefill**: the link opens the provider with the recipient *and* the amount filled in. Some links also carry a note.
- **Recipient**: the link opens the recipient's page. The app copies the amount to the clipboard first, so the payer only has to paste it.
- **QR**: the app builds a QR code, or a copy-paste code, that carries the recipient and the amount. The payer scans it or pastes it in their banking app.
- **Copy**: there is no public link. The app copies the handle and shows "send {amount} in {app}".

Any https link the user stored that the app can't rebuild (InstaPay `ipn.eg`, Tikkie, monobank jar, Stripe…) is simply opened. This is **Recipient** behaviour, with the amount copied to the clipboard.

## Countries → methods

The app shows local methods first. After them come the worldwide methods, always in this order: **PayPal, Revolut, Wise, Bank transfer, Other**. The mapping lives in `countryPaymentMethodIds`. Euro countries that aren't listed below get SEPA EPC QR + Wero. Any other unlisted country gets only the worldwide methods.

| Country | Local methods (most used first) | Capability |
|---|---|---|
| US | Venmo · Zelle · Cash App · Apple Cash | Prefill · Copy · Prefill · Messages (see limits) |
| GB | Bank transfer (Faster Payments) · Monzo | Copy · Prefill (GBP) |
| CA | Interac e-Transfer | Copy |
| AU | PayID (Osko) | Copy |
| NZ | Bank transfer | Copy |
| IE | Revolut · SEPA EPC QR | Recipient · QR |
| DE | PayPal · SEPA EPC QR (GiroCode) · Wero | Prefill · QR · Copy |
| AT | SEPA EPC QR · PayPal | QR · Prefill |
| CH | TWINT | Copy |
| FR | Wero · Lydia · SEPA EPC QR | Copy · Copy · QR |
| BE / LU | Wero · Payconiq (ending 2026) · SEPA EPC QR | Copy · Copy · QR |
| NL | Tikkie (stored link) · Wero · SEPA EPC QR | Recipient · Copy · QR |
| ES | Bizum · SEPA EPC QR | Copy · QR |
| PT | MB WAY · SEPA EPC QR | Copy · QR |
| IT | Satispay · PayPal · SEPA EPC QR | Copy · Prefill · QR |
| FI | MobilePay · SEPA EPC QR | Copy · QR |
| SE | Swish | Prefill (unverified on device, see below) |
| NO | Vipps | Copy |
| DK | MobilePay | Copy |
| IS | Aur | Copy |
| PL | BLIK (phone transfer) | Copy |
| CZ / SK | QR Platba (SPAYD) | QR |
| TR | FAST / IBAN · Papara | Copy · Copy |
| RU | SBP (Faster Payments System) | Copy |
| UA | monobank (jar link or card) | Recipient / Copy |
| EG | InstaPay · Vodafone Cash | Recipient (stored ipn.eg link) or Copy · Copy |
| SA | Instant transfer (sarie) · STC Bank · urpay | Copy |
| AE | Aani · Careem Pay | Copy |
| KW | WAMD | Copy |
| QA | Fawran | Copy |
| BH | BenefitPay (Fawri+) | Copy |
| OM | Bank transfer (mobile / alias transfers in bank apps) | Copy |
| JO | CliQ | Copy |
| LB | Whish Money | Copy |
| MA | Bank transfer (instant) | Copy |
| TN | D17 | Copy |
| DZ | BaridiMob (RIP) | Copy |
| IQ | ZainCash · FIB | Copy |
| PK | Raast · JazzCash · Easypaisa | Copy |
| IN | UPI | Prefill (INR) + QR |
| BD | bKash · Nagad | Copy |
| ID | Bank transfer (BI-FAST) · GoPay · DANA · OVO | Copy |
| MY | DuitNow · Touch 'n Go eWallet | Copy |
| SG | PayNow | QR |
| PH | GCash · Maya | Copy |
| TH | PromptPay | QR |
| VN | VietQR · MoMo | QR · Copy |
| JP | PayPay | Copy |
| KR | Toss · KakaoPay | Recipient · Copy |
| CN | WeChat Pay · Alipay | Copy |
| HK | FPS · PayMe · AlipayHK | Copy (or a stored PayMe link: Recipient) |
| TW | LINE Pay · JKOPAY | Copy |
| BR | Pix | QR + "Pix copia e cola" |
| MX | SPEI (CLABE, validated) · Mercado Pago | Copy |
| AR | Mercado Pago (CVU / alias) | Copy |
| CO | Nequi · Bre-B | Copy |
| CL | Bank transfer · MACH · Mercado Pago | Copy |
| PE | Yape · Plin | Copy |
| NG | Bank transfer · OPay · PalmPay | Copy |
| KE / TZ | M-Pesa | Copy |
| ZA | Bank transfer · PayShap | Copy |
| GH | MTN MoMo · Telecel Cash | Copy |
| Worldwide | PayPal · Revolut · Wise · Bank transfer · Other | Prefill · Recipient · Copy · Copy/QR (EUR IBAN) · Copy |

The app picks the country with `detectPaymentCountry`. It uses the region in the device locale first (`en_US` → US), then the bill currency's home country (`currencyHomeCountry`). EUR, which many countries share, gives the euro list.

## Link formats in the code

| Method | Template | Status |
|---|---|---|
| PayPal.me | `https://paypal.me/<user>/<amount><CUR>`. The amount is added only for the currencies PayPal.me supports. Email handles are copied instead. | Verified against PayPal's PayPal.Me FAQ ([source](https://www.paypal.com/us/smarthelp/article/What-is-PayPal.Me-FAQ3025)) |
| Venmo | `venmo://paycharge?txn=pay&recipients=<u>&amount=<a>&note=<n>`, with the web fallback `https://venmo.com/?txn=pay&recipients=…&amount=…&note=…` | The web parameters appear on Venmo's payment-links page ([venmo.com/paymentlinks](https://venmo.com/paymentlinks)). The `venmo://` scheme is community-documented only. |
| Cash App | `https://cash.app/$<tag>/<amount>` (USD only) | Community / Square developer forum. Not in official docs. |
| Monzo | `https://monzo.me/<user>/<amount>?d=<note>` (GBP only) | `/amount` is documented by Monzo ([help](https://monzo.com/help/monzo-with-friends/monzo-me-how-to)). `?d=` is community-documented. |
| Revolut | `https://revolut.me/<revtag>` (recipient only) | Verified ([Revolut help](https://help.revolut.com/help/transfers/payment-links/revolut-me-link/)). The app doesn't add an amount path, because none is documented. |
| Toss | `https://toss.me/<id>` (recipient only) | Blog-level source. The amount path is unverified, so the app doesn't use it. |
| UPI | `upi://pay?pa=<vpa>&pn=<name>&am=<0.00>&cu=INR&tn=<note>`; the QR code uses the same string | NPCI UPI Linking Specification ([copy](https://www.labnol.org/files/linking.pdf)) |
| Swish | `swish://payment?data=<urlencoded JSON {version:1, payee, amount, message}>` | Format from Swish's QR / app-switch "prefilled" spec, seen through open-source libraries ([swish_qr](https://www.ruby-toolbox.com/projects/swish_qr)). Not confirmed for private payee numbers. If the app can't open the link, the number is copied instead. |
| Apple Cash | `sms:<phone or email>&body=<message>` (iOS only) | See the limitations below |
| Pix | EMV BR Code: tag 26 {`br.gov.bcb.pix`, key, description}, 52 `0000`, 53 `986`, 54 amount, 58 `BR`, 59 name, 60 city, 62/05 `***`, 63 CRC16 | Verified: the test reproduces the BCB manual example `…63041D3D` ([BCB manual](https://www.bcb.gov.br/content/estabilidadefinanceira/pix/Regulamento_Pix/II_ManualdePadroesparaIniciacaodoPix.pdf)) |
| PromptPay | EMV tag 29 {`A000000677010111`; 01 `0066`+mobile / 02 national ID / 03 e-wallet}, 58 `TH`, 53 `764`, 54 amount, CRC | Tests match the `dtinth/promptpay-qr` vectors (`…8956`, `…E469`, `…7B5A`). Spec details from [thai-qr-payment](https://thai-qr-payment.js.org/reference/spec/). The Bank of Thailand PDF was not reviewed. |
| PayNow | SGQR tag 26 {`SG.PAYNOW`; 01 `0` mobile / `2` UEN; 02 proxy; 03 editable}, 53 `702`, 58 `SG` | Structure from open-source generators. The MAS/ABS spec was not reviewed. Tested for structure and CRC only. |
| VietQR | EMV tag 38 {`A000000727`; 01 {BIN, account}; 02 `QRIBFTTA`}, 53 `704`, 58 `VN` | From open-source libraries ([napas-qr-python](https://pypi.org/project/napas-qr-python/0.1.0/)). The NAPAS spec isn't public. Tested for structure and CRC only. |
| SEPA EPC QR (GiroCode) | `BCD` / `002` / `1` / `SCT` / BIC (optional) / name / IBAN / `EUR<amt>` / purpose / ref / text | EPC069-12 v3.0 ([EPC](https://europeanpaymentscouncil.eu/sites/default/files/kb/file/2022-09/EPC069-12%20v3.0%20Quick%20Response%20Code%20-%20Guidelines%20to%20Enable%20the%20Data%20Capture%20for%20the%20Initiation%20of%20an%20SCT_0.pdf)) |
| QR Platba (CZ) | `SPD*1.0*ACC:<IBAN>*AM:<0.00>*CC:CZK*RN:<name>*MSG:<text>` | ČBA standard v1.2 ([PDF](https://cbaonline.cz/upload/1408-standard-qr-kody-leden-2021.pdf)) |
| CLABE (MX) | 18 digits with a (3, 7, 1) mod-10 check digit, validated before copying | Banxico CLABE structure. The test uses the well-known `002010077777777771`. |

## Limitations

- **Apple Cash.** There is no public API or URL scheme that lets a third-party app send Apple Cash. An Apple engineer said so on the Apple Developer Forums ([thread 650953](https://developer.apple.com/forums/thread/650953), June 2020): sending is available only in Messages, not through third-party apps. FinanceKit only reads data. Here is what the app does instead:
  - The recipient saves their phone number or email.
  - On iOS, Pay opens Messages to that contact with the prefilled note "Paying you USD 16.38 for Sea Breeze Grill via Apple Cash". The amount is also on the clipboard. The payer taps the Apple Cash button in Messages.
  - The method is offered only on iOS and only for the US. Apple Cash is a US programme, and Apple's support article lists steps for iPhone and Apple Watch only ([Apple support](https://support.apple.com/105013)). Sending from a Mac is unconfirmed, so macOS is excluded.
  - The `sms:<to>&body=` form is the long-standing iOS form. It wasn't tested on a device in this pass.
- **Zelle.** The standalone Zelle app stopped sending payments on 1 April 2025 ([Kiplinger](https://www.kiplinger.com/personal-finance/banking/zelle-app-shut-down-why-zelle-discontinued-its-app)). Zelle now lives inside each bank's app and has no public deep link. The app copies the email or phone number and tells the payer to open their bank app and choose Zelle.
- **Bizum, MB WAY, BLIK, Satispay, TWINT, Vipps, MobilePay, Lydia, Wero, Payconiq, M-Pesa, PayPay, KakaoPay, WeChat Pay, Alipay and the Gulf instant-payment systems** (sarie, Aani, WAMD, Fawran, BenefitPay, CliQ). None of them has a public link that prefills a payment to a friend. Their public link APIs are merchant-only, or links can only be made inside the app. The app copies the phone number, alias or ID.
  - TWINT's payment link is a business product ([TWINT](https://www.twint.ch/en/business-customers/products/twint-for-online-shops/payment-link/)).
  - Vipps MobilePay's ePayment API is for merchants only. MobilePay is being renamed Vipps in DK and FI from January 2027.
- **Tikkie, InstaPay, PayMe and monobank.** The links are created by the requester inside the provider's app, so the app can't build them. If the recipient pastes their own link, the app opens it and copies the amount.
- **UPI on iOS.** `upi://` is not reliably handled on iOS, because UPI apps register their own schemes there. When the link can't open, the app falls back to copying the VPA, and the UPI QR still works. Some UPI apps also limit amounts in P2P intents for security reasons. Not tested on a device.
- **Swish.** The prefilled app-switch format is documented for QR / app-switch. Whether it works for private Swish numbers was **not verified on a device**. Copying is the fallback.
- **Papara (TR).** It has been under state trustee (TMSF) since 2025, with restricted accounts ([source](https://www.ensonhaber.com/tmsfye-gecen-paparadan-aciklama-h1438651)). It is listed after FAST/IBAN and kept mainly for existing users.
- **Payconiq (BE/LU).** It is being replaced by Wero during 2026 ([Payconiq](https://www.payconiq.be/en/payconiq-evolves)).
- **DuitNow QR, QRIS, QR Ph (GCash/Maya) and KHQR.** No public specification was found, so the app has no QR for them. Those methods are copy-only.
- **Weak sources.** The rankings for LB, CL, IS (Kass vs Aur) and NG rest on weak or general-knowledge sources and should be re-checked.

## Sources for the method rankings

- US: Kiplinger on the Zelle app shutdown (above).
- GB: Monzo help (above).
- CH: [TWINT send and request](https://www.twint.ch/en/private-customers/payment/send-and-request-money/).
- FR: [Paylib → Wero](https://www.moneyvox.fr/carte-bancaire/paylib.php).
- BE: [Payconiq evolves](https://www.payconiq.be/en/payconiq-evolves).
- LU: [Worldline on Payconiq → Wero](https://worldline.com/en-lu/home/main-navigation/resources/blogs/2026/what-happens-to-payconiq-when-wero-arrives-in-luxembourg).
- NL: [ABN AMRO Tikkie record year](https://www.abnamro.com/nl/nieuws/tikkie-beleeft-nieuw-recordjaar-en-doorbreekt-grens-van-een-miljard).
- PT: [SIBS MB WAY](https://www.sibs.com/marcas/mbway/).
- DK/FI: [MobilePay → Vipps rebrand](https://thepaypers.com/payments/news/mobilepay-to-be-rebranded-as-vipps-across-the-nordics).
- PL: [BLIK P2P 2025](https://antyweb.pl/blik-p2p-2025).
- CZ: ČBA (above).
- EG: [HSBC Egypt IPN FAQ](https://www.egypt.hsbc.com/ways-to-bank/instant-payment-network/faqs/).
- SA: [STC Bank transformation](https://stcbank.com.sa/en/notice-of-transformation-to-stc-bank).
- AE: [WAM on Aani](https://www.wam.ae/en/article/bzna1fc-uae-instant-payments-platform-aani-tops-125).
- KW: [KFH WAMD](https://www.kfh.com/en/home/Personal/news/2024/KFH-Launches--WAMD--for-Sending-and-Receiving-Money-via-Mobile-Number.html).
- QA: [QNA on Fawran](https://www.qna.org.qa/en/News-Area/News/2024-03/07/0036-qcb-launches-'fawran'-instant-payment-service).
- OM: [Zawya on CBO fee waiver](https://www.zawya.com/en/economy/gcc/central-bank-of-oman-announces-fee-waiver-for-local-digital-transfers-pumaks2t).
- JO: [JoPACC](https://www.jopacc.com/node/647).
- MA: [TelQuel on instant transfers](https://telquel.ma/instant-t/2026/10/22/les-virements-instantanes-bondissent-de-78-en-2025_2014264/).
- TN: [Webdo on D17 / e-Dinar](https://www.webdo.tn/fr/actualite/national/la-poste-tunisienne-lance-le-wallet-e-dinar-gratuit-pour-ces-services/379737/).
- DZ: [Algérie360 on BaridiMob](https://www.algerie360.com/algerie-poste-quelles-sont-conditions-pour-transferer-de-largent-via-lapplication-baridimob/).
- IQ: [AGBI on ZainCash](https://www.agbi.com/banking-finance/2026/06/zaincash-ceo-iraq-is-5-years-behind-in-digital-payments/).
- PK: [SBP Raast P2P](https://www.sbp.org.pk/our-subsidiaries/raast/raast-person-to-person).
- VN: [MoMo](https://momo.vn/chuyen-tien).
- JP: [LY Corp on the LINE Pay Japan shutdown](https://www.lycorp.co.jp/en/news/release/008632/).
- KR: [Toss](https://toss.im/service/easy-remittance).
- MX: [DiMo adoption](https://mexicobusiness.news/finance/news/banxico-pushes-broader-adoption-dimo-payments-2025).
- CO: [Bre-B launch](https://actualicese.com/bre-b-ya-esta-operando-oficialmente-y-van-mas-de-82-millones-de-llaves-registradas/).
- PE: [BCRP interoperability](https://www.bcrp.gob.pe/docs/Sistema-Pagos/articulos/estrategia-de-interoperabilidad-2025-1.pdf).
- ZA: [TechCentral on PayShap](https://techcentral.co.za/three-years-in-payshap-pivots-to-merchants/281687/).
- Other rows (CA Interac, AU PayID, ES Bizum, SE Swish, IN UPI, BD bKash, MY DuitNow, SG PayNow, TH PromptPay, CN, HK, KE M-Pesa, NG, GH) rely on the providers' official sites. Those sites were not re-opened on the verification date.

## Storage compatibility

- **Profiles.** `customPaymentMethods` on `users/{uid}` and on `publicProfiles/{uid}` stays a list of `{name, value}`. 2.0 adds an optional `type` field holding the registry id. Older app versions ignore it.
- **Old formats.** The pre-1.0 `paymentMethods` map and the bill-level `paymentMethods` map (`{name: value}`) are read through `parseStoredPaymentMethods` and `parseBillPaymentMethods`.
- **Matching without a `type`.** A stored method with no `type` is matched first by its name: exact alias, then a whole-word alias, then the alias inside one word. If that fails, it is matched by its value (provider link host, `$cashtag`, UPI VPA, IBAN). Anything left over becomes `other`.
