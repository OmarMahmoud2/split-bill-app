import os

# ==============================================================================
# Split Bill Metadata Generator
# This script generates ALL store metadata (Title, Description, URLs, etc.)
# for 15+ locales used in both the App Store and Google Play.
# ==============================================================================

# Base Metadata (English UK)
BASE_TITLE = "Split Bill - Receipt Scanner"
BASE_SHORT = "Scan receipts & split fairly with AI. No more math after dinner!"
BASE_PROMO = "Split bills instantly with AI! No more awkward math at dinner."
BASE_DESC = """Tired of doing math after dinner? Split Bill makes it easy.

Features:
- AI Receipt Scanning: Just snap a photo. We extract items & prices automatically.
- Easy Splitting: Assign items to friends with a tap.
- Tax & Tip: Auto-calculated for everyone.
- Share Instantly: Send breakdown links to friends.
- Multiple Currencies: Splitting bills while traveling? We've got you covered.
- History: Keep track of all your past splits and who owes what.

Download now and never fight over the bill again!"""
BASE_KEYWORDS = "split, bill, receipts, scanner, expense, sharing, group, dinner, ai, finance"
BASE_CHANGELOG = "Improved flow, Bug Fixes, more languages and currencies added (1.1.0=8)"

# Mandatory URLs for iOS
SUPPORT_URL = "https://omarmali.net/split-app-terms/"
PRIVACY_URL = "https://omarmali.net/split-app-terms/"
MARKETING_URL = "https://omarmali.net/" # Often same as support

