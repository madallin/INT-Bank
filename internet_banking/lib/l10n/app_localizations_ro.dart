// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'INTBank';

  @override
  String get errorsAparutEroareNeasteptataIncearca =>
      'A apărut o eroare neașteptată. Încearcă din nou.';

  @override
  String get errorsServerulRaspundeIncearcaNou =>
      'Serverul nu răspunde. Încearcă din nou în câteva momente.';

  @override
  String get errorsPotiConectaServerVerifica =>
      'Nu te poți conecta la server. Verifică conexiunea la internet.';

  @override
  String get errorsConexiuneaEsteSiguraOperatiunea =>
      'Conexiunea nu este sigură. Operațiunea a fost oprită.';

  @override
  String get errorsOperatiuneaFostAnulata => 'Operațiunea a fost anulată.';

  @override
  String get errorsSesiuneaExpiratAutentificaNou =>
      'Sesiunea a expirat. Autentifică-te din nou.';

  @override
  String get errorsPermisiuneaAceastaOperatiune =>
      'Nu ai permisiunea pentru această operațiune.';

  @override
  String get errorsResursaSolicitataFostGasita =>
      'Resursa solicitată nu a fost găsită.';

  @override
  String get errorsPreaMulteIncercariAsteapta =>
      'Prea multe încercări. Așteaptă puțin și încearcă din nou.';

  @override
  String get errorsServiciulEsteTemporarIndisponibil =>
      'Serviciul este temporar indisponibil. Încearcă din nou mai târziu.';

  @override
  String get analyticsIanuarie => 'Ianuarie';

  @override
  String get analyticsFebruarie => 'Februarie';

  @override
  String get analyticsMartie => 'Martie';

  @override
  String get analyticsAprilie => 'Aprilie';

  @override
  String get analyticsMai => 'Mai';

  @override
  String get analyticsIunie => 'Iunie';

  @override
  String get analyticsIulie => 'Iulie';

  @override
  String get analyticsAugust => 'August';

  @override
  String get analyticsSeptembrie => 'Septembrie';

  @override
  String get analyticsOctombrie => 'Octombrie';

  @override
  String get analyticsNoiembrie => 'Noiembrie';

  @override
  String get analyticsDecembrie => 'Decembrie';

  @override
  String get analyticsSAuPututIncarca => 'Nu s-au putut încărca statisticile.';

  @override
  String get analyticsSAuPututIncarca2 => 'Nu s-au putut încărca statisticile.';

  @override
  String get analyticsStatisticiCheltuieli => 'Statistici cheltuieli';

  @override
  String get analyticsLunaAnterioara => 'Luna anterioară';

  @override
  String get analyticsLunaUrmatoare => 'Luna următoare';

  @override
  String analyticsTotalCheltuit(Object month) {
    return 'TOTAL CHELTUIT ÎN $month';
  }

  @override
  String analyticsCategorieTop(Object topCategory) {
    return 'Categorie top: $topCategory';
  }

  @override
  String analyticsPlati(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plăți',
      few: '$count plăți',
      one: '$count plată',
    );
    return '$_temp0';
  }

  @override
  String get analyticsDistributieCategorii => 'DISTRIBUȚIE PE CATEGORII';

  @override
  String get analyticsNicioCheltuialaAceastaLuna =>
      'Nicio cheltuială în această lună';

  @override
  String get loginLungimeaNumaruluiEsteValida =>
      'Lungimea numărului nu este validă';

  @override
  String get loginNumarulTelefonApartineUnui =>
      'Numărul de telefon nu aparține unui client';

  @override
  String loginEroareComunicareaServerulCod(Object statusCode) {
    return 'Eroare la comunicarea cu serverul (cod: $statusCode)';
  }

  @override
  String get loginPotiConectaServerVerifica =>
      'Nu te poți conecta la server. Verifică conexiunea la internet';

  @override
  String get loginIntroduNumarulTelefon => 'Introdu numărul de telefon';

  @override
  String get loginNumarulTelefonEsteValid => 'Numărul de telefon nu este valid';

  @override
  String get loginConectare => 'Conectare';

  @override
  String get loginRugamSaIntroduciNumarul =>
      'Te rugăm să introduci numărul declarat băncii';

  @override
  String get commonNumarTelefon => 'Număr de telefon';

  @override
  String get commonIncarcare => 'Încărcare...';

  @override
  String get commonConfirma => 'Confirmă';

  @override
  String get pinPinIncorect => 'PIN incorect';

  @override
  String get pinEroareSetareaPinUlui => 'Eroare la setarea PIN-ului';

  @override
  String get pinConfirmaPinUl => 'Confirmă PIN-ul';

  @override
  String get pinSeteazaPinUl => 'Setează PIN-ul';

  @override
  String get pinIntroduPinUl => 'Introdu PIN-ul';

  @override
  String get pinReintroducetiCodulPinConfirmare =>
      'Reintroduceți codul PIN pentru confirmare';

  @override
  String get pinAlegetiCodPin6 => 'Alegeți un cod PIN din 6 cifre';

  @override
  String get pinContinuaRugamSaIntroduci =>
      'Pentru a continua, te rugăm să introduci codul tău PIN';

  @override
  String get registerMasculin => 'Masculin';

  @override
  String get registerNecasatorit => 'Necăsătorit';

  @override
  String get registerContulExistaDeja => 'Contul există deja';

  @override
  String get registerEroareInregistrare => 'Eroare la înregistrare';

  @override
  String get registerVerificareNumar => 'Verificare număr';

  @override
  String get registerIntroduNumarulTauTelefon =>
      'Introdu numărul tău de telefon';

  @override
  String get registerDatePersonale => 'Date personale';

  @override
  String get registerCompleteazaDateleTale => 'Completează datele tale';

  @override
  String get registerPrenume => 'Prenume';

  @override
  String get registerIntroduPrenumele => 'Introdu prenumele';

  @override
  String get registerNume => 'Nume';

  @override
  String get registerIntroduNumele => 'Introdu numele';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerEmailExempluRo => 'email@exemplu.ro';

  @override
  String get registerFeminin => 'Feminin';

  @override
  String get registerGen => 'Gen';

  @override
  String get registerCnp => 'CNP';

  @override
  String get registerCasatorit => 'Căsătorit';

  @override
  String get registerDivortat => 'Divorțat';

  @override
  String get registerStareCivila => 'Stare civilă';

  @override
  String get registerConfirmareDate => 'Confirmare date';

  @override
  String get registerVerificaDateleIntroduse => 'Verifică datele introduse';

  @override
  String get registerTelefon => 'Telefon';

  @override
  String get commonDataNasterii => 'Data nașterii';

  @override
  String get registerInregistrare => 'Înregistrare';

  @override
  String get commonInapoi => 'Înapoi';

  @override
  String get registerContinua => 'Continuă';

  @override
  String get registerConfirmaInregistrarea => 'Confirmă înregistrarea';

  @override
  String get twoFactorEroareTrimitereaCodului => 'Eroare la trimiterea codului';

  @override
  String get twoFactorTimpulVerificareExpiratRugam =>
      'Timpul pentru verificare a expirat. Te rugăm să reîncepi procesul.';

  @override
  String get twoFactorVerificareReusitaVeiFi =>
      'Verificare reușită! Vei fi redirecționat...';

  @override
  String get twoFactorCodInvalidDepasitNumarul =>
      'Cod invalid sau ai depășit numărul de încercări';

  @override
  String get twoFactorCodVerificareSms6 => 'Cod de verificare din SMS, 6 cifre';

  @override
  String get twoFactorVerificare => 'Verificare';

  @override
  String get twoFactorIntroduCodulVerificare => 'Introdu codul de verificare';

  @override
  String get twoFactorAmTrimisCodVerificare =>
      'Am trimis un cod de verificare la\n';

  @override
  String get twoFactorPrimitCodul => 'Nu ai primit codul? ';

  @override
  String get twoFactorRetrimite => 'Retrimite';

  @override
  String twoFactorRetrimiteS(Object cooldownSeconds) {
    return 'Retrimite (${cooldownSeconds}s)';
  }

  @override
  String get cardSettingsBlocheziTemporarCardul => 'Blochezi temporar cardul?';

  @override
  String cardSettingsPlatileCardulRetragerileAtm(Object last4) {
    return 'Plățile cu cardul •••• $last4 și retragerile de la ATM vor fi refuzate până îl deblochezi. Îl poți debloca oricând din această pagină.';
  }

  @override
  String get cardSettingsBlocheaza => 'Blochează';

  @override
  String get cardSettingsCardulFostBlocatTemporar =>
      'Cardul a fost blocat temporar';

  @override
  String get cardSettingsCardulFostDeblocatSucces =>
      'Cardul a fost deblocat cu succes';

  @override
  String get cardSettingsStareaCarduluiPututFi =>
      'Starea cardului nu a putut fi modificată.';

  @override
  String cardSettingsNouaLimitaFostSalvata(Object spendingLimit) {
    return 'Noua limită ($spendingLimit) a fost salvată cu succes!';
  }

  @override
  String get cardSettingsLimitaPututFiSalvata =>
      'Limita nu a putut fi salvată.';

  @override
  String get cardSettingsOptiunilePlataAuFost =>
      'Opțiunile de plată au fost actualizate.';

  @override
  String get cardSettingsOptiunileAuPututFi =>
      'Opțiunile nu au putut fi salvate.';

  @override
  String get cardSettingsSetariCard => 'Setări Card';

  @override
  String get cardSettingsBlocat => 'BLOCAT';

  @override
  String get cardSettingsActiv => 'ACTIV';

  @override
  String cardSettingsExp(Object expiryDate) {
    return 'EXP: $expiryDate';
  }

  @override
  String get cardSettingsSecuritateCard => 'SECURITATE CARD';

  @override
  String get cardSettingsBlocareTemporaraCard => 'Blocare temporară card';

  @override
  String get cardSettingsDezactiveazaPlatileRetragerileAtm =>
      'Dezactivează plățile și retragerile ATM instant.';

  @override
  String get cardSettingsLimiteTranzactii => 'LIMITE TRANZACȚII';

  @override
  String get cardSettingsLimitaZilnicaCheltuieli =>
      'Limită zilnică de cheltuieli';

  @override
  String get cardSettingsSalveazaNouaLimita => 'Salvează noua limită';

  @override
  String get cardSettingsOptiuniPlati => 'OPȚIUNI PLĂȚI';

  @override
  String get cardSettingsPlatiOnlineECommerce => 'Plăți online (e-Commerce)';

  @override
  String get cardSettingsPermiteTranzactiiSecurizateInternet =>
      'Permite tranzacții securizate pe internet.';

  @override
  String get cardSettingsPlatiContactlessPos => 'Plăți contactless POS';

  @override
  String get cardSettingsPlatiRapideFaraContact =>
      'Plăți rapide fără contact la magazine.';

  @override
  String get errorUpsCevaFunctionat => 'Ups, ceva nu a funcționat...';

  @override
  String get errorReincearcaAcum => 'Reîncearcă acum';

  @override
  String get errorIncaAvemConexiuneReincercam =>
      'Încă nu avem conexiune. Reîncercăm automat.';

  @override
  String exchangeContInexistent(Object toCurrency) {
    return 'Cont în $toCurrency inexistent';
  }

  @override
  String exchangeCumparaTrebuieSaDeschizi(Object toCurrency) {
    return 'Pentru a cumpăra $toCurrency, trebuie să deschizi mai întâi un sub-cont în această valută.';
  }

  @override
  String get commonInchide => 'Închide';

  @override
  String get exchangeDeschideCont => 'Deschide cont';

  @override
  String get exchangeConfirmaSchimbulValutar => 'Confirmă schimbul valutar';

  @override
  String get exchangePlatesti => 'Plătești:';

  @override
  String get exchangePrimesti => 'Primești:';

  @override
  String get exchangeCursSchimb => 'Curs schimb:';

  @override
  String get exchangeComisionTranzactie => 'Comision tranzacție:';

  @override
  String get exchangeGratuit => 'Gratuit';

  @override
  String get commonAnuleaza => 'Anulează';

  @override
  String get exchangeSchimbulValutarPututFi =>
      'Schimbul valutar nu a putut fi efectuat.';

  @override
  String get exchangeSchimbValutar => 'Schimb valutar';

  @override
  String get exchangeInverseazaValutele => 'Inversează valutele';

  @override
  String get exchangeCursulValutarEsteDisponibil =>
      'Cursul valutar nu este disponibil';

  @override
  String exchangeComision(Object commissionPercent, Object commissionAmount) {
    return 'Comision $commissionPercent: $commissionAmount';
  }

  @override
  String exchangeRataEfectiva1(
    Object fromCurrency,
    Object rateWithCommission,
    Object toCurrency,
  ) {
    return 'Rată efectivă: 1 $fromCurrency = $rateWithCommission $toCurrency';
  }

  @override
  String get exchangeSchimbaValuta => 'Schimbă valuta';

  @override
  String get homeSeIncarcaDateleContului => 'Se încarcă datele contului...';

  @override
  String get homeClientIntbank => 'Client INTBank';

  @override
  String get homeDeconectezi => 'Te deconectezi?';

  @override
  String get homeVaTrebuiSaAutentifici =>
      'Va trebui să te autentifici din nou pentru a folosi aplicația.';

  @override
  String get homeDeconecteazaMa => 'Deconectează-mă';

  @override
  String get homeBunVenit => 'Bun venit!';

  @override
  String get homeArataSumele => 'Arată sumele';

  @override
  String get homeAscundeSumele => 'Ascunde sumele';

  @override
  String get homeNotificari => 'Notificări';

  @override
  String get homeDeconectare => 'Deconectare';

  @override
  String get homeCarduriDisponibile => 'Nu ai carduri disponibile';

  @override
  String homeCard(Object currentCardIndex, Object cardList) {
    return 'Card $currentCardIndex din $cardList';
  }

  @override
  String get homeCardulAnterior => 'Cardul anterior';

  @override
  String get homeCardulUrmator => 'Cardul următor';

  @override
  String get homeSetariCard => 'Setări card';

  @override
  String get homeTitular => 'TITULAR';

  @override
  String get homeExpira => 'EXPIRĂ';

  @override
  String get homePan => 'PAN  ';

  @override
  String get homeCvv => 'CVV';

  @override
  String homeExp(Object expiry) {
    return 'EXP: $expiry';
  }

  @override
  String get homeAscundeDateleCardului => 'Ascunde datele cardului';

  @override
  String get homeAscunde => 'Ascunde';

  @override
  String get commonSoldDisponibil => 'Sold disponibil';

  @override
  String get homeArataSoldul => 'Arată soldul';

  @override
  String get homeAscundeSoldul => 'Ascunde soldul';

  @override
  String get homeValuta => 'Valută';

  @override
  String get homeExtras => 'Extras';

  @override
  String get homeDetaliiCont => 'Detalii cont';

  @override
  String get commonTransfer => 'Transfer';

  @override
  String get homeIstoric => 'Istoric';

  @override
  String get homeSchimb => 'Schimb';

  @override
  String get homeStatistici => 'Statistici';

  @override
  String get homeSeifuriRoundUp => 'Seifuri de economii';

  @override
  String get homeNou => 'NOU';

  @override
  String get homeEconomisesteAutomatMaruntisulTranzactiilor =>
      'Pune bani deoparte pentru obiectivele tale.';

  @override
  String get homeCursValutar => 'Curs valutar';

  @override
  String get homeSeIncarca => 'Se încarcă...';

  @override
  String get homeTranzactiiRecente => 'Tranzacții recente';

  @override
  String get homeVeziToate => 'Vezi toate';

  @override
  String get homeExistaTranzactiiRecente => 'Nu există tranzacții recente';

  @override
  String homeNecitite(Object tooltip, Object badgeCount) {
    return '$tooltip, $badgeCount necitite';
  }

  @override
  String get accountDetailsDetaliiContCurent => 'Detalii cont curent';

  @override
  String accountDetailsContPrincipal(Object currency) {
    return 'Cont principal · $currency';
  }

  @override
  String get accountDetailsContIban => 'CONT IBAN';

  @override
  String get accountDetailsCopiazaIbanUl => 'Copiază IBAN-ul';

  @override
  String get accountDetailsIbanUlFostCopiat =>
      'IBAN-ul a fost copiat în clipboard';

  @override
  String get accountDetailsTitularCont => 'Titular cont';

  @override
  String get accountDetailsCodBicSwift => 'Cod BIC / SWIFT';

  @override
  String get commonBanca => 'Banca';

  @override
  String get accountDetailsIntbankSRomania => 'INTBank S.A. România';

  @override
  String get accountDetailsMonedaCont => 'Monedă cont';

  @override
  String accountDetailsDateContIntbankTitular(Object holderName, Object iban) {
    return 'Date cont INTBank:\nTitular: $holderName\nIBAN: $iban\nBIC/SWIFT: INTBROBUXXX\nBanca: INTBank România';
  }

  @override
  String get accountDetailsToateDateleContuluiAu =>
      'Toate datele contului au fost copiate pentru partajare';

  @override
  String get accountDetailsCopiazaDateleTransfer =>
      'Copiază datele pentru transfer';

  @override
  String commonCopiaza(Object label) {
    return 'Copiază $label';
  }

  @override
  String accountDetailsCopiat(Object label) {
    return '$label copiat';
  }

  @override
  String get openCurrencyEuro => 'Euro';

  @override
  String get openCurrencyContCurentEuroPlati =>
      'Cont curent în Euro pentru plăți SEPA';

  @override
  String get openCurrencyDolarAmerican => 'Dolar American';

  @override
  String get openCurrencyContCurentUsdTransferuri =>
      'Cont curent în USD pentru transferuri internaționale';

  @override
  String get openCurrencyLiraSterlina => 'Liră sterlină';

  @override
  String get openCurrencyContCurentGbpPlati =>
      'Cont curent în GBP pentru plăți în Regatul Unit';

  @override
  String openCurrencyContulTauFostDeschis(Object selectedCurrency) {
    return 'Contul tău în $selectedCurrency a fost deschis cu succes!';
  }

  @override
  String get openCurrencyContulPututFiDeschis =>
      'Contul nu a putut fi deschis.';

  @override
  String get openCurrencyDeschideContValutar => 'Deschide cont valutar';

  @override
  String get openCurrencyAlegeMonedaDoritaSe =>
      'Alege moneda dorită. Se va genera instant un IBAN unic fără comisioane de administrare.';

  @override
  String get openCurrencyDeschide => 'Deschide';

  @override
  String get notificationsTranzactii => 'Tranzacții';

  @override
  String get notificationsSecuritate => 'Securitate';

  @override
  String get notificationsCentruNotificari => 'Centru Notificări';

  @override
  String get notificationsMarcheazaCitite => 'Marchează citite';

  @override
  String get notificationsNicioNotificareDisponibila =>
      'Nicio notificare disponibilă';

  @override
  String get notificationsNotificare => 'Notificare';

  @override
  String get approvalVerificareCurs => 'Verificare în curs';

  @override
  String get approvalOperatorVerificaDateleTale =>
      'Un operator verifică datele tale în acest moment';

  @override
  String get approvalAprobareCatevaMomente => 'Aprobare în câteva momente...';

  @override
  String get approvalContVerificatSucces => 'Cont verificat cu succes!';

  @override
  String get approvalDateleTaleAuFost =>
      'Datele tale au fost aprobate.\nVei fi redirecționat în 5 secunde.';

  @override
  String get approvalVerificareCompleta => 'Verificare completă';

  @override
  String get tosEroareVerificareaTos => 'Eroare la verificarea TOS';

  @override
  String get tosEroareActualizareaTos => 'Eroare la actualizarea TOS';

  @override
  String get tosEroareVerificareaContului => 'Eroare la verificarea contului';

  @override
  String get tosSePoateConectaServer => 'Nu se poate conecta la server';

  @override
  String get tosToateConturileDeschiseInt =>
      'Toate conturile deschise la INTBank trebuie să fie înregistrate cu date reale și corecte.';

  @override
  String get tosFiecareClientPoateDetine =>
      'Fiecare client poate deține un singur cont personal la INTBank.';

  @override
  String get tosConturileInactiveMaiMult =>
      'Conturile inactive mai mult de 12 luni pot fi suspendate temporar.';

  @override
  String get tosClientiiMinoriNecesitaConsimtamantul =>
      'Clienții minori necesită consimțământul părinților sau tutorilor.';

  @override
  String get tosClientulTrebuieSaProtejeze =>
      'Clientul trebuie să protejeze datele de acces și parolele.';

  @override
  String get tosIntBankPoateSolicita =>
      'INTBank poate solicita documente suplimentare pentru verificare.';

  @override
  String get tosTranzactiileEfectuatePrinCont =>
      'Tranzacțiile efectuate prin cont sunt responsabilitatea clientului.';

  @override
  String get tosPartajareaConturilorAltePersoane =>
      'Partajarea conturilor cu alte persoane este strict interzisă.';

  @override
  String get tosClientulTrebuieSaAccepte =>
      'Clientul trebuie să accepte acești termeni pentru deschiderea contului.';

  @override
  String get tosConturileNeregulatePotFi =>
      'Conturile neregulate pot fi închise de INTBank fără notificare prealabilă.';

  @override
  String get tosClientulTrebuieSaRespecte =>
      'Clientul trebuie să respecte limitele de tranzacționare și regulile băncii.';

  @override
  String get tosModificareaDatelorPersonaleTrebuie =>
      'Modificarea datelor personale trebuie raportată imediat la INTBank.';

  @override
  String get tosDateleContuluiTrebuiePastrate =>
      'Datele contului trebuie păstrate confidențiale.';

  @override
  String get tosUtilizareaContuluiActivitatiIlegale =>
      'Utilizarea contului pentru activități ilegale este interzisă.';

  @override
  String get tosIntBankRaspundePierderi =>
      'INTBank nu răspunde pentru pierderi cauzate de neglijența clientului.';

  @override
  String get tosSuspendareaContuluiPoateFi =>
      'Suspendarea contului poate fi efectuată pentru verificări suplimentare.';

  @override
  String get tosAccesulContPoateFi =>
      'Accesul la cont poate fi blocat temporar în caz de risc de securitate.';

  @override
  String get tosClientiiTrebuieSaPastreze =>
      'Clienții trebuie să păstreze confidențialitatea parolelor și codurilor PIN.';

  @override
  String get tosIntBankVaSolicita =>
      'INTBank nu va solicita niciodată parole prin email sau telefon.';

  @override
  String get tosRaportatiImediatOriceActivitate =>
      'Raportați imediat orice activitate suspectă la INTBank.';

  @override
  String get tosDispozitiveleFolositeAccesCont =>
      'Dispozitivele folosite pentru acces la cont trebuie să fie securizate.';

  @override
  String get tosAutentificareaDoiFactori2fa =>
      'Autentificarea cu doi factori (2FA) este recomandată.';

  @override
  String get tosDatelePersonaleSuntProcesate =>
      'Datele personale sunt procesate conform politicii de confidențialitate INTBank.';

  @override
  String get tosEsteInterzisaDistribuireaMalware =>
      'Este interzisă distribuirea de malware sau phishing prin aplicație.';

  @override
  String get tosClientiiTrebuieSaFoloseasca =>
      'Clienții trebuie să folosească doar canalele oficiale INTBank.';

  @override
  String get tosMonitorizareaActivitatiiContuluiSe =>
      'Monitorizarea activității contului se face pentru siguranță.';

  @override
  String get tosIntBankPoateIntroduce =>
      'INTBank poate introduce autentificări suplimentare pentru protecție.';

  @override
  String get tosCazIncalcareSecuritatiiContul =>
      'În caz de încălcare a securității, contul poate fi blocat temporar.';

  @override
  String get tosParoleleTrebuieSaFie =>
      'Parolele trebuie să fie complexe și unice.';

  @override
  String get tosCodurileSecuritateTrebuieDistribuite =>
      'Codurile de securitate nu trebuie distribuite altor persoane.';

  @override
  String get tosDateleSensibileTrebuieStocate =>
      'Datele sensibile nu trebuie stocate pe dispozitive publice.';

  @override
  String get tosRaportareaPierderiiDispozitivuluiPrevine =>
      'Raportarea pierderii dispozitivului previne fraudele.';

  @override
  String get tosIntBankPoateAudita =>
      'INTBank poate audita securitatea conturilor pentru prevenirea fraudei.';

  @override
  String get tosPlatileEfectuatePrinInt =>
      'Plățile efectuate prin INTBank sunt finale și ireversibile fără acordul băncii.';

  @override
  String get tosClientulTrebuieSaVerifice =>
      'Clientul trebuie să verifice detaliile înainte de confirmarea plății.';

  @override
  String get tosTranzactiileInternationaleSuntSupuse =>
      'Tranzacțiile internaționale sunt supuse cursului de schimb valutar.';

  @override
  String get tosIntBankPoateRefuza =>
      'INTBank poate refuza tranzacții suspecte fără notificare.';

  @override
  String get tosClientiiTrebuieSaRespecte =>
      'Clienții trebuie să respecte limitele zilnice și lunare stabilite.';

  @override
  String get tosTaxeleComisioaneleAplicabileSunt =>
      'Taxele și comisioanele aplicabile sunt cele afișate în ghidul tarifar.';

  @override
  String get tosClientulEsteResponsabilPlata =>
      'Clientul este responsabil pentru plata tuturor taxelor asociate contului.';

  @override
  String get tosTranzactiileSumeMariPot =>
      'Tranzacțiile cu sume mari pot fi supuse verificărilor suplimentare.';

  @override
  String get tosPlatileAutomateTrebuieConfigurate =>
      'Plățile automate trebuie configurate corect conform instrucțiunilor INTBank.';

  @override
  String get tosTranzactiileFrauduloaseTrebuieRaportate =>
      'Tranzacțiile frauduloase trebuie raportate imediat.';

  @override
  String get tosDocumenteleSuplimentarePotFi =>
      'Documentele suplimentare pot fi cerute pentru validarea plăților.';

  @override
  String get tosClientulTrebuieSaPastreze =>
      'Clientul trebuie să păstreze dovezi ale plăților efectuate.';

  @override
  String get tosOriceEroareTranzactiePoate =>
      'Orice eroare de tranzacție poate fi investigată conform procedurilor interne.';

  @override
  String get tosIntBankPoateSuspenda =>
      'INTBank poate suspenda tranzacțiile dacă sunt detectate nereguli.';

  @override
  String get tosModificareaDatelorBancareTrebuie =>
      'Modificarea datelor bancare trebuie verificată înainte de transfer.';

  @override
  String get tosIntBankPoateModifica =>
      'INTBank poate modifica termenii și condițiile în orice moment.';

  @override
  String get tosNotificarileOficialeSuntComunicate =>
      'Notificările oficiale sunt comunicate prin aplicație, email sau SMS.';

  @override
  String get tosServiciilePotFiSuspendate =>
      'Serviciile pot fi suspendate temporar pentru mentenanță.';

  @override
  String get tosFunctionalitatileSuplimentarePotFi =>
      'Funcționalitățile suplimentare pot fi introduse fără notificare.';

  @override
  String get tosProcedurileAutentificareSecuritatePot =>
      'Procedurile de autentificare și securitate pot fi actualizate.';

  @override
  String get tosStructuraConturilorLimiteleConditiile =>
      'Structura conturilor, limitele și condițiile pot fi modificate.';

  @override
  String get tosClientiiTrebuieSaFoloseasca2 =>
      'Clienții trebuie să folosească versiuni actualizate ale aplicației.';

  @override
  String get tosAccesulAnumiteFunctionalitatiPoate =>
      'Accesul la anumite funcționalități poate fi limitat pentru neconformitate.';

  @override
  String get tosIntBankPoateSchimba =>
      'INTBank poate schimba taxele și comisioanele percepute.';

  @override
  String get tosActualizarileVorFiAfisate =>
      'Actualizările vor fi afișate și în aplicație.';

  @override
  String get tosLimiteleTranzactionarePotFi =>
      'Limitele de tranzacționare pot fi ajustate.';

  @override
  String get tosClientiiTrebuieSaAccepte =>
      'Clienții trebuie să accepte modificările pentru continuarea serviciilor.';

  @override
  String get tosSchimbarileMajoreVorFi =>
      'Schimbările majore vor fi notificate prin email oficial.';

  @override
  String get tosFunctionalitatilePotFiSuspendate =>
      'Funcționalitățile pot fi suspendate temporar pentru upgrade-uri.';

  @override
  String get tosActualizarileSecuritateSuntObligatorii =>
      'Actualizările de securitate sunt obligatorii pentru toți utilizatorii.';

  @override
  String get tosClientiiTrebuieSaRaporteze =>
      'Clienții trebuie să raporteze pierderea sau furtul dispozitivelor imediat.';

  @override
  String get tosClientulTrebuieSaActualizeze =>
      'Clientul trebuie să actualizeze informațiile personale la schimbarea datelor.';

  @override
  String get tosClientiiTrebuieSaRespecte2 =>
      'Clienții trebuie să respecte legislația locală privind tranzacțiile financiare.';

  @override
  String get tosSePoateFolosiAplicatia =>
      'Nu se poate folosi aplicația pentru scopuri ilegale.';

  @override
  String get tosRespectareaRegulilorPublicitatePromovare =>
      'Respectarea regulilor de publicitate și promovare a serviciilor este obligatorie.';

  @override
  String get tosLitigiilePrivindConturileVor =>
      'Litigiile privind conturile vor fi soluționate conform legislației.';

  @override
  String get tosClientiiSuntResponsabiliToate =>
      'Clienții sunt responsabili pentru toate datele introduse și confidențialitatea acestora.';

  @override
  String get tosIntBankGaranteazaDisponibilitatea =>
      'INTBank nu garantează disponibilitatea neîntreruptă a serviciilor.';

  @override
  String get tosClientulTrebuieSaRespecte2 =>
      'Clientul trebuie să respecte cerințele pentru prevenirea fraudei.';

  @override
  String get tosVerificareaPeriodicaExtraselorCont =>
      'Verificarea periodică a extraselor de cont este responsabilitatea clientului.';

  @override
  String get tosRespectareaLimitelorRetragereTransfer =>
      'Respectarea limitelor de retragere și transfer impuse de INTBank este obligatorie.';

  @override
  String get tosVerificareaCorectitudiniiDatelorAplicatie =>
      'Verificarea corectitudinii datelor în aplicație este responsabilitatea clientului.';

  @override
  String get tosProtejareaDispozitivelorAplicatieiInt =>
      'Protejarea dispozitivelor și a aplicației INTBank este obligatorie.';

  @override
  String get tosEsteInterzisaFolosireaConturilor =>
      'Este interzisă folosirea conturilor pentru activități comerciale fără aprobare.';

  @override
  String get tosRespectareaTermenelorPlataServiciile =>
      'Respectarea termenelor de plată pentru serviciile asociate este responsabilitatea clientului.';

  @override
  String get tosIntBankColecteazaProceseaza =>
      'INTBank colectează și procesează date personale conform legislației.';

  @override
  String get tosClientulTrebuieSaAccepte2 =>
      'Clientul trebuie să accepte politica de confidențialitate INTBank.';

  @override
  String get tosDateleSensibileTrebuieDistribuite =>
      'Datele sensibile nu trebuie distribuite către terți neautorizați.';

  @override
  String get tosClientiiAuDreptulSolicita =>
      'Clienții au dreptul de a solicita ștergerea datelor personale.';

  @override
  String get tosDatelePotFiFolosite =>
      'Datele pot fi folosite pentru servicii personalizate și oferte.';

  @override
  String get tosToateDateleSuntStocate =>
      'Toate datele sunt stocate securizat și criptat.';

  @override
  String get tosClientiiTrebuieSaRaporteze2 =>
      'Clienții trebuie să raporteze accesul neautorizat la date.';

  @override
  String get tosIntBankPoateProcesa =>
      'INTBank poate procesa date anonimizate pentru statistici interne.';

  @override
  String get tosFolosireaDatelorAltorClienti =>
      'Folosirea datelor altor clienți fără consimțământ este interzisă.';

  @override
  String get tosAcceptareaCookieUrilorTermenilor =>
      'Acceptarea cookie-urilor și termenilor de procesare este obligatorie.';

  @override
  String get tosModificarilePoliticiiConfidentialitateVor =>
      'Modificările politicii de confidențialitate vor fi notificate prin aplicație.';

  @override
  String get tosClientiiTrebuieSaAccepte2 =>
      'Clienții trebuie să accepte termenii pentru a continua să folosească aplicația.';

  @override
  String get tosDateleColectateSuntFolosite =>
      'Datele colectate sunt folosite exclusiv în scopuri legale.';

  @override
  String get tosIntBankPoateBloca =>
      'INTBank poate bloca contul în caz de încălcare a politicii de date.';

  @override
  String get tosClientiiTrebuieSaMentina =>
      'Clienții trebuie să mențină informațiile personale actualizate.';

  @override
  String get tosIntBankEsteResponsabila =>
      'INTBank nu este responsabilă pentru pierderi cauzate de erori ale clienților.';

  @override
  String get tosSeGaranteazaDisponibilitateaNeintrerupta =>
      'Nu se garantează disponibilitatea neîntreruptă a serviciilor.';

  @override
  String get tosIntBankRaspundeIntarzieri =>
      'INTBank nu răspunde pentru întârzieri cauzate de terți.';

  @override
  String get tosClientiiSuntResponsabiliProtectia =>
      'Clienții sunt responsabili pentru protecția dispozitivelor și conturilor lor.';

  @override
  String get tosServiciilePotFiSuspendate2 =>
      'Serviciile pot fi suspendate în caz de urgență sau defecțiuni.';

  @override
  String get tosRespectareaInstructiunilorUtilizareEste =>
      'Respectarea instrucțiunilor de utilizare este responsabilitatea clientului.';

  @override
  String get tosIntBankRaspundePierderi2 =>
      'INTBank nu răspunde pentru pierderi cauzate de fraude externe.';

  @override
  String get tosServiciileSuntFurnizateAsa =>
      'Serviciile sunt furnizate așa cum sunt, fără garanții suplimentare.';

  @override
  String get tosIntBankGaranteazaExactitatea =>
      'INTBank nu garantează exactitatea informațiilor terților.';

  @override
  String get tosClientiiTrebuieSaVerifice =>
      'Clienții trebuie să verifice regulat extrasele de cont pentru erori.';

  @override
  String get tosAccesulContPoateFi2 =>
      'Accesul la cont poate fi limitat în caz de risc de securitate.';

  @override
  String get tosClientiiSuntResponsabiliFolosirea =>
      'Clienții sunt responsabili pentru folosirea aplicației conform legii.';

  @override
  String get tosIntBankPoateAjusta =>
      'INTBank poate ajusta termenii de responsabilitate prin notificare.';

  @override
  String get tosClientiiTrebuieSaAccepte3 =>
      'Clienții trebuie să accepte termenii pentru a continua folosirea serviciilor.';

  @override
  String get tosIntBankPoateSuspenda2 =>
      'INTBank poate suspenda sau restricționa conturile care încalcă termenii.';

  @override
  String get tosConturileTrebuieSaRespecte =>
      'Conturile trebuie să respecte politicile fiscale locale.';

  @override
  String get tosIntBankEsteResponsabil =>
      'INTBank nu este responsabil pentru pierderile cauzate de terți.';

  @override
  String get tosClientiiTrebuieSaUtilizeze =>
      'Clienții trebuie să utilizeze doar canalele oficiale INTBank.';

  @override
  String get tosDisputePrivindTranzactiileVor =>
      'Dispute privind tranzacțiile vor fi investigate conform procedurilor interne.';

  @override
  String get tosClientiiTrebuieSaRespecte3 =>
      'Clienții trebuie să respecte cerințele de securitate.';

  @override
  String get tosConturileInactiveNedeclaratePot =>
      'Conturile inactive sau nedeclarate pot fi dezactivate.';

  @override
  String get tosFolosireaAplicatieiImplicaAcordul =>
      'Folosirea aplicației implică acordul față de toate regulile INTBank.';

  @override
  String get tosIntBankPoateIntroduce2 =>
      'INTBank poate introduce noi funcționalități și servicii.';

  @override
  String get tosNerespectareaTermenilorPoateDuce =>
      'Nerespectarea termenilor poate duce la suspendarea contului.';

  @override
  String get tosClientiiTrebuieSaRespecte4 =>
      'Clienții trebuie să respecte toate notificările INTBank.';

  @override
  String get tosModificarileLegislativePotInfluenta =>
      'Modificările legislative pot influența regulile aplicabile.';

  @override
  String get tosClientulTrebuieSaConsulte =>
      'Clientul trebuie să consulte periodic aplicația pentru actualizări.';

  @override
  String get tosIntBankPoateModifica2 =>
      'INTBank poate modifica termenii pentru a proteja clienții.';

  @override
  String get tosClientiiSuntResponsabiliRespectarea =>
      'Clienții sunt responsabili pentru respectarea regulilor aplicației.';

  @override
  String get tosToateTaxeleAplicateContului =>
      'Toate taxele aplicate contului vor fi afișate transparent în aplicație.';

  @override
  String get tosIntBankPoateModifica3 =>
      'INTBank poate modifica comisioanele prin notificare prealabilă.';

  @override
  String get tosTaxeleTranzactiileInternationalePot =>
      'Taxele pentru tranzacțiile internaționale pot varia conform cursului valutar.';

  @override
  String get tosClientulEsteResponsabilPlata2 =>
      'Clientul este responsabil pentru plata tuturor taxelor aferente contului.';

  @override
  String get tosTaxelePotFiPercepute =>
      'Taxele pot fi percepute pentru retrageri, transferuri și servicii adiționale.';

  @override
  String get tosIntBankPoateSuspenda3 =>
      'INTBank poate suspenda contul pentru neplata taxelor aplicabile.';

  @override
  String get tosClientiiTrebuieSaConsulte =>
      'Clienții trebuie să consulte ghidul tarifar actualizat al băncii.';

  @override
  String get tosReduceriPromotiiPotFi =>
      'Reduceri și promoții pot fi aplicate doar conform regulilor INTBank.';

  @override
  String get tosTaxelePerceputeTertiTransferuri =>
      'Taxele percepute de terți pentru transferuri externe sunt responsabilitatea clientului.';

  @override
  String get tosSchimbarileTaxeVorFi =>
      'Schimbările de taxe vor fi comunicate prin aplicație și email.';

  @override
  String get tosComisioaneleServiciiSpecialeSunt =>
      'Comisioanele pentru servicii speciale sunt afișate separat.';

  @override
  String get tosIntBankPoateAjusta2 =>
      'INTBank poate ajusta limitele taxelor în funcție de cont.';

  @override
  String get tosTaxeleSuplimentareTranzactiiUrgente =>
      'Taxele suplimentare pentru tranzacții urgente pot fi percepute.';

  @override
  String get tosClientulTrebuieSaAccepte3 =>
      'Clientul trebuie să accepte taxele pentru continuarea serviciului.';

  @override
  String get tosNeplataTaxelorPoateDuce =>
      'Neplata taxelor poate duce la suspendarea funcționalităților contului.';

  @override
  String get tosIntBankPoateRezilia =>
      'INTBank poate rezilia contul în caz de încălcare a termenilor.';

  @override
  String get tosSuspendareaContuluiPoateFi2 =>
      'Suspendarea contului poate fi temporară sau permanentă.';

  @override
  String get tosClientiiVorFiNotificati =>
      'Clienții vor fi notificați prin aplicație sau email oficial.';

  @override
  String get tosReziliereaContuluiElibereazaClientul =>
      'Rezilierea contului nu eliberează clientul de obligațiile financiare.';

  @override
  String get tosIntBankPoateInchide =>
      'INTBank poate închide contul pentru activități ilegale.';

  @override
  String get tosSuspendareaContuluiSePoate =>
      'Suspendarea contului se poate realiza pentru verificări suplimentare.';

  @override
  String get tosConturileInactiveTermenLung =>
      'Conturile inactive pe termen lung pot fi dezactivate automat.';

  @override
  String get tosReziliereaContuluiAfecteazaTranzactiile =>
      'Rezilierea contului nu afectează tranzacțiile deja efectuate.';

  @override
  String get tosClientiiTrebuieSaCoopereze =>
      'Clienții trebuie să coopereze pentru închiderea contului conform procedurilor.';

  @override
  String get tosIntBankPoateSuspenda4 =>
      'INTBank poate suspenda serviciile în caz de risc de securitate.';

  @override
  String get tosReactivareaContuluiPoateFi =>
      'Reactivarea contului poate fi solicitată doar conform regulilor băncii.';

  @override
  String get tosClientiiTrebuieSaIsi =>
      'Clienții trebuie să își retragă fondurile înainte de închidere.';

  @override
  String get tosOriceLitigiuLegatContul =>
      'Orice litigiu legat de contul suspendat va fi soluționat conform legislației.';

  @override
  String get tosSuspendareaTemporaraPoateFi =>
      'Suspendarea temporară poate fi decisă de banca pentru mentenanță sau upgrade.';

  @override
  String get tosReziliereaContuluiSeRealizeaza =>
      'Rezilierea contului se realizează numai după respectarea tuturor procedurilor.';

  @override
  String get tosTermeniConditii => 'Termeni și Condiții';

  @override
  String get tosSeProceseaza => 'Se procesează...';

  @override
  String get tosSuntAcord => 'Sunt de acord';

  @override
  String get splashSPututRealizaConexiunea =>
      'Nu s-a putut realiza conexiunea cu serverul. Așteptăm conexiunea...';

  @override
  String get statement3Luni => '3 luni';

  @override
  String get statement6Luni => '6 luni';

  @override
  String get statement1An => '1 an';

  @override
  String get statementPersonalizat => 'Personalizat';

  @override
  String get statementSPututIncarcaExtrasul =>
      'Nu s-a putut încărca extrasul de cont.';

  @override
  String statementExtrasulPdfFostGenerat(Object startDate, Object endDate) {
    return 'Extrasul PDF ($startDate - $endDate) a fost generat cu succes!';
  }

  @override
  String get statementPdfUlPututFi => 'PDF-ul nu a putut fi descărcat.';

  @override
  String get statementExtrasCont => 'Extras de cont';

  @override
  String statementPerioada(Object startDate, Object endDate) {
    return 'Perioada: $startDate - $endDate';
  }

  @override
  String get statementSeGenereazaPdf => 'Se generează PDF...';

  @override
  String get statementDescarcaExtrasPdf => 'Descarcă extras PDF';

  @override
  String get statementSoldInitial => 'SOLD INIȚIAL';

  @override
  String get statementSoldFinal => 'SOLD FINAL';

  @override
  String get statementIncasari => 'ÎNCASĂRI (+)';

  @override
  String get statementPlati => 'PLĂȚI (-)';

  @override
  String statementOperatiuni(Object transactions) {
    return 'OPERAȚIUNI ($transactions)';
  }

  @override
  String get statementAtingeTranzactieDetalii =>
      'Atinge o tranzacție pentru detalii';

  @override
  String get statementNicioOperatiuneAceastaPerioada =>
      'Nicio operațiune în această perioadă';

  @override
  String get historyToate => 'Toate';

  @override
  String get historyIntrari => 'Intrări (+)';

  @override
  String get historyIesiri => 'Ieșiri (-)';

  @override
  String get historyLunaCurenta => 'Luna curentă';

  @override
  String get historySPututIncarcaIstoricul =>
      'Nu s-a putut încărca istoricul tranzacțiilor.';

  @override
  String get historyIstoricTranzactii => 'Istoric tranzacții';

  @override
  String get historyCautaComerciantDescriere =>
      'Caută comerciant, descriere...';

  @override
  String historyTotal(Object currency) {
    return 'Total: $currency';
  }

  @override
  String historyTotal2(Object totalSum) {
    return 'Total: $totalSum';
  }

  @override
  String get historyAuFostGasiteTranzactii =>
      'Nu au fost găsite tranzacții care să corespundă căutării.';

  @override
  String get commonTransferBancar => 'Transfer bancar';

  @override
  String get txDetailsDovadaPlata => 'Dovadă de plată';

  @override
  String get txDetailsFinalizata => 'Finalizată';

  @override
  String get commonProcesare => 'În procesare';

  @override
  String get txDetailsDataOra => 'Data & Ora';

  @override
  String get txDetailsReferintaTranzactie => 'Referință tranzacție';

  @override
  String get txDetailsTipOperatiune => 'Tip operațiune';

  @override
  String get txDetailsPlataTransferTrimis => 'Plată / Transfer trimis';

  @override
  String get txDetailsIncasareTransferPrimit => 'Încasare / Transfer primit';

  @override
  String get txDetailsContExpeditorIban => 'Cont expeditor (IBAN)';

  @override
  String get txDetailsContBeneficiarIban => 'Cont beneficiar (IBAN)';

  @override
  String txDetailsTranzactieIntbankSumaData(
    Object trackingId,
    Object signedAmount,
    Object date,
  ) {
    return 'Tranzacție INTBank: $trackingId | Suma: $signedAmount | Data: $date';
  }

  @override
  String get txDetailsDetaliileTranzactieiAuFost =>
      'Detaliile tranzacției au fost copiate';

  @override
  String get txDetailsCopiaza => 'Copiază';

  @override
  String txDetailsFostCopiatClipboard(Object label) {
    return '$label a fost copiat în clipboard';
  }

  @override
  String get scheduledSAuPututIncarca =>
      'Nu s-au putut încărca plățile programate.';

  @override
  String get scheduledPlataProgramataFostAnulata =>
      'Plata programată a fost anulată.';

  @override
  String get scheduledPlataProgramataPututFi =>
      'Plata programată nu a putut fi anulată.';

  @override
  String get scheduledAnuleziPlataRecurenta => 'Anulezi plata recurentă?';

  @override
  String scheduledPlataCatreVaMai(Object amount, Object beneficiary) {
    return 'Plata de $amount către $beneficiary nu va mai fi executată.';
  }

  @override
  String get scheduledAnuleazaPlata => 'Anulează plata';

  @override
  String get scheduledPastreaza => 'Păstrează';

  @override
  String get commonSaptamanal => 'Săptămânal';

  @override
  String get commonLunar => 'Lunar';

  @override
  String get scheduledSinguraData => 'O singură dată';

  @override
  String get scheduledPlatiProgramate => 'Plăți programate';

  @override
  String get scheduledNicioPlataProgramata => 'Nicio plată programată';

  @override
  String get scheduledPotiSetaPlatiRecurente =>
      'Poți seta plăți recurente sau viitoare direct din ecranul de transfer activând opțiunea \"Programare plată\".';

  @override
  String get scheduledBeneficiar => 'Beneficiar';

  @override
  String commonDetalii(Object reason) {
    return 'Detalii: $reason';
  }

  @override
  String scheduledUrmatoarea(Object nextRun) {
    return 'Următoarea: $nextRun';
  }

  @override
  String get receiptPlataProgramata => 'Plată programată';

  @override
  String get receiptTransferEfectuat => 'Transfer efectuat';

  @override
  String get receiptTransferProcesare => 'Transfer în procesare';

  @override
  String get receiptProgramata => 'Programată';

  @override
  String get receiptFinalizat => 'Finalizat';

  @override
  String receiptIntBank(Object title) {
    return 'INTBank - $title';
  }

  @override
  String receiptSuma(Object amount) {
    return 'Sumă: $amount';
  }

  @override
  String receiptBeneficiar(Object beneficiaryName) {
    return 'Beneficiar: $beneficiaryName';
  }

  @override
  String receiptIbanBeneficiar(Object toIban) {
    return 'IBAN beneficiar: $toIban';
  }

  @override
  String receiptData(Object createdAt) {
    return 'Data: $createdAt';
  }

  @override
  String receiptProgramare(Object scheduleSummary) {
    return 'Programare: $scheduleSummary';
  }

  @override
  String receiptIdTranzactie(Object trackingId) {
    return 'ID tranzacție: $trackingId';
  }

  @override
  String receiptCatre(Object beneficiaryName) {
    return 'către $beneficiaryName';
  }

  @override
  String get receiptBancaProceseazaTransferulVei =>
      'Banca procesează transferul. Vei primi o notificare când este finalizat.';

  @override
  String get receiptDetaliileAuFostCopiate => 'Detaliile au fost copiate.';

  @override
  String get receiptCopiazaDetaliile => 'Copiază detaliile';

  @override
  String get receiptGata => 'Gata';

  @override
  String get commonTransferNou => 'Transfer nou';

  @override
  String get receiptStatus => 'Status';

  @override
  String get receiptData2 => 'Data';

  @override
  String get commonProgramare => 'Programare';

  @override
  String get commonContul => 'Din contul';

  @override
  String get receiptCatre2 => 'Către';

  @override
  String get commonDetaliiPlata => 'Detalii plată';

  @override
  String get receiptIdTranzactie2 => 'ID tranzacție';

  @override
  String get transferData => 'O dată';

  @override
  String transferDin(Object frequency, Object scheduledDate) {
    return '$frequency, din $scheduledDate';
  }

  @override
  String get transferEroareTransfer => 'Eroare la transfer';

  @override
  String get transferTransferulPututFiEfectuat =>
      'Transferul nu a putut fi efectuat. Încearcă din nou.';

  @override
  String get transferCompleteazaDateleEfectuaTransferul =>
      'Completează datele pentru a efectua transferul';

  @override
  String get transferDestinatar => 'DESTINATAR';

  @override
  String get transferProgramate => 'Programate';

  @override
  String get transferAgenda => 'Agendă';

  @override
  String get transferIbanDestinatar => 'IBAN destinatar';

  @override
  String get transferNumeBeneficiar => 'Nume beneficiar';

  @override
  String get transferPopescuIon => 'Popescu Ion';

  @override
  String transferSuma(Object currency) {
    return 'Suma ($currency)';
  }

  @override
  String transferDisponibil(Object availableBalance) {
    return 'Disponibil: $availableBalance';
  }

  @override
  String get transferMotivTransfer => 'Motiv transfer';

  @override
  String get transferPlataFacturaRambursareEtc =>
      'Plată factură, Rambursare etc.';

  @override
  String get transferSalveazaDestinatarulAgendaPlati =>
      'Salvează destinatarul în agenda de plăți';

  @override
  String get transferProgramarePlataRecurenta => 'Programare plată / Recurență';

  @override
  String get transferFrecventaExecutie => 'Frecvență execuție';

  @override
  String transferDataExecutiei(Object scheduledDate) {
    return 'Data execuției: $scheduledDate';
  }

  @override
  String get transferSchimbaData => 'Schimbă data';

  @override
  String get transferProgrameazaTransferul => 'Programează transferul';

  @override
  String get transferTransferaAcum => 'Transferă acum';

  @override
  String get transferDisponibil2 => 'Disponibil';

  @override
  String get transferValidationIntroduIbanUlDestinatarului =>
      'Introdu IBAN-ul destinatarului.';

  @override
  String get transferValidationIbanUlIncepeCodul =>
      'IBAN-ul începe cu codul țării și două cifre (ex. RO49).';

  @override
  String get transferValidationIbanUlPoateContine =>
      'IBAN-ul poate conține doar litere și cifre.';

  @override
  String get transferValidationIbanUlAreLungime =>
      'IBAN-ul are o lungime incorectă.';

  @override
  String get transferValidationAcestaEsteContulCare =>
      'Acesta este contul din care plătești. Alege alt destinatar.';

  @override
  String transferValidationIbanRomanescAre24(Object c) {
    return 'Un IBAN românesc are 24 de caractere (ai introdus $c).';
  }

  @override
  String get transferValidationIbanUlEsteValid =>
      'IBAN-ul nu este valid. Verifică dacă ai copiat corect toate caracterele.';

  @override
  String get transferValidationIntroduNumeleBeneficiarului =>
      'Introdu numele beneficiarului.';

  @override
  String get transferValidationNumeleEstePreaScurt => 'Numele este prea scurt.';

  @override
  String transferValidationNumelePoateAveaCel(Object maxNameLength) {
    return 'Numele poate avea cel mult $maxNameLength de caractere.';
  }

  @override
  String get transferValidationNumeleTrebuieSaContina =>
      'Numele trebuie să conțină litere.';

  @override
  String get transferValidationIntroduSumaMaiMare =>
      'Introdu o sumă mai mare de 0.';

  @override
  String transferValidationSoldInsuficientDisponibil(Object available) {
    return 'Sold insuficient. Disponibil: $available.';
  }

  @override
  String get transferValidationDescrieScurtPlataEx =>
      'Descrie pe scurt plata (ex. „Chirie octombrie”).';

  @override
  String get transferValidationDetaliilePlatiiTrebuieSa =>
      'Detaliile plății trebuie să aibă minim 3 caractere.';

  @override
  String transferValidationDetaliilePotAveaCel(Object maxReasonLength) {
    return 'Detaliile pot avea cel mult $maxReasonLength de caractere.';
  }

  @override
  String get beneficiariesBeneficiariSalvati => 'Beneficiari salvați';

  @override
  String beneficiariesContacte(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de contacte',
      few: '$count contacte',
      one: '$count contact',
    );
    return '$_temp0';
  }

  @override
  String get beneficiariesCautaDupaNumeIban => 'Caută după nume sau IBAN...';

  @override
  String get beneficiariesNiciunBeneficiarSalvatInca =>
      'Nu ai niciun beneficiar salvat încă';

  @override
  String get beneficiariesNiciunRezultatGasit => 'Niciun rezultat găsit';

  @override
  String get transferConfirmVerificareTransfer => 'Verificare transfer';

  @override
  String get transferConfirmVerificaDetaliilePlatiiInainte =>
      'Verifică detaliile plății înainte de trimitere';

  @override
  String get transferConfirmSumaTransferat => 'SUMĂ DE TRANSFERAT';

  @override
  String transferConfirmComisionTransferGratuit(Object currency) {
    return 'Comision: $currency • Transfer gratuit';
  }

  @override
  String get transferConfirmDestinatar => 'Destinatar';

  @override
  String get transferConfirmBancaBeneficiar => 'Bancă beneficiar';

  @override
  String get transferConfirmBancaComerciala => 'Bancă Comercială';

  @override
  String get transferConfirmIbanDestinatie => 'IBAN Destinație';

  @override
  String get transferConfirmPlataVaFiExecutata =>
      'Plata va fi executată automat. O poți anula oricând din „Plăți programate”.';

  @override
  String get transferConfirmVerificaIbanUlSuma =>
      'Verifică IBAN-ul și suma. După confirmare, transferul este trimis imediat și nu mai poate fi anulat din aplicație.';

  @override
  String get transferConfirmConfirmaProgramarea => 'Confirmă programarea';

  @override
  String get transferConfirmConfirmaTransferul => 'Confirmă transferul';

  @override
  String get transferConfirmModificaDetaliile => 'Modifică detaliile';

  @override
  String get routerPaginaSolicitataFostGasita =>
      'Pagina solicitată nu a fost găsită. Te redirecționăm către ecranul principal...';

  @override
  String commonSeProceseaza(Object label) {
    return '$label, se procesează';
  }

  @override
  String get commonRenunta => 'Renunță';

  @override
  String get commonPrefixTara => 'Prefix țară';

  @override
  String get commonSelecteazaData => 'Selectează data';

  @override
  String get commonReincearca => 'Reîncearcă';

  @override
  String commonCifreIntroduse(Object length, Object totalDots) {
    return '$length din $totalDots cifre introduse';
  }

  @override
  String commonCifra(Object d) {
    return 'Cifra $d';
  }

  @override
  String get commonStergeUltimaCifra => 'Șterge ultima cifră';

  @override
  String commonPasul(Object currentStep, Object totalSteps) {
    return 'Pasul $currentStep din $totalSteps';
  }

  @override
  String get statement30Zile => '30 zile';

  @override
  String get commonNeselectata => 'neselectată';

  @override
  String analyticsCategoryCount(int count, String percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de tranzacții',
      few: '$count tranzacții',
      one: '$count tranzacție',
    );
    return '$_temp0 • $percent';
  }

  @override
  String historyResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de tranzacții găsite',
      few: '$count tranzacții găsite',
      one: '$count tranzacție găsită',
    );
    return '$_temp0';
  }

  @override
  String get pinEroareAutentificareIncearcaNou =>
      'Eroare la autentificare. Încearcă din nou.';

  @override
  String get pinEroarePotiConectaServer =>
      'Eroare: Nu te poți conecta la server';

  @override
  String get pinPotiConectaServerIncearca =>
      'Nu te poți conecta la server. Încearcă din nou.';

  @override
  String get pinPinUrileCoincid => 'PIN-urile nu coincid';

  @override
  String get registerPotiConectaServerVerifica =>
      'Nu te poți conecta la server. Verifică conexiunea';

  @override
  String get twoFactorEroareObtinereaTokenuluiClient =>
      'Eroare la obținerea tokenului client';

  @override
  String get twoFactorCodulPututFiTrimis =>
      'Codul nu a putut fi trimis. Apasă „Retrimite” și încearcă din nou.';

  @override
  String get twoFactorSesiuneExpirataRugamSa =>
      'Sesiune expirată. Te rugăm să te reconectezi';

  @override
  String exchangeContActiv(Object fromCurrency) {
    return 'Nu ai un cont activ în $fromCurrency.';
  }

  @override
  String get exchangeIntroduSumaValidaSchimb =>
      'Introdu o sumă validă pentru schimb';

  @override
  String exchangeFonduriInsuficienteDisponibil(Object available) {
    return 'Fonduri insuficiente! Disponibil: $available';
  }

  @override
  String get exchangeEroareRealizareaSchimbuluiValutar =>
      'Eroare la realizarea schimbului valutar';

  @override
  String get openCurrencyEroareDeschidereaContului =>
      'Eroare la deschiderea contului';

  @override
  String get transferEroareProgramareaPlatii => 'Eroare la programarea plății';

  @override
  String get transferEroareEfectuareaTransferului =>
      'Eroare la efectuarea transferului';

  @override
  String commonTxIncomingSemantics(
    String beneficiary,
    String date,
    String amount,
  ) {
    return 'Încasare: $beneficiary, $date, $amount';
  }

  @override
  String commonTxOutgoingSemantics(
    String beneficiary,
    String date,
    String amount,
  ) {
    return 'Plată: $beneficiary, $date, $amount';
  }

  @override
  String get errorsCodeCurrencyMismatch =>
      'Contul destinatarului are altă monedă. Folosește schimbul valutar sau un cont în aceeași monedă.';

  @override
  String get errorsCodeInsufficientFunds =>
      'Fonduri insuficiente în contul sursă.';

  @override
  String get errorsCodeAccountNotOwned => 'Contul ales nu îți aparține.';

  @override
  String get errorsCodeSameAccount => 'Alege două conturi diferite.';

  @override
  String get errorsCodeUnsupportedPair =>
      'Schimbul între aceste monede nu este disponibil.';

  @override
  String get errorsCodeInvalidAmount =>
      'Suma nu este validă sau este prea mică.';

  @override
  String get scaTitle => 'Confirmă plata';

  @override
  String get scaSubtitle =>
      'Pentru plăți de valoare mare, introdu PIN-ul ca să autorizezi exact această plată.';

  @override
  String get scaCancel => 'Anulează';

  @override
  String scaPinProgress(int entered, int total) {
    return '$entered din $total cifre introduse';
  }

  @override
  String errorsCodeScaPinInvalid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'PIN incorect. Mai ai $count de încercări.',
      few: 'PIN incorect. Mai ai $count încercări.',
      one: 'PIN incorect. Mai ai o încercare.',
    );
    return '$_temp0';
  }

  @override
  String get errorsCodeScaLocked =>
      'PIN-ul este blocat temporar după prea multe încercări. Reîncearcă peste 15 minute.';

  @override
  String get errorsCodeScaChallengeInvalid =>
      'Confirmarea a expirat sau plata s-a schimbat. Trimite plata din nou.';

  @override
  String get transferValidationOnlyIntBank =>
      'Poți trimite bani doar către conturi INTBank (IBAN-uri cu codul INTB).';

  @override
  String get errorsCodeDestinationNotFound =>
      'Nu există niciun cont INTBank cu acest IBAN. Verifică IBAN-ul destinatarului.';

  @override
  String get scheduledStatusFailed => 'Neefectuată';

  @override
  String get scheduledStatusPaused => 'Suspendată';

  @override
  String get scheduledStatusCompleted => 'Efectuată';

  @override
  String scheduledLastError(String reason) {
    return 'Ultima încercare: $reason';
  }

  @override
  String get vaultsTitle => 'Seifuri de economii';

  @override
  String get vaultsTotalSaved => 'Total economisit';

  @override
  String get vaultsNoInterestNote =>
      'Banii din seifuri rămân ai tăi; seifurile nu sunt purtătoare de dobândă.';

  @override
  String get vaultsEmptyTitle => 'Niciun seif încă';

  @override
  String get vaultsEmptyBody =>
      'Pune deoparte bani pentru un obiectiv. Dintr-un seif flexibil îi poți retrage oricând.';

  @override
  String get vaultsNew => 'Seif nou';

  @override
  String get vaultsLoadError => 'Seifurile nu au putut fi încărcate.';

  @override
  String vaultsProgress(String saved, String target) {
    return '$saved din $target';
  }

  @override
  String get vaultsFlexible => 'Flexibil';

  @override
  String vaultsLockedUntil(String date) {
    return 'Blocat până la $date';
  }

  @override
  String vaultsTargetBy(String date) {
    return 'Țintă: $date';
  }

  @override
  String get vaultsGoalReached => 'Obiectiv atins';

  @override
  String get vaultsDeposit => 'Depune';

  @override
  String get vaultsWithdraw => 'Retrage';

  @override
  String vaultsMoreActions(String name) {
    return 'Mai multe acțiuni pentru „$name”';
  }

  @override
  String get vaultsClose => 'Închide seiful';

  @override
  String vaultsCloseTitle(String name) {
    return 'Închizi seiful „$name”?';
  }

  @override
  String vaultsCloseMessage(String amount, String account) {
    return '$amount se mută în contul tău $account. Seiful dispare din listă.';
  }

  @override
  String vaultsDepositTitle(String name) {
    return 'Depune în „$name”';
  }

  @override
  String vaultsWithdrawTitle(String name) {
    return 'Retrage din „$name”';
  }

  @override
  String get vaultsFromAccount => 'Din contul';

  @override
  String get vaultsToAccount => 'În contul';

  @override
  String vaultsAvailable(String amount) {
    return 'Disponibil: $amount';
  }

  @override
  String vaultsAmount(String currency) {
    return 'Suma ($currency)';
  }

  @override
  String get vaultsAmountInvalid => 'Introdu o sumă mai mare de 0.';

  @override
  String vaultsAmountTooHigh(String amount) {
    return 'Suma depășește $amount.';
  }

  @override
  String get vaultsConfirm => 'Confirmă';

  @override
  String vaultsDeposited(String amount, String name) {
    return 'Ai depus $amount în „$name”.';
  }

  @override
  String vaultsWithdrawn(String amount, String name) {
    return 'Ai retras $amount din „$name”.';
  }

  @override
  String vaultsClosed(String name) {
    return 'Seiful „$name” a fost închis.';
  }

  @override
  String vaultsCreated(String name) {
    return 'Seiful „$name” a fost creat.';
  }

  @override
  String get vaultsNameLabel => 'Numele seifului';

  @override
  String get vaultsNameHint => 'ex. Vacanță';

  @override
  String get vaultsNameInvalid =>
      'Introdu un nume de cel mult 60 de caractere.';

  @override
  String vaultsTargetLabel(String currency) {
    return 'Suma țintă ($currency)';
  }

  @override
  String get vaultsTargetDateLabel => 'Data țintă';

  @override
  String get vaultsTargetDateNone => 'Alege o dată (opțional)';

  @override
  String get vaultsTargetDateRequired =>
      'Un seif blocat are nevoie de o dată țintă.';

  @override
  String get vaultsTypeFlexible => 'Flexibil';

  @override
  String get vaultsTypeLocked => 'Blocat';

  @override
  String get vaultsTypeFlexibleHint => 'Poți retrage banii oricând.';

  @override
  String get vaultsTypeLockedHint => 'Banii rămân în seif până la data țintă.';

  @override
  String get vaultsCreate => 'Creează seiful';

  @override
  String vaultsNoAccount(String currency) {
    return 'Ai nevoie de un cont curent în $currency.';
  }

  @override
  String get errorsCodeVaultLocked => 'Seiful este blocat până la data țintă.';

  @override
  String get errorsCodeVaultNotFound => 'Seiful nu mai există.';

  @override
  String get errorsCodeVaultInvalid => 'Verifică datele seifului.';

  @override
  String get exchangeQuoteValidity =>
      'Cursul și sumele sunt garantate 60 de secunde.';

  @override
  String get errorsCodeQuoteExpired =>
      'Oferta de curs a expirat. Încearcă din nou pentru un curs nou.';

  @override
  String get sessionLockedTitle => 'Sesiune încheiată';

  @override
  String get sessionLockedBody =>
      'Pentru siguranța banilor tăi, te-am deconectat după câteva minute fără activitate. Introdu PIN-ul ca să continui.';

  @override
  String get sessionLockedAction => 'Introdu PIN-ul';

  @override
  String get privacyVeilLabel => 'INTBank • Protecția confidențialității';

  @override
  String get navHome => 'Acasă';

  @override
  String get navAccounts => 'Conturi';

  @override
  String get navPayments => 'Plăți';

  @override
  String get navSavings => 'Economii';

  @override
  String get navProfile => 'Profil';

  @override
  String get accountsTitle => 'Conturile mele';

  @override
  String accountsCurrentAccount(String currency) {
    return 'Cont curent $currency';
  }

  @override
  String get accountsEmpty => 'Nu ai încă un cont curent.';

  @override
  String get accountsLoadError => 'Nu am putut încărca conturile.';

  @override
  String get accountsOpenCurrency => 'Deschide un cont în valută';

  @override
  String get accountsCopyIban => 'Copiază IBAN-ul';

  @override
  String get accountsIbanCopied => 'IBAN copiat';

  @override
  String get paymentsTitle => 'Plăți';

  @override
  String get paymentsFrom => 'Plătești din';

  @override
  String get paymentsTransferTitle => 'Transfer către un cont INTBank';

  @override
  String get paymentsTransferBody => 'Instant, către orice IBAN INTBank.';

  @override
  String get paymentsExchangeTitle => 'Schimb valutar';

  @override
  String get paymentsExchangeBody =>
      'Între conturile tale, la un curs garantat 60 de secunde.';

  @override
  String get paymentsScheduledTitle => 'Plăți programate';

  @override
  String get paymentsScheduledBody =>
      'Transferuri care pleacă automat la datele alese.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLoadError => 'Nu am putut încărca datele tale.';

  @override
  String get profilePersonalDetails => 'Date personale';

  @override
  String get profileEmail => 'E-mail';

  @override
  String get profileAddress => 'Adresă';

  @override
  String get profileBirthDate => 'Data nașterii';

  @override
  String get profileDetailsNote =>
      'Pentru a-ți schimba datele personale, contactează INTBank.';

  @override
  String get settingsSecurity => 'Securitate';

  @override
  String get settingsChangePin => 'Schimbă PIN-ul';

  @override
  String get settingsChangePinBody =>
      'PIN-ul cu care intri în aplicație și confirmi plățile.';

  @override
  String get settingsAutoLock => 'Blocare automată';

  @override
  String settingsAutoLockMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'După $minutes de minute fără activitate',
      few: 'După $minutes minute fără activitate',
      one: 'După 1 minut fără activitate',
    );
    return '$_temp0';
  }

  @override
  String get settingsHideAmounts => 'Ascunde sumele';

  @override
  String get settingsHideAmountsBody =>
      'Soldurile și sumele apar ca •••• până le afișezi.';

  @override
  String get settingsPreferences => 'Preferințe';

  @override
  String get settingsAppearance => 'Aspect';

  @override
  String get settingsThemeSystem => 'Ca pe telefon';

  @override
  String get settingsThemeLight => 'Luminos';

  @override
  String get settingsThemeDark => 'Întunecat';

  @override
  String get settingsLanguage => 'Limbă';

  @override
  String get settingsLanguageSystem => 'Limba telefonului';

  @override
  String get settingsAbout => 'Despre';

  @override
  String get settingsVersion => 'Versiune';

  @override
  String get settingsLicences => 'Licențe open-source';

  @override
  String get changePinCurrentTitle => 'Introdu PIN-ul actual';

  @override
  String get changePinCurrentBody =>
      'Pentru siguranță, confirmă mai întâi că ești tu.';

  @override
  String get changePinNewTitle => 'Alege noul PIN';

  @override
  String get changePinNewBody =>
      '6 cifre pe care nu le folosești în altă parte.';

  @override
  String get changePinConfirmTitle => 'Confirmă noul PIN';

  @override
  String get changePinConfirmBody => 'Introdu din nou noul PIN.';

  @override
  String changePinStep(int step) {
    return 'Pasul $step din 3';
  }

  @override
  String get changePinSameAsOld =>
      'Noul PIN trebuie să fie diferit de cel actual.';

  @override
  String get changePinDone => 'PIN-ul a fost schimbat.';

  @override
  String get changePinFailed => 'Nu am putut schimba PIN-ul. Încearcă din nou.';

  @override
  String get dayToday => 'Astăzi';

  @override
  String get dayYesterday => 'Ieri';

  @override
  String get homeGreetMorning => 'Bună dimineața';

  @override
  String get homeGreetAfternoon => 'Bună ziua';

  @override
  String get homeGreetEvening => 'Bună seara';

  @override
  String get transferSavedRecipients => 'Destinatari salvați';

  @override
  String transferToRecipient(String name) {
    return 'Transferă către $name';
  }

  @override
  String get categoryGroceries => 'Alimente și supermarket';

  @override
  String get categoryBills => 'Facturi și utilități';

  @override
  String get categoryRestaurants => 'Restaurante și cafenele';

  @override
  String get categoryTransport => 'Transport și combustibil';

  @override
  String get categoryEntertainment => 'Divertisment și abonamente';

  @override
  String get categoryOther => 'Transferuri și altele';

  @override
  String get categoryIncoming => 'Bani primiți';

  @override
  String get categoryOwnAccounts => 'Între conturile tale';

  @override
  String get txDetailsCategory => 'Categorie';

  @override
  String get exchangeSell => 'Vinzi';

  @override
  String get exchangeBuy => 'Cumperi';

  @override
  String exchangeBalance(String amount) {
    return 'Sold: $amount';
  }

  @override
  String exchangeNoAccount(String currency) {
    return 'Nu ai cont în $currency';
  }

  @override
  String get exchangeAll => 'Tot soldul';

  @override
  String get exchangeNoFee => 'Fără comision';

  @override
  String get exchangeChooseCurrency => 'Alege moneda';

  @override
  String get exchangeEstimateNote => 'Suma exactă o vezi înainte să confirmi.';

  @override
  String get exchangeDone => 'Schimb realizat';

  @override
  String get currencyRon => 'Leu românesc';

  @override
  String get welcomeHeadline => 'Banca ta, mereu cu tine';

  @override
  String get welcomeSubtitle =>
      'Gestionează-ți banii simplu și în siguranță, de oriunde.';

  @override
  String get welcomeFeatureTransfers => 'Transferuri instant';

  @override
  String get welcomeFeatureTransfersBody =>
      'Între conturile INTBank, la orice oră.';

  @override
  String get welcomeFeatureSavings => 'Seifuri de economii';

  @override
  String get welcomeFeatureSavingsBody =>
      'Pune bani deoparte pentru obiectivele tale.';

  @override
  String get welcomeFeatureSecurity => 'Securitate la fiecare pas';

  @override
  String get welcomeFeatureSecurityBody =>
      'PIN, confirmarea plăților și blocare automată.';

  @override
  String get welcomeOpenAccount => 'Deschide un cont';

  @override
  String get welcomeHaveAccount => 'Am deja cont';

  @override
  String get setupErrorTitle => 'Aplicația nu este configurată';

  @override
  String get setupErrorBody =>
      'Această versiune nu are configurată conexiunea securizată cu banca, așa că nu se conectează la server. Instalează o versiune oficială a aplicației.';
}
