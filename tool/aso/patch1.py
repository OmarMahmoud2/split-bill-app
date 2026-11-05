import io
R = {
 "copy_en.py": [
  ('"expense,holiday,flatmate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,kitty,trip"', '"expense,holiday,flatmate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,kitty"'),
  ('"expense,trip,roommate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,etransfer,cottage"', '"expense,trip,roommate,friends,dinner,tip,owe,iou,share,travel,voice,pay,calculator,debt,etransfer"'),
 ],
 "copy_eu.py": [
  (',gruppenkasse,reisekasse,beleg,ki"', ',reisekasse,beleg,ki"'),
  (',schuld,reis,fooi,verdelen,potje,wie betaalt,ai"', ',schuld,reis,fooi,verdelen,potje,ai"'),
  ('"Scan de bon, zeg wie wat had, verreken. Vrienden betalen via een link, zonder app."', '"Scan de bon, zeg wie wat had, verreken. Vrienden betalen via een link."'),
  (',ai,betala,räkning,gemensamt"', ',ai,betala,räkning"'),
  ('"Skanna kvittot, säg vem som tog vad, gör upp. Vänner betalar via en länk, utan app."', '"Skanna kvittot, säg vem som tog vad, gör upp. Vänner betalar via en länk."'),
  (',bofæller,ai,betal,regnskab,fælles"', ',bofæller,ai,betal,fælles"'),
  ('"Scan kvitteringen, sig hvem der fik hvad, afregn. Venner betaler via et link, uden app."', '"Scan kvitteringen, sig hvem der fik hvad, afregn. Venner betaler via et link."'),
  (',tips,splitte,deling,ferie,kollektiv,ai,betal,regnskap,felles"', ',tips,splitte,ferie,kollektiv,ai,betal,regnskap,felles"'),
  ('"Skann kvitteringen, si hvem som fikk hva, gjør opp. Venner betaler via en lenke, uten app."', '"Skann kvitteringen, si hvem som fikk hva, gjør opp. Venner betaler via en lenke."'),
  ('"dépenses,partage,frais,groupe,voyage,coloc,amis,restaurant,pourboire,dettes,note,compte,vacances,ia,diviser,rembourser"', '"dépenses,partage,frais,groupe,voyage,coloc,amis,pourboire,dettes,note,compte,vacances,ia,diviser"'),
  ('"Scannez le ticket, dites qui a pris quoi, réglez. Vos amis paient depuis un lien."', '"Scannez le ticket, dites qui a pris quoi, réglez. Vos amis paient par lien."'),
  ('"dépenses,partage,frais,groupe,voyage,coloc,amis,restaurant,pourboire,dettes,note,compte,vacances,ia,diviser,virement"', '"dépenses,partage,frais,groupe,voyage,coloc,amis,pourboire,dettes,note,compte,ia,diviser,virement"'),
  (',pagar,ia,bote,reparto,compañeros,vacaciones,calculadora"', ',pagar,ia,bote,reparto,vacaciones"'),
  (',pagar,ia,reparto,cuentas claras,calculadora,coperacha"', ',pagar,ia,reparto,cuentas claras"'),
  (',pagare,ia,ripartizione,vacanza,calcolo,alla romana"', ',pagare,ia,vacanza,alla romana"'),
  ('"Scansiona lo scontrino, di\' chi ha preso cosa, salda. Gli amici pagano da un link."', '"Scansiona lo scontrino, di\' chi ha preso cosa, salda. Amici pagano da un link."'),
  (',pagar,ia,rachar,vaquinha,calculadora,rateio"', ',pagar,ia,rachar,vaquinha,rateio"'),
  (',pagar,ia,rachar,férias,calculadora,partilha"', ',pagar,ia,rachar,férias,partilha"'),
  ('"Digitaliza o talão, diz quem pediu o quê, acerta. Os teus amigos pagam por um link."', '"Digitaliza o talão, diz quem pediu o quê, acerta. Os amigos pagam por um link."'),
  ('"wydatki,wspólne,grupa,wyjazd,znajomi,współlokator,kolacja,napiwek,długi,zapłać,ai,podział,kto ile,rozliczenie,kalkulator"', '"wydatki,wspólne,grupa,wyjazd,znajomi,kolacja,napiwek,długi,zapłać,ai,podział,kto ile,rozliczenie"'),
  ('"Zeskanuj paragon, powiedz kto co zamówił, rozlicz. Znajomi płacą z linku, bez aplikacji."', '"Zeskanuj paragon, powiedz kto co zamówił, rozlicz. Znajomi płacą z linku."'),
  (',ии,кто сколько,соседи,калькулятор,сплит,путешествие"', ',ии,кто сколько,соседи,сплит"'),
  (',paylaş,tatil,kim ne kadar,gider"', ',paylaş,tatil,gider"'),
  ('"Fişi tara, kim ne yedi söyle, hesaplaş. Arkadaşların bağlantıdan öder, uygulama gerekmez."', '"Fişi tara, kim ne yedi söyle, hesaplaş. Arkadaşların bağlantıdan öder."'),
 ],
 "copy_asia.py": [
  (',ديون,تقسيم المصاريف,حاسبة,ذكاء اصطناعي,سكن,سفر,ادفع,كم عليك"', ',ديون,تقسيم,حاسبة,ذكاء اصطناعي,سكن,سفر,ادفع,كم عليك"'),
  (',dinner,tip,calculator,dosti,पैसे,खर्च,हिस्सा,बराबर"', ',dinner,tip,dosti,पैसे,खर्च,हिस्सा,बराबर"'),
  ('"रसीद स्कैन करें, बोलें किसने क्या लिया, हिसाब चुकता करें। दोस्त लिंक से UPI पर चुकाएं।"', '"रसीद स्कैन करें, बोलें किसने क्या लिया, हिसाब करें। दोस्त लिंक से चुकाएं।"'),
  (',bayar,ai,hitung,siapa bayar apa,nota"', ',bayar,ai,hitung,nota"'),
  ('"Pindai struknya. Sebutkan siapa makan apa. Tiap rupiah jelas. Teman bayar lewat tautan dengan GoPay, DANA, OVO, atau transfer bank, tanpa aplikasi. Gratis, tanpa batas harian."', '"Pindai struk. Sebut siapa makan apa. Tiap rupiah jelas. Teman bayar lewat tautan dengan GoPay, DANA, atau transfer bank, tanpa aplikasi. Gratis, tanpa batas harian."'),
  ('"Pindai struk, sebutkan siapa makan apa, lunasi. Teman bayar lewat tautan, tanpa aplikasi."', '"Pindai struk, sebut siapa makan apa, lunasi. Teman bayar lewat tautan."'),
  (',chuyển khoản,tính,góp,quỹ,công bằng,chia đều,ai"', ',chuyển khoản,tính,góp,quỹ,chia đều,ai"'),
 ],
}
for fn, reps in R.items():
    s = io.open(fn, encoding="utf-8").read()
    for a, b in reps:
        assert s.count(a) == 1, (fn, a[:60], s.count(a))
        s = s.replace(a, b)
    io.open(fn, "w", encoding="utf-8").write(s)
print("patched")