# Localized Content
# IMPORTANT: Android titles MUST be 30 characters or less.
locales = {
    'en': {
        'title': "Split Bill - Receipt Scanner",
        'short': "Scan receipts & split fairly with AI. No more math after dinner!",
        'promo': "Split bills instantly with AI! No more awkward math at dinner.",
        'desc': BASE_DESC,
        'keywords': BASE_KEYWORDS,
        'changelog': BASE_CHANGELOG
    },
    'ar': {
        'title': "تقسيم الفاتورة - مسح الإيصالات",
        'short': "امسح الفاتورة وقسمها بالذكاء الاصطناعي. وداعاً لحسابات العشاء المعقدة!",
        'promo': "قسم الفاتورة فوراً بالذكاء الاصطناعي! لا مزيد من الحسابات المحرجة.",
        'desc': """تعبت من الحسابات بعد العشاء؟ تطبيق تقسيم الفاتورة يسهل عليك الأمر.

الميزات:
- مسح الإيصالات بالذكاء الاصطناعي: فقط التقط صورة. نستخرج العناصر والأسعار تلقائيًا.
- تقسيم سهل: خصص العناصر للأصدقاء بلمسة واحدة.
- الضرائب والإكرامية: تُحسب تلقائيًا للجميع.
- مشاركة فورية: أرسل تفاصيل الفاتورة للأصدقاء.
- عملات متعددة: هل تقسم الفواتير أثناء السفر؟ نحن نوفر لك ذلك.
- السجل: تتبع جميع فواتيرك السابقة ومن مدين لك.

حمل التطبيق الآن ولا تختلف مع أصدقائك على الفاتورة أبدًا!""",
        'keywords': "تقسيم, فاتورة, إيصالات, ماسح, مصاريف, مشاركة, مجموعة, عشاء, ذكاء اصطناعي",
        'changelog': "تحسين التدفق، إصلاح الأخطاء، إضافة المزيد من اللغات والعملات (1.1.0=8)"
    },
    'de': {
        'title': "Split Bill - Belegscanner",
        'short': "Belege scannen & fair teilen mit KI. Schluss mit Rechnen nach dem Essen!",
        'promo': "Rechnungen sofort per KI teilen! Kein peinliches Rechnen mehr.",
        'desc': """Müde vom Rechnen nach dem Essen? Split Bill macht es einfach.

Funktionen:
- KI-Belegscanning: Einfach ein Foto machen. Wir extrahieren Artikel & Preise automatisch.
- Einfaches Teilen: Artikel Freunden mit einem Fingertipp zuweisen.
- Steuern & Trinkgeld: Automatisch für jeden berechnet.
- Sofort teilen: Aufschlüsselungs-Links an Freunde senden.
- Mehrere Währungen: Rechnungen auf Reisen teilen? Wir unterstützen Sie.
- Verlauf: Behalten Sie alle vergangenen Teilungen im Blick.

Jetzt herunterladen und nie wieder über die Rechnung streiten!""",
        'keywords': "teilen, rechnung, beleg, scanner, ausgaben, gruppe, essen, ki, finanzen",
        'changelog': "Verbesserter Ablauf, Fehlerbehebungen, weitere Sprachen und Währungen hinzugefügt (1.1.0=8)"
    },
    'es': {
        'title': "Split Bill - Escáner Recibos",
        'short': "Escanea recibos y divide con IA. ¡Se acabó calcular tras la cena!",
        'promo': "¡Divide cuentas al instante con IA! No más cuentas incómodas.",
        'desc': """¿Cansado de calcular después de cenar? Split Bill lo hace fácil.

Características:
- Escaneo de recibos con IA: Haz una foto. Extraemos artículos y precios automáticamente.
- División fácil: Asigna artículos a amigos con un toque.
- Impuestos y propinas: Cálculo automático para todos.
- Comparte al instante: Envía enlaces con el desglose a tus amigos.
- Múltiples monedas: ¿Divides cuentas viajando? Te cubrimos.
- Historial: Rastrea tus divisiones pasadas y quién debe qué.

¡Descárgalo ahora y no vuelvas a discutir por la cuenta!""",
        'keywords': "dividir, cuenta, recibo, escáner, gastos, grupo, cena, ia, finanzas",
        'changelog': "Flujo mejorado, corrección de errores, más idiomas y monedas añadidos (1.1.0=8)"
    },
    'fr': {
        'title': "Split Bill - Scanner Reçus",
        'short': "Scannez les reçus et divisez avec l'IA. Fini les calculs après le dîner !",
        'promo': "Divisez les comptes instantanément with l'IA！Plus de calculs gênants.",
        'desc': """Fatigué de calculer après le dîner ? Split Bill vous facilite la vie.

Fonctionnalités :
- Scan de reçus par IA : Prenez une photo. Nous extrayons articles et prix automatiquement.
- Division facile : Attribuez les articles aux amis d'une simple pression.
- Taxes et pourboires : Calculés automatiquement pour tout le monde.
- Partage instantané : Envoyez des liens de répartition à vos amis.
- Plusieurs devises : Vous divisez les comptes en voyage ? Nous avons ce qu'il vous faut.
- Historique : Gardez une trace de vos partages passés.

Téléchargez maintenant et ne vous disputez plus jamais pour l'addition !""",
        'keywords': "diviser, addition, reçu, scanner, dépenses, groupe, dîner, ia, finance",
        'changelog': "Flux amélioré, corrections de bugs, ajout de nouvelles langues et devises (1.1.0=8)"
    },
    'hi': {
        'title': "Split Bill - रसीद स्कैनर",
        'short': "AI के साथ रसीदें स्कैन करें और सटीक विभाजित करें। भोजन के बाद गणित की ज़रूरत नहीं!",
        'promo': "AI के साथ बिल तुरंत विभाजित करें! अब कोई अजीब गणित नहीं।",
        'desc': """भोजन के बाद गणित करने से थक गए हैं? Split Bill इसे आसान बनाता है।

विशेषताएं:
- AI रसीद स्कैनिंग: बस एक फोटो लें। हम स्वचालित रूप से आइटम और कीमतें निकालते हैं।
- आसान विभाजन: एक टैप के साथ दोस्तों को आइटम असाइन करें।
- टैक्स और टिप: सभी के लिए स्वचालित रूप से गणना।
- तुरंत साझा करें: दोस्तों को ब्रेकडाउन लिंक भेजें।
- कई मुद्राएं: यात्रा के दौरान बिलों का विभाजन? हमने इसे कवर किया है।
- इतिहास: पिछले सभी विभाजनों और किसे क्या देना है, इसका ट्रैक रखें।

अभी डाउनलोड करें और बिल को लेकर कभी झगड़ा न करें!""",
        'keywords': "विभाजित, बिल, रसीद, स्कैनर, खर्च, साझाकरण, समूह, भोजन, एआई, वित्त",
        'changelog': "बेहतर प्रवाह, बग फिक्स, अधिक भाषाएं और मुद्राएं जोड़ी गईं (1.1.0=8)"
    },
    'id': {
        'title': "Split Bill - Pemindai Struk",
        'short': "Pindai struk & bagi adil dengan AI. Tidak ada lagi hitungan rumit!",
        'promo': "Bagi tagihan instan dengan AI! Tidak ada lagi hitungan canggung.",
        'desc': """Lelah menghitung tagihan setelah makan? Split Bill memudahkannya.

Fitur:
- AI Struk Scanning: Cukup ambil foto. Kami ekstrak item & harga otomatis.
- Pembagian Mudah: Berikan item ke teman dengan satu sentuhan.
- Pajak & Tip: Dihitung otomatis untuk semua orang.
- Bagikan Instan: Kirim link rincian tagihan ke teman.
- Berbagai Mata Uang: Traveling? Kami mendukung pembagian mata uang asing.
- Riwayat: Pantau semua pembagian yang lalu dan siapa yang berhutang.

Unduh sekarang dan jangan pernah bertengkar karena tagihan lagi!""",
        'keywords': "bagi, tagihan, struk, pemindai, pengeluaran, grup, makan, ai, keuangan",
        'changelog': "Alur ditingkatkan, perbaikan bug, penambahan lebih banyak bahasa and mata uang (1.1.0=8)"
    },
    'it': {
        'title': "Split Bill - Scanner Ricevute",
        'short': "Scansiona ricevute e dividi con l'IA. Basta conti dopo cena!",
        'promo': "Dividi i conti istantaneamente con l'IA! Niente più calcoli imbarazzanti.",
        'desc': """Stanco di fare calcoli dopo cena? Split Bill rende tutto semplice.

Funzionalità:
- Scansione Ricevute IA: Scatta una foto. Estraiamo articoli e prezzi in automatico.
- Divisione Facile: Assegna gli articoli agli amici con un tocco.
- Tasse e Mance: Calcolate automaticamente per tutti.
- Condivisione Istantanea: Invia i link del riepilogo agli amici.
- Più Valute: Dividi i conti in viaggio? Ci pensiamo noi.
- Cronologia: Tieni traccia di tutte le tue condivisioni passate.

Scarica ora e non lititare mai più per il conto!""",
        'keywords': "dividere, conto, ricevuta, scanner, spese, gruppo, cena, ia, finanza",
        'changelog': "Flusso migliorato, correzioni di bug, aggiunte nuove lingue e valute (1.1.0=8)"
    },
    'ja': {
        'title': "Split Bill - レシート読取",
        'short': "AIでレシートをスキャンして公平に分割。食後の暗算はもう不要！",
        'promo': "AIで即座に割り勘！面倒な計算から解放されます。",
        'desc': """食後の計算に疲れていませんか？Split Billが解決します。

特徴：
- AIレシートスキャン：写真を撮るだけ。商品と価格を自動抽出。
- 簡単割り勘：タップ一つで友達に商品を割り当て。
- 税金・チップ：全員分を自動計算。
- 即時に共有：友達に詳細リンクを送信。
- 多通貨対応：旅行中の割り勘もお任せください。
- 履歴管理：過去の割り勘履歴や貸し借りを一目で確認。

今すぐダウンロードして、支払いのトラブルをなくしましょう！""",
        'keywords': "分割, 割り勘, レシート, スキャナー, 経費, グループ, 食事, ai, 金融",
        'changelog': "フローの改善、バグ修正、新しい言語と通貨の追加 (1.1.0=8)"
    },
    'ko': {
        'title': "Split Bill - 영수증 스캐너",
        'short': "AI로 영수증을 스캔하고 공정하게 분할하세요. 식사 후 복잡한 계산은 이제 그만!",
        'promo': "AI로 즉석에서 더치페이! 어색한 계산 시간이 필요 없습니다.",
        'desc': """식사 후 영수증 계산이 스트레스인가요? Split Bill이 도와드립니다.

주요 기능:
- AI 영수증 스캔: 사진만 찍으세요. 품목과 가격을 자동으로 추출합니다.
- 간편한 분할: 탭 한 번으로 친구에게 품목을 할당하세요.
- 세금 및 팁: 모든 사람의 몫을 자동으로 계산합니다.
- 즉시 공유: 상세 내역 링크를 친구들에게 보내세요.
- 다국어 및 다화폐: 여행 중에도 문제없이 더치페이하세요.
- 히스토리: 과거 내역과 미정산 금액을 한눈에 관리하세요.

지금 다운로드하고 결제 걱정 없이 식사를 즐기세요!""",
        'keywords': "분할, 영수증, 스캐너, 비용, 공유, 그룹, 식사, ai, 금융, 더치페이",
        'changelog': "흐름 개선, 버그 수정, 더 많은 언어와 통화 추가 (1.1.0=8)"
    },
    'pl': {
        'title': "Split Bill - Skaner Paragon",
        'short': "Skanuj paragony i dziel rachunki z AI. Koniec z liczeniem po kolacji!",
        'promo': "Dziel rachunki natychmiast z AI! Koniec z niezręcznymi obliczeniami.",
        'desc': """Masz dość liczenia po kolacji? Split Bill ułatwia sprawę.

Cechy:
- Skanowanie paragonów AI: Zrób zdjęcie. Automatycznie wyodrębnimy produkty i ceny.
- Łatwe dzielenie: Przypisuj produkty znajomym jednym dotknięciem.
- Podatki i napiwki: Automatycznie przeliczane dla każdego.
- Udostępnij natychmiast: Wysyłaj linki z podsumowaniem do znajomych.
- Wiele walut: Dzielenie rachunków w podróży? Mamy cię.
- Historia: Śledź wszystkie przeszłe podziały i rozliczenia.

Pobierz teraz i nigdy więcej nie kłóć się o rachunek!""",
        'keywords': "dzielenie, rachunek, paragon, skaner, wydatki, grupa, kolacja, ai, finanse",
        'changelog': "Ulepszony przepływ, poprawki błędów, dodano więcej języków i walut (1.1.0=8)"
    },
    'pt': {
        'title': "Split Bill - Scanner Recibos",
        'short': "Escaneie recibos e divida com IA. Chega de cálculos após o jantar!",
        'promo': "Divida contas instantaneamente com IA！Sem contas constrangedoras.",
        'desc': """Cansado de fazer contas depois de jantar? Split Bill facilita tudo.

Funcionalidades:
- Escaneamento de Recibos por IA: Tire uma foto. Extraímos itens e preços automaticamente.
- Divisão Fácil: Atribua itens aos amigos com um toque.
- Impostos e Gorjetas: Calculados automaticamente para todos.
- Compartilhe Instantaneamente: Envie links de detalhamento aos amigos.
- Múltiplas Moedas: Dividindo contas em viagens? Nós cuidamos disso.
- Histórico: Acompanhe todas as divisões passadas e quem deve o quê.

Baixe agora e nunca mais discuta pela conta!""",
        'keywords': "dividir, conta, recibo, scanner, despesas, grupo, jantar, ia, finanças",
        'changelog': "Fluxo melhorado, corrections de bugs, mais idiomas and moedas adicionados (1.1.0=8)"
    },
    'ru': {
        'title': "Split Bill - Сканер Чеков",
        'short': "Сканируйте чеки и делите счет с ИИ. Забудьте о математике после ужина!",
        'promo': "Делите счет мгновенно с ИИ! Никаких неловких расчетов.",
        'desc': """Устали считать после ужина? Split Bill сделает это за вас.

Особенности:
- Сканирование чеков ИИ: Просто сделайте фото. Мы автоматически извлечем товары и цены.
- Легкое разделение: Назначайте товары друзьям одним нажатием.
- Налоги и чаевые: Автоматический расчет для каждого.
- Мгновенная отправка: Делитесь ссылкой на расчет с друзьями.
- Несколько валют: Делите счета в путешествиях? Мы поможем.
- История: Следите за всеми прошлыми расчетами и долгами.

Скачайте сейчас и забудьте о спорах из-за счетов!""",
        'keywords': "разделить, счет, чек, сканер, расходы, группа, ужин, ии, финансы",
        'changelog': "Улучшенный интерфейс, исправления ошибок, добавлено больше языков и валют (1.1.0=8)"
    },
    'ur': {
        'title': "Split Bill - رسید اسکینر",
        'short': "AI کے ساتھ رسیدیں اسکین کریں اور درست تقسیم کریں۔ کھانے کے بعد حساب کی ضرورت نہیں!",
        'promo': "AI کے ساتھ بل فوری تقسیم کریں! اب کوئی عجیب حساب کتاب نہیں۔",
        'desc': """کھانے کے بعد حساب کتاب کرنے سے تھک گئے ہیں؟ Split Bill اسے آسان بناتا ہے۔

خصوصیات:
- AI رسید اسکیننگ: بس ایک فوٹو لیں۔ ہم خودکار طور پر آئٹمز اور قیمتیں نکالتے ہیں۔
- آسان تقسیم: ایک ٹیپ کے ساتھ دوستوں کو آئٹمز تفویض کریں۔
- ٹیکس اور ٹپ: سب کے لیے خودکار طور پر حساب۔
- فوری شیئر کریں: دوستوں کو بریک ڈاؤن لنک بھیجیں۔
- کئی کرنسیاں: سفر کے دوران بلوں کی تقسیم؟ ہم نے اسے کور کیا ہے۔
- ہسٹری: پچھلے تمام تقسیم اور کس نے کیا دینا ہے، اس کا تریک رکھیں۔

 ابھی ڈاؤن لوڈ کریں اور بل کو لے کر کبھی جھگڑا نہ کریں!""",
        'keywords': "تقسیم, بل, رسید, اسکینر, اخراجات, شیئرنگ, گروپ, کھانا, اے آئی, فنانس",
        'changelog': "بہتر روانی، بگ فکسز، مزید زبانیں اور کرنسیاں شامل کی گئیں (1.1.0=8)"
    },
    'zh': {
        'title': "Split Bill - 收据扫描分摊",
        'short': "AI扫描收据，公平分账。用餐后无需再心算！",
        'promo': "AI瞬间分账！告别尴尬的计算时间。",
        'desc': """聚餐后还在为谁该付多少钱烦恼吗？Split Bill 来帮你。

主要功能：
- AI 扫描收据：拍张照即可。我们自动提取品名和价格。
- 轻松分摊：轻轻一点，即可将菜品分配给好友。
- 税费与小费：为每个人自动计算比例。
- 快速分享：将会计详单链接发送给好友。
- 多币种支持：出国旅行也能轻松分账。
- 历史记录：追踪所有过往的分账和欠款情况。

立即下载，再也不用为买单争吵！""",
        'keywords': "分账, 账单, 收据, 扫描, 费用, 分担, 聚餐, ai, 金融, 扫码",
        'changelog': "改进了流程，修复了错误，添加了更多语言 and 货币 (1.1.0=8)"
    }
}

# Mapping codes for iOS and Android
ios_mappings = {
    'en': ['en-US', 'en-GB', 'en-AU', 'en-CA'],
    'ar': ['ar-SA'],
    'de': ['de-DE'],
    'es': ['es-ES', 'es-MX'],
    'fr': ['fr-FR', 'fr-CA'],
    'hi': ['hi'],
    'id': ['id'],
    'it': ['it'],
    'ja': ['ja'],
    'ko': ['ko'],
    'pl': ['pl'],
    'pt': ['pt-BR', 'pt-PT'],
    'ru': ['ru'],
    'zh': ['zh-Hans', 'zh-Hant']
}

android_mappings = {
    'en': ['en-US', 'en-GB', 'en-AU', 'en-CA'],
    'ar': ['ar'],
    'de': ['de-DE'],
    'es': ['es-ES', 'es-US'],
    'fr': ['fr-FR', 'fr-CA'],
    'hi': ['hi-IN'],
    'id': ['id'],
    'it': ['it-IT'],
    'ja': ['ja-JP'],
    'ko': ['ko-KR'],
    'pl': ['pl-PL'],
    'pt': ['pt-BR', 'pt-PT'],
    'ru': ['ru-RU'],
    'ur': ['ur'],
    'zh': ['zh-CN', 'zh-TW']
}

# Helper to write files
def write_file(base_path, locale, filename, content):
    loc_path = os.path.join(base_path, locale)
    os.makedirs(loc_path, exist_ok=True)
    file_path = os.path.join(loc_path, filename)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

# Process iOS
ios_base = 'fastlane/metadata'
for lang, config in locales.items():
    if lang in ios_mappings:
        for locale in ios_mappings[lang]:
            write_file(ios_base, locale, 'name.txt', config['title'])
            write_file(ios_base, locale, 'description.txt', config['desc'])
            write_file(ios_base, locale, 'subtitle.txt', config['short'])
            write_file(ios_base, locale, 'promotional_text.txt', config['promo'])
            write_file(ios_base, locale, 'keywords.txt', config['keywords'])
            write_file(ios_base, locale, 'release_notes.txt', config['changelog'])
            # ADDING MISSING URLs
            write_file(ios_base, locale, 'support_url.txt', SUPPORT_URL)
            write_file(ios_base, locale, 'privacy_url.txt', PRIVACY_URL)
            write_file(ios_base, locale, 'marketing_url.txt', MARKETING_URL)

# Process Android
android_base = 'fastlane/metadata/android'
for lang, config in locales.items():
    if lang in android_mappings:
        for locale in android_mappings[lang]:
            write_file(android_base, locale, 'title.txt', config['title'])
            write_file(android_base, locale, 'full_description.txt', config['desc'])
            write_file(android_base, locale, 'short_description.txt', config['short'])
            # Android changelogs are per-version
            changelog_dir = os.path.join(android_base, locale, "changelogs")
            os.makedirs(changelog_dir, exist_ok=True)
            with open(os.path.join(changelog_dir, "8.txt"), 'w', encoding='utf-8') as f:
                f.write(config['changelog'])

print("✅ Metadata generation (with URLs) completed for ALL locales!")
