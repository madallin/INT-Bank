import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro'),
  ];

  /// Application name
  ///
  /// In ro, this message translates to:
  /// **'INT Bank'**
  String get appTitle;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'A apărut o eroare neașteptată. Încearcă din nou.'**
  String get errorsAparutEroareNeasteptataIncearca;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Serverul nu răspunde. Încearcă din nou în câteva momente.'**
  String get errorsServerulRaspundeIncearcaNou;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu te poți conecta la server. Verifică conexiunea la internet.'**
  String get errorsPotiConectaServerVerifica;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Conexiunea nu este sigură. Operațiunea a fost oprită.'**
  String get errorsConexiuneaEsteSiguraOperatiunea;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Operațiunea a fost anulată.'**
  String get errorsOperatiuneaFostAnulata;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Sesiunea a expirat. Autentifică-te din nou.'**
  String get errorsSesiuneaExpiratAutentificaNou;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu ai permisiunea pentru această operațiune.'**
  String get errorsPermisiuneaAceastaOperatiune;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Resursa solicitată nu a fost găsită.'**
  String get errorsResursaSolicitataFostGasita;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Prea multe încercări. Așteaptă puțin și încearcă din nou.'**
  String get errorsPreaMulteIncercariAsteapta;

  /// Used in error_messages.dart
  ///
  /// In ro, this message translates to:
  /// **'Serviciul este temporar indisponibil. Încearcă din nou mai târziu.'**
  String get errorsServiciulEsteTemporarIndisponibil;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ianuarie'**
  String get analyticsIanuarie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Februarie'**
  String get analyticsFebruarie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Martie'**
  String get analyticsMartie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Aprilie'**
  String get analyticsAprilie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Mai'**
  String get analyticsMai;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Iunie'**
  String get analyticsIunie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Iulie'**
  String get analyticsIulie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'August'**
  String get analyticsAugust;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Septembrie'**
  String get analyticsSeptembrie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Octombrie'**
  String get analyticsOctombrie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Noiembrie'**
  String get analyticsNoiembrie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Decembrie'**
  String get analyticsDecembrie;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-au putut încărca statisticile.'**
  String get analyticsSAuPututIncarca;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-au putut încărca statisticile.'**
  String get analyticsSAuPututIncarca2;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Statistici cheltuieli'**
  String get analyticsStatisticiCheltuieli;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Luna anterioară'**
  String get analyticsLunaAnterioara;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Luna următoare'**
  String get analyticsLunaUrmatoare;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'TOTAL CHELTUIT ÎN {month}'**
  String analyticsTotalCheltuit(Object month);

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Categorie top: {topCategory}'**
  String analyticsCategorieTop(Object topCategory);

  /// Payments in the month (analytics hero)
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} plată} few{{count} plăți} other{{count} de plăți}}'**
  String analyticsPlati(int count);

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'DISTRIBUȚIE PE CATEGORII'**
  String get analyticsDistributieCategorii;

  /// Used in spending_analytics_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nicio cheltuială în această lună'**
  String get analyticsNicioCheltuialaAceastaLuna;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Lungimea numărului nu este validă'**
  String get loginLungimeaNumaruluiEsteValida;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Numărul de telefon nu aparține unui client'**
  String get loginNumarulTelefonApartineUnui;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la comunicarea cu serverul (cod: {statusCode})'**
  String loginEroareComunicareaServerulCod(Object statusCode);

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu te poți conecta la server. Verifică conexiunea la internet'**
  String get loginPotiConectaServerVerifica;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu numărul de telefon'**
  String get loginIntroduNumarulTelefon;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Numărul de telefon nu este valid'**
  String get loginNumarulTelefonEsteValid;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conectare'**
  String get loginConectare;

  /// Used in login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Te rugăm să introduci numărul declarat băncii'**
  String get loginRugamSaIntroduciNumarul;

  /// Used in login_screen.dart, register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Număr de telefon'**
  String get commonNumarTelefon;

  /// Used in login_screen.dart, register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Încărcare...'**
  String get commonIncarcare;

  /// Used in exchange_screen.dart, login_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă'**
  String get commonConfirma;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'PIN incorect'**
  String get pinPinIncorect;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la setarea PIN-ului'**
  String get pinEroareSetareaPinUlui;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă PIN-ul'**
  String get pinConfirmaPinUl;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Setează PIN-ul'**
  String get pinSeteazaPinUl;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu PIN-ul'**
  String get pinIntroduPinUl;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Reintroduceți codul PIN pentru confirmare'**
  String get pinReintroducetiCodulPinConfirmare;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Alegeți un cod PIN din 6 cifre'**
  String get pinAlegetiCodPin6;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Pentru a continua, te rugăm să introduci codul tău PIN'**
  String get pinContinuaRugamSaIntroduci;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Masculin'**
  String get registerMasculin;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Necăsătorit'**
  String get registerNecasatorit;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Contul există deja'**
  String get registerContulExistaDeja;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la înregistrare'**
  String get registerEroareInregistrare;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare număr'**
  String get registerVerificareNumar;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu numărul tău de telefon'**
  String get registerIntroduNumarulTauTelefon;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Date personale'**
  String get registerDatePersonale;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Completează datele tale'**
  String get registerCompleteazaDateleTale;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Prenume'**
  String get registerPrenume;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu prenumele'**
  String get registerIntroduPrenumele;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nume'**
  String get registerNume;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu numele'**
  String get registerIntroduNumele;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Email'**
  String get registerEmail;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'email@exemplu.ro'**
  String get registerEmailExempluRo;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Feminin'**
  String get registerFeminin;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Gen'**
  String get registerGen;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'CNP'**
  String get registerCnp;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Căsătorit'**
  String get registerCasatorit;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Divorțat'**
  String get registerDivortat;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Stare civilă'**
  String get registerStareCivila;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmare date'**
  String get registerConfirmareDate;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verifică datele introduse'**
  String get registerVerificaDateleIntroduse;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Telefon'**
  String get registerTelefon;

  /// Used in date_picker_field.dart, register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Data nașterii'**
  String get commonDataNasterii;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Înregistrare'**
  String get registerInregistrare;

  /// Used in register_screen.dart, simple_app_bar.dart
  ///
  /// In ro, this message translates to:
  /// **'Înapoi'**
  String get commonInapoi;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Continuă'**
  String get registerContinua;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă înregistrarea'**
  String get registerConfirmaInregistrarea;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la trimiterea codului'**
  String get twoFactorEroareTrimitereaCodului;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Timpul pentru verificare a expirat. Te rugăm să reîncepi procesul.'**
  String get twoFactorTimpulVerificareExpiratRugam;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare reușită! Vei fi redirecționat...'**
  String get twoFactorVerificareReusitaVeiFi;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cod invalid sau ai depășit numărul de încercări'**
  String get twoFactorCodInvalidDepasitNumarul;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cod de verificare din SMS, 6 cifre'**
  String get twoFactorCodVerificareSms6;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare'**
  String get twoFactorVerificare;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu codul de verificare'**
  String get twoFactorIntroduCodulVerificare;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Am trimis un cod de verificare la\n'**
  String get twoFactorAmTrimisCodVerificare;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu ai primit codul? '**
  String get twoFactorPrimitCodul;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Retrimite'**
  String get twoFactorRetrimite;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Retrimite ({cooldownSeconds}s)'**
  String twoFactorRetrimiteS(Object cooldownSeconds);

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Blochezi temporar cardul?'**
  String get cardSettingsBlocheziTemporarCardul;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plățile cu cardul •••• {last4} și retragerile de la ATM vor fi refuzate până îl deblochezi. Îl poți debloca oricând din această pagină.'**
  String cardSettingsPlatileCardulRetragerileAtm(Object last4);

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Blochează'**
  String get cardSettingsBlocheaza;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cardul a fost blocat temporar'**
  String get cardSettingsCardulFostBlocatTemporar;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cardul a fost deblocat cu succes'**
  String get cardSettingsCardulFostDeblocatSucces;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Starea cardului nu a putut fi modificată.'**
  String get cardSettingsStareaCarduluiPututFi;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Noua limită ({spendingLimit}) a fost salvată cu succes!'**
  String cardSettingsNouaLimitaFostSalvata(Object spendingLimit);

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Limita nu a putut fi salvată.'**
  String get cardSettingsLimitaPututFiSalvata;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Opțiunile de plată au fost actualizate.'**
  String get cardSettingsOptiunilePlataAuFost;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Opțiunile nu au putut fi salvate.'**
  String get cardSettingsOptiunileAuPututFi;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Setări Card'**
  String get cardSettingsSetariCard;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'BLOCAT'**
  String get cardSettingsBlocat;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'ACTIV'**
  String get cardSettingsActiv;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'EXP: {expiryDate}'**
  String cardSettingsExp(Object expiryDate);

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'SECURITATE CARD'**
  String get cardSettingsSecuritateCard;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Blocare temporară card'**
  String get cardSettingsBlocareTemporaraCard;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Dezactivează plățile și retragerile ATM instant.'**
  String get cardSettingsDezactiveazaPlatileRetragerileAtm;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'LIMITE TRANZACȚII'**
  String get cardSettingsLimiteTranzactii;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Limită zilnică de cheltuieli'**
  String get cardSettingsLimitaZilnicaCheltuieli;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Salvează noua limită'**
  String get cardSettingsSalveazaNouaLimita;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'OPȚIUNI PLĂȚI'**
  String get cardSettingsOptiuniPlati;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plăți online (e-Commerce)'**
  String get cardSettingsPlatiOnlineECommerce;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Permite tranzacții securizate pe internet.'**
  String get cardSettingsPermiteTranzactiiSecurizateInternet;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plăți contactless POS'**
  String get cardSettingsPlatiContactlessPos;

  /// Used in card_settings_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plăți rapide fără contact la magazine.'**
  String get cardSettingsPlatiRapideFaraContact;

  /// Used in error_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ups, ceva nu a funcționat...'**
  String get errorUpsCevaFunctionat;

  /// Used in error_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Reîncearcă acum'**
  String get errorReincearcaAcum;

  /// Used in error_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Încă nu avem conexiune. Reîncercăm automat.'**
  String get errorIncaAvemConexiuneReincercam;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont în {toCurrency} inexistent'**
  String exchangeContInexistent(Object toCurrency);

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Pentru a cumpăra {toCurrency}, trebuie să deschizi mai întâi un sub-cont în această valută.'**
  String exchangeCumparaTrebuieSaDeschizi(Object toCurrency);

  /// Used in exchange_screen.dart, transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Închide'**
  String get commonInchide;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Deschide cont'**
  String get exchangeDeschideCont;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă schimbul valutar'**
  String get exchangeConfirmaSchimbulValutar;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plătești:'**
  String get exchangePlatesti;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Primești:'**
  String get exchangePrimesti;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Curs schimb:'**
  String get exchangeCursSchimb;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Comision tranzacție:'**
  String get exchangeComisionTranzactie;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Gratuit'**
  String get exchangeGratuit;

  /// Used in exchange_screen.dart, open_currency_account_dialog.dart, scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Anulează'**
  String get commonAnuleaza;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimb valutar realizat cu succes!'**
  String get exchangeSchimbValutarRealizatSucces;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbul valutar nu a putut fi efectuat.'**
  String get exchangeSchimbulValutarPututFi;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimb valutar'**
  String get exchangeSchimbValutar;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbă între diferite valute la cursul zilei'**
  String get exchangeSchimbaIntreDiferiteValute;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Din valuta'**
  String get exchangeValuta;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Inversează valutele'**
  String get exchangeInverseazaValutele;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'În valuta'**
  String get exchangeValuta2;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cursul valutar nu este disponibil'**
  String get exchangeCursulValutarEsteDisponibil;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Comision {commissionPercent}: {commissionAmount}'**
  String exchangeComision(Object commissionPercent, Object commissionAmount);

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Rată efectivă: 1 {fromCurrency} = {rateWithCommission} {toCurrency}'**
  String exchangeRataEfectiva1(
    Object fromCurrency,
    Object rateWithCommission,
    Object toCurrency,
  );

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbă valuta'**
  String get exchangeSchimbaValuta;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Se încarcă datele contului...'**
  String get homeSeIncarcaDateleContului;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Client INTBank'**
  String get homeClientIntbank;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Te deconectezi?'**
  String get homeDeconectezi;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Va trebui să te autentifici din nou pentru a folosi aplicația.'**
  String get homeVaTrebuiSaAutentifici;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Deconectează-mă'**
  String get homeDeconecteazaMa;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Bun venit!'**
  String get homeBunVenit;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Arată sumele'**
  String get homeArataSumele;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ascunde sumele'**
  String get homeAscundeSumele;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Notificări'**
  String get homeNotificari;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Deconectare'**
  String get homeDeconectare;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu ai carduri disponibile'**
  String get homeCarduriDisponibile;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Card {currentCardIndex} din {cardList}'**
  String homeCard(Object currentCardIndex, Object cardList);

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cardul anterior'**
  String get homeCardulAnterior;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cardul următor'**
  String get homeCardulUrmator;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Setări card'**
  String get homeSetariCard;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'TITULAR'**
  String get homeTitular;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'EXPIRĂ'**
  String get homeExpira;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'PAN  '**
  String get homePan;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'CVV'**
  String get homeCvv;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'EXP: {expiry}'**
  String homeExp(Object expiry);

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ascunde datele cardului'**
  String get homeAscundeDateleCardului;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ascunde'**
  String get homeAscunde;

  /// Used in account_details_bottom_sheet.dart, home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Sold disponibil'**
  String get commonSoldDisponibil;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Arată soldul'**
  String get homeArataSoldul;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ascunde soldul'**
  String get homeAscundeSoldul;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Valută'**
  String get homeValuta;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Extras'**
  String get homeExtras;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Detalii cont'**
  String get homeDetaliiCont;

  /// Used in home_screen.dart, statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transfer'**
  String get commonTransfer;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Istoric'**
  String get homeIstoric;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimb'**
  String get homeSchimb;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Statistici'**
  String get homeStatistici;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Seifuri & Round-Up'**
  String get homeSeifuriRoundUp;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'NOU'**
  String get homeNou;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Economisește automat din mărunțișul tranzacțiilor.'**
  String get homeEconomisesteAutomatMaruntisulTranzactiilor;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Curs valutar'**
  String get homeCursValutar;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Se încarcă...'**
  String get homeSeIncarca;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacții recente'**
  String get homeTranzactiiRecente;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Vezi toate'**
  String get homeVeziToate;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu există tranzacții recente'**
  String get homeExistaTranzactiiRecente;

  /// Used in home_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'{tooltip}, {badgeCount} necitite'**
  String homeNecitite(Object tooltip, Object badgeCount);

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Detalii cont curent'**
  String get accountDetailsDetaliiContCurent;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont principal · {currency}'**
  String accountDetailsContPrincipal(Object currency);

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'CONT IBAN'**
  String get accountDetailsContIban;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Copiază IBAN-ul'**
  String get accountDetailsCopiazaIbanUl;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN-ul a fost copiat în clipboard'**
  String get accountDetailsIbanUlFostCopiat;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Titular cont'**
  String get accountDetailsTitularCont;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Cod BIC / SWIFT'**
  String get accountDetailsCodBicSwift;

  /// Used in account_details_bottom_sheet.dart, transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Banca'**
  String get commonBanca;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'INTBank S.A. România'**
  String get accountDetailsIntbankSRomania;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Monedă cont'**
  String get accountDetailsMonedaCont;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Date cont INTBank:\nTitular: {holderName}\nIBAN: {iban}\nBIC/SWIFT: INTBROBUXXX\nBanca: INTBank România'**
  String accountDetailsDateContIntbankTitular(Object holderName, Object iban);

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Toate datele contului au fost copiate pentru partajare'**
  String get accountDetailsToateDateleContuluiAu;

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Copiază datele pentru transfer'**
  String get accountDetailsCopiazaDateleTransfer;

  /// Used in account_details_bottom_sheet.dart, transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Copiază {label}'**
  String commonCopiaza(Object label);

  /// Used in account_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'{label} copiat'**
  String accountDetailsCopiat(Object label);

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Euro'**
  String get openCurrencyEuro;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont curent în Euro pentru plăți SEPA'**
  String get openCurrencyContCurentEuroPlati;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Dolar American'**
  String get openCurrencyDolarAmerican;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont curent în USD pentru transferuri internaționale'**
  String get openCurrencyContCurentUsdTransferuri;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Liră sterlină'**
  String get openCurrencyLiraSterlina;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont curent în GBP pentru plăți în Regatul Unit'**
  String get openCurrencyContCurentGbpPlati;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Contul tău în {selectedCurrency} a fost deschis cu succes!'**
  String openCurrencyContulTauFostDeschis(Object selectedCurrency);

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Contul nu a putut fi deschis.'**
  String get openCurrencyContulPututFiDeschis;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Deschide cont valutar'**
  String get openCurrencyDeschideContValutar;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Alege moneda dorită. Se va genera instant un IBAN unic fără comisioane de administrare.'**
  String get openCurrencyAlegeMonedaDoritaSe;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Deschide'**
  String get openCurrencyDeschide;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacții'**
  String get notificationsTranzactii;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Securitate'**
  String get notificationsSecuritate;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Centru Notificări'**
  String get notificationsCentruNotificari;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Marchează citite'**
  String get notificationsMarcheazaCitite;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Nicio notificare disponibilă'**
  String get notificationsNicioNotificareDisponibila;

  /// Used in notification_center_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Notificare'**
  String get notificationsNotificare;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare în curs'**
  String get approvalVerificareCurs;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Un operator verifică datele tale în acest moment'**
  String get approvalOperatorVerificaDateleTale;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Aprobare în câteva momente...'**
  String get approvalAprobareCatevaMomente;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont verificat cu succes!'**
  String get approvalContVerificatSucces;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele tale au fost aprobate.\nVei fi redirecționat în 5 secunde.'**
  String get approvalDateleTaleAuFost;

  /// Used in approval_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare completă'**
  String get approvalVerificareCompleta;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la verificarea TOS'**
  String get tosEroareVerificareaTos;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la actualizarea TOS'**
  String get tosEroareActualizareaTos;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la verificarea contului'**
  String get tosEroareVerificareaContului;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu se poate conecta la server'**
  String get tosSePoateConectaServer;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Toate conturile deschise la INT Bank trebuie să fie înregistrate cu date reale și corecte.'**
  String get tosToateConturileDeschiseInt;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Fiecare client poate deține un singur cont personal la INT Bank.'**
  String get tosFiecareClientPoateDetine;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conturile inactive mai mult de 12 luni pot fi suspendate temporar.'**
  String get tosConturileInactiveMaiMult;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții minori necesită consimțământul părinților sau tutorilor.'**
  String get tosClientiiMinoriNecesitaConsimtamantul;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să protejeze datele de acces și parolele.'**
  String get tosClientulTrebuieSaProtejeze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate solicita documente suplimentare pentru verificare.'**
  String get tosIntBankPoateSolicita;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacțiile efectuate prin cont sunt responsabilitatea clientului.'**
  String get tosTranzactiileEfectuatePrinCont;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Partajarea conturilor cu alte persoane este strict interzisă.'**
  String get tosPartajareaConturilorAltePersoane;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să accepte acești termeni pentru deschiderea contului.'**
  String get tosClientulTrebuieSaAccepte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conturile neregulate pot fi închise de INT Bank fără notificare prealabilă.'**
  String get tosConturileNeregulatePotFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să respecte limitele de tranzacționare și regulile băncii.'**
  String get tosClientulTrebuieSaRespecte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Modificarea datelor personale trebuie raportată imediat la INT Bank.'**
  String get tosModificareaDatelorPersonaleTrebuie;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele contului trebuie păstrate confidențiale.'**
  String get tosDateleContuluiTrebuiePastrate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Utilizarea contului pentru activități ilegale este interzisă.'**
  String get tosUtilizareaContuluiActivitatiIlegale;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu răspunde pentru pierderi cauzate de neglijența clientului.'**
  String get tosIntBankRaspundePierderi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Suspendarea contului poate fi efectuată pentru verificări suplimentare.'**
  String get tosSuspendareaContuluiPoateFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Accesul la cont poate fi blocat temporar în caz de risc de securitate.'**
  String get tosAccesulContPoateFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să păstreze confidențialitatea parolelor și codurilor PIN.'**
  String get tosClientiiTrebuieSaPastreze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu va solicita niciodată parole prin email sau telefon.'**
  String get tosIntBankVaSolicita;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Raportați imediat orice activitate suspectă la INT Bank.'**
  String get tosRaportatiImediatOriceActivitate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Dispozitivele folosite pentru acces la cont trebuie să fie securizate.'**
  String get tosDispozitiveleFolositeAccesCont;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Autentificarea cu doi factori (2FA) este recomandată.'**
  String get tosAutentificareaDoiFactori2fa;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele personale sunt procesate conform politicii de confidențialitate INT Bank.'**
  String get tosDatelePersonaleSuntProcesate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Este interzisă distribuirea de malware sau phishing prin aplicație.'**
  String get tosEsteInterzisaDistribuireaMalware;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să folosească doar canalele oficiale INT Bank.'**
  String get tosClientiiTrebuieSaFoloseasca;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Monitorizarea activității contului se face pentru siguranță.'**
  String get tosMonitorizareaActivitatiiContuluiSe;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate introduce autentificări suplimentare pentru protecție.'**
  String get tosIntBankPoateIntroduce;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'În caz de încălcare a securității, contul poate fi blocat temporar.'**
  String get tosCazIncalcareSecuritatiiContul;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Parolele trebuie să fie complexe și unice.'**
  String get tosParoleleTrebuieSaFie;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Codurile de securitate nu trebuie distribuite altor persoane.'**
  String get tosCodurileSecuritateTrebuieDistribuite;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele sensibile nu trebuie stocate pe dispozitive publice.'**
  String get tosDateleSensibileTrebuieStocate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Raportarea pierderii dispozitivului previne fraudele.'**
  String get tosRaportareaPierderiiDispozitivuluiPrevine;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate audita securitatea conturilor pentru prevenirea fraudei.'**
  String get tosIntBankPoateAudita;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plățile efectuate prin INT Bank sunt finale și ireversibile fără acordul băncii.'**
  String get tosPlatileEfectuatePrinInt;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să verifice detaliile înainte de confirmarea plății.'**
  String get tosClientulTrebuieSaVerifice;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacțiile internaționale sunt supuse cursului de schimb valutar.'**
  String get tosTranzactiileInternationaleSuntSupuse;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate refuza tranzacții suspecte fără notificare.'**
  String get tosIntBankPoateRefuza;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să respecte limitele zilnice și lunare stabilite.'**
  String get tosClientiiTrebuieSaRespecte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Taxele și comisioanele aplicabile sunt cele afișate în ghidul tarifar.'**
  String get tosTaxeleComisioaneleAplicabileSunt;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul este responsabil pentru plata tuturor taxelor asociate contului.'**
  String get tosClientulEsteResponsabilPlata;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacțiile cu sume mari pot fi supuse verificărilor suplimentare.'**
  String get tosTranzactiileSumeMariPot;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plățile automate trebuie configurate corect conform instrucțiunilor INT Bank.'**
  String get tosPlatileAutomateTrebuieConfigurate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacțiile frauduloase trebuie raportate imediat.'**
  String get tosTranzactiileFrauduloaseTrebuieRaportate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Documentele suplimentare pot fi cerute pentru validarea plăților.'**
  String get tosDocumenteleSuplimentarePotFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să păstreze dovezi ale plăților efectuate.'**
  String get tosClientulTrebuieSaPastreze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Orice eroare de tranzacție poate fi investigată conform procedurilor interne.'**
  String get tosOriceEroareTranzactiePoate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate suspenda tranzacțiile dacă sunt detectate nereguli.'**
  String get tosIntBankPoateSuspenda;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Modificarea datelor bancare trebuie verificată înainte de transfer.'**
  String get tosModificareaDatelorBancareTrebuie;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate modifica termenii și condițiile în orice moment.'**
  String get tosIntBankPoateModifica;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Notificările oficiale sunt comunicate prin aplicație, email sau SMS.'**
  String get tosNotificarileOficialeSuntComunicate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Serviciile pot fi suspendate temporar pentru mentenanță.'**
  String get tosServiciilePotFiSuspendate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Funcționalitățile suplimentare pot fi introduse fără notificare.'**
  String get tosFunctionalitatileSuplimentarePotFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Procedurile de autentificare și securitate pot fi actualizate.'**
  String get tosProcedurileAutentificareSecuritatePot;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Structura conturilor, limitele și condițiile pot fi modificate.'**
  String get tosStructuraConturilorLimiteleConditiile;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să folosească versiuni actualizate ale aplicației.'**
  String get tosClientiiTrebuieSaFoloseasca2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Accesul la anumite funcționalități poate fi limitat pentru neconformitate.'**
  String get tosAccesulAnumiteFunctionalitatiPoate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate schimba taxele și comisioanele percepute.'**
  String get tosIntBankPoateSchimba;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Actualizările vor fi afișate și în aplicație.'**
  String get tosActualizarileVorFiAfisate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Limitele de tranzacționare pot fi ajustate.'**
  String get tosLimiteleTranzactionarePotFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să accepte modificările pentru continuarea serviciilor.'**
  String get tosClientiiTrebuieSaAccepte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbările majore vor fi notificate prin email oficial.'**
  String get tosSchimbarileMajoreVorFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Funcționalitățile pot fi suspendate temporar pentru upgrade-uri.'**
  String get tosFunctionalitatilePotFiSuspendate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Actualizările de securitate sunt obligatorii pentru toți utilizatorii.'**
  String get tosActualizarileSecuritateSuntObligatorii;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să raporteze pierderea sau furtul dispozitivelor imediat.'**
  String get tosClientiiTrebuieSaRaporteze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să actualizeze informațiile personale la schimbarea datelor.'**
  String get tosClientulTrebuieSaActualizeze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să respecte legislația locală privind tranzacțiile financiare.'**
  String get tosClientiiTrebuieSaRespecte2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu se poate folosi aplicația pentru scopuri ilegale.'**
  String get tosSePoateFolosiAplicatia;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Respectarea regulilor de publicitate și promovare a serviciilor este obligatorie.'**
  String get tosRespectareaRegulilorPublicitatePromovare;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Litigiile privind conturile vor fi soluționate conform legislației.'**
  String get tosLitigiilePrivindConturileVor;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții sunt responsabili pentru toate datele introduse și confidențialitatea acestora.'**
  String get tosClientiiSuntResponsabiliToate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu garantează disponibilitatea neîntreruptă a serviciilor.'**
  String get tosIntBankGaranteazaDisponibilitatea;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să respecte cerințele pentru prevenirea fraudei.'**
  String get tosClientulTrebuieSaRespecte2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificarea periodică a extraselor de cont este responsabilitatea clientului.'**
  String get tosVerificareaPeriodicaExtraselorCont;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Respectarea limitelor de retragere și transfer impuse de INT Bank este obligatorie.'**
  String get tosRespectareaLimitelorRetragereTransfer;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificarea corectitudinii datelor în aplicație este responsabilitatea clientului.'**
  String get tosVerificareaCorectitudiniiDatelorAplicatie;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Protejarea dispozitivelor și a aplicației INT Bank este obligatorie.'**
  String get tosProtejareaDispozitivelorAplicatieiInt;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Este interzisă folosirea conturilor pentru activități comerciale fără aprobare.'**
  String get tosEsteInterzisaFolosireaConturilor;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Respectarea termenelor de plată pentru serviciile asociate este responsabilitatea clientului.'**
  String get tosRespectareaTermenelorPlataServiciile;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank colectează și procesează date personale conform legislației.'**
  String get tosIntBankColecteazaProceseaza;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să accepte politica de confidențialitate INT Bank.'**
  String get tosClientulTrebuieSaAccepte2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele sensibile nu trebuie distribuite către terți neautorizați.'**
  String get tosDateleSensibileTrebuieDistribuite;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții au dreptul de a solicita ștergerea datelor personale.'**
  String get tosClientiiAuDreptulSolicita;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele pot fi folosite pentru servicii personalizate și oferte.'**
  String get tosDatelePotFiFolosite;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Toate datele sunt stocate securizat și criptat.'**
  String get tosToateDateleSuntStocate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să raporteze accesul neautorizat la date.'**
  String get tosClientiiTrebuieSaRaporteze2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate procesa date anonimizate pentru statistici interne.'**
  String get tosIntBankPoateProcesa;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Folosirea datelor altor clienți fără consimțământ este interzisă.'**
  String get tosFolosireaDatelorAltorClienti;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Acceptarea cookie-urilor și termenilor de procesare este obligatorie.'**
  String get tosAcceptareaCookieUrilorTermenilor;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Modificările politicii de confidențialitate vor fi notificate prin aplicație.'**
  String get tosModificarilePoliticiiConfidentialitateVor;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să accepte termenii pentru a continua să folosească aplicația.'**
  String get tosClientiiTrebuieSaAccepte2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Datele colectate sunt folosite exclusiv în scopuri legale.'**
  String get tosDateleColectateSuntFolosite;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate bloca contul în caz de încălcare a politicii de date.'**
  String get tosIntBankPoateBloca;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să mențină informațiile personale actualizate.'**
  String get tosClientiiTrebuieSaMentina;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu este responsabilă pentru pierderi cauzate de erori ale clienților.'**
  String get tosIntBankEsteResponsabila;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu se garantează disponibilitatea neîntreruptă a serviciilor.'**
  String get tosSeGaranteazaDisponibilitateaNeintrerupta;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu răspunde pentru întârzieri cauzate de terți.'**
  String get tosIntBankRaspundeIntarzieri;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții sunt responsabili pentru protecția dispozitivelor și conturilor lor.'**
  String get tosClientiiSuntResponsabiliProtectia;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Serviciile pot fi suspendate în caz de urgență sau defecțiuni.'**
  String get tosServiciilePotFiSuspendate2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Respectarea instrucțiunilor de utilizare este responsabilitatea clientului.'**
  String get tosRespectareaInstructiunilorUtilizareEste;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu răspunde pentru pierderi cauzate de fraude externe.'**
  String get tosIntBankRaspundePierderi2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Serviciile sunt furnizate așa cum sunt, fără garanții suplimentare.'**
  String get tosServiciileSuntFurnizateAsa;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu garantează exactitatea informațiilor terților.'**
  String get tosIntBankGaranteazaExactitatea;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să verifice regulat extrasele de cont pentru erori.'**
  String get tosClientiiTrebuieSaVerifice;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Accesul la cont poate fi limitat în caz de risc de securitate.'**
  String get tosAccesulContPoateFi2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții sunt responsabili pentru folosirea aplicației conform legii.'**
  String get tosClientiiSuntResponsabiliFolosirea;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate ajusta termenii de responsabilitate prin notificare.'**
  String get tosIntBankPoateAjusta;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să accepte termenii pentru a continua folosirea serviciilor.'**
  String get tosClientiiTrebuieSaAccepte3;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate suspenda sau restricționa conturile care încalcă termenii.'**
  String get tosIntBankPoateSuspenda2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conturile trebuie să respecte politicile fiscale locale.'**
  String get tosConturileTrebuieSaRespecte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank nu este responsabil pentru pierderile cauzate de terți.'**
  String get tosIntBankEsteResponsabil;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să utilizeze doar canalele oficiale INT Bank.'**
  String get tosClientiiTrebuieSaUtilizeze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Dispute privind tranzacțiile vor fi investigate conform procedurilor interne.'**
  String get tosDisputePrivindTranzactiileVor;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să respecte cerințele de securitate.'**
  String get tosClientiiTrebuieSaRespecte3;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conturile inactive sau nedeclarate pot fi dezactivate.'**
  String get tosConturileInactiveNedeclaratePot;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Folosirea aplicației implică acordul față de toate regulile INT Bank.'**
  String get tosFolosireaAplicatieiImplicaAcordul;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate introduce noi funcționalități și servicii.'**
  String get tosIntBankPoateIntroduce2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nerespectarea termenilor poate duce la suspendarea contului.'**
  String get tosNerespectareaTermenilorPoateDuce;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să respecte toate notificările INT Bank.'**
  String get tosClientiiTrebuieSaRespecte4;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Modificările legislative pot influența regulile aplicabile.'**
  String get tosModificarileLegislativePotInfluenta;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să consulte periodic aplicația pentru actualizări.'**
  String get tosClientulTrebuieSaConsulte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate modifica termenii pentru a proteja clienții.'**
  String get tosIntBankPoateModifica2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții sunt responsabili pentru respectarea regulilor aplicației.'**
  String get tosClientiiSuntResponsabiliRespectarea;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Toate taxele aplicate contului vor fi afișate transparent în aplicație.'**
  String get tosToateTaxeleAplicateContului;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate modifica comisioanele prin notificare prealabilă.'**
  String get tosIntBankPoateModifica3;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Taxele pentru tranzacțiile internaționale pot varia conform cursului valutar.'**
  String get tosTaxeleTranzactiileInternationalePot;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul este responsabil pentru plata tuturor taxelor aferente contului.'**
  String get tosClientulEsteResponsabilPlata2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Taxele pot fi percepute pentru retrageri, transferuri și servicii adiționale.'**
  String get tosTaxelePotFiPercepute;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate suspenda contul pentru neplata taxelor aplicabile.'**
  String get tosIntBankPoateSuspenda3;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să consulte ghidul tarifar actualizat al băncii.'**
  String get tosClientiiTrebuieSaConsulte;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Reduceri și promoții pot fi aplicate doar conform regulilor INT Bank.'**
  String get tosReduceriPromotiiPotFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Taxele percepute de terți pentru transferuri externe sunt responsabilitatea clientului.'**
  String get tosTaxelePerceputeTertiTransferuri;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbările de taxe vor fi comunicate prin aplicație și email.'**
  String get tosSchimbarileTaxeVorFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Comisioanele pentru servicii speciale sunt afișate separat.'**
  String get tosComisioaneleServiciiSpecialeSunt;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate ajusta limitele taxelor în funcție de cont.'**
  String get tosIntBankPoateAjusta2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Taxele suplimentare pentru tranzacții urgente pot fi percepute.'**
  String get tosTaxeleSuplimentareTranzactiiUrgente;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clientul trebuie să accepte taxele pentru continuarea serviciului.'**
  String get tosClientulTrebuieSaAccepte3;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Neplata taxelor poate duce la suspendarea funcționalităților contului.'**
  String get tosNeplataTaxelorPoateDuce;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate rezilia contul în caz de încălcare a termenilor.'**
  String get tosIntBankPoateRezilia;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Suspendarea contului poate fi temporară sau permanentă.'**
  String get tosSuspendareaContuluiPoateFi2;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții vor fi notificați prin aplicație sau email oficial.'**
  String get tosClientiiVorFiNotificati;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Rezilierea contului nu eliberează clientul de obligațiile financiare.'**
  String get tosReziliereaContuluiElibereazaClientul;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate închide contul pentru activități ilegale.'**
  String get tosIntBankPoateInchide;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Suspendarea contului se poate realiza pentru verificări suplimentare.'**
  String get tosSuspendareaContuluiSePoate;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conturile inactive pe termen lung pot fi dezactivate automat.'**
  String get tosConturileInactiveTermenLung;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Rezilierea contului nu afectează tranzacțiile deja efectuate.'**
  String get tosReziliereaContuluiAfecteazaTranzactiile;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să coopereze pentru închiderea contului conform procedurilor.'**
  String get tosClientiiTrebuieSaCoopereze;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank poate suspenda serviciile în caz de risc de securitate.'**
  String get tosIntBankPoateSuspenda4;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Reactivarea contului poate fi solicitată doar conform regulilor băncii.'**
  String get tosReactivareaContuluiPoateFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Clienții trebuie să își retragă fondurile înainte de închidere.'**
  String get tosClientiiTrebuieSaIsi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Orice litigiu legat de contul suspendat va fi soluționat conform legislației.'**
  String get tosOriceLitigiuLegatContul;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Suspendarea temporară poate fi decisă de banca pentru mentenanță sau upgrade.'**
  String get tosSuspendareaTemporaraPoateFi;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Rezilierea contului se realizează numai după respectarea tuturor procedurilor.'**
  String get tosReziliereaContuluiSeRealizeaza;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Termeni și Condiții'**
  String get tosTermeniConditii;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Se procesează...'**
  String get tosSeProceseaza;

  /// Used in tos_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Sunt de acord'**
  String get tosSuntAcord;

  /// Used in splash_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-a putut realiza conexiunea cu serverul. Așteptăm conexiunea...'**
  String get splashSPututRealizaConexiunea;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'3 luni'**
  String get statement3Luni;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'6 luni'**
  String get statement6Luni;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'1 an'**
  String get statement1An;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Personalizat'**
  String get statementPersonalizat;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-a putut încărca extrasul de cont.'**
  String get statementSPututIncarcaExtrasul;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Extrasul PDF ({startDate} - {endDate}) a fost generat cu succes!'**
  String statementExtrasulPdfFostGenerat(Object startDate, Object endDate);

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'PDF-ul nu a putut fi descărcat.'**
  String get statementPdfUlPututFi;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Extras de cont'**
  String get statementExtrasCont;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Perioada: {startDate} - {endDate}'**
  String statementPerioada(Object startDate, Object endDate);

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Se generează PDF...'**
  String get statementSeGenereazaPdf;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Descarcă extras PDF'**
  String get statementDescarcaExtrasPdf;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'SOLD INIȚIAL'**
  String get statementSoldInitial;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'SOLD FINAL'**
  String get statementSoldFinal;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'ÎNCASĂRI (+)'**
  String get statementIncasari;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'PLĂȚI (-)'**
  String get statementPlati;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'OPERAȚIUNI ({transactions})'**
  String statementOperatiuni(Object transactions);

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Atinge o tranzacție pentru detalii'**
  String get statementAtingeTranzactieDetalii;

  /// Used in statement_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nicio operațiune în această perioadă'**
  String get statementNicioOperatiuneAceastaPerioada;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Toate'**
  String get historyToate;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Intrări (+)'**
  String get historyIntrari;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ieșiri (-)'**
  String get historyIesiri;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Luna curentă'**
  String get historyLunaCurenta;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-a putut încărca istoricul tranzacțiilor.'**
  String get historySPututIncarcaIstoricul;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Istoric tranzacții'**
  String get historyIstoricTranzactii;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Caută comerciant, descriere...'**
  String get historyCautaComerciantDescriere;

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Total: {currency}'**
  String historyTotal(Object currency);

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Total: {totalSum}'**
  String historyTotal2(Object totalSum);

  /// Used in transaction_history_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu au fost găsite tranzacții care să corespundă căutării.'**
  String get historyAuFostGasiteTranzactii;

  /// Used in transaction_details_bottom_sheet.dart, transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transfer bancar'**
  String get commonTransferBancar;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Dovadă de plată'**
  String get txDetailsDovadaPlata;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Finalizată'**
  String get txDetailsFinalizata;

  /// Used in transaction_details_bottom_sheet.dart, transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'În procesare'**
  String get commonProcesare;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Data & Ora'**
  String get txDetailsDataOra;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Referință tranzacție'**
  String get txDetailsReferintaTranzactie;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Tip operațiune'**
  String get txDetailsTipOperatiune;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Plată / Transfer trimis'**
  String get txDetailsPlataTransferTrimis;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Încasare / Transfer primit'**
  String get txDetailsIncasareTransferPrimit;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont expeditor (IBAN)'**
  String get txDetailsContExpeditorIban;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Cont beneficiar (IBAN)'**
  String get txDetailsContBeneficiarIban;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Tranzacție INTBank: {trackingId} | Suma: {signedAmount} | Data: {date}'**
  String txDetailsTranzactieIntbankSumaData(
    Object trackingId,
    Object signedAmount,
    Object date,
  );

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Detaliile tranzacției au fost copiate'**
  String get txDetailsDetaliileTranzactieiAuFost;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Copiază'**
  String get txDetailsCopiaza;

  /// Used in transaction_details_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'{label} a fost copiat în clipboard'**
  String txDetailsFostCopiatClipboard(Object label);

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu s-au putut încărca plățile programate.'**
  String get scheduledSAuPututIncarca;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plata programată a fost anulată.'**
  String get scheduledPlataProgramataFostAnulata;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plata programată nu a putut fi anulată.'**
  String get scheduledPlataProgramataPututFi;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Anulezi plata recurentă?'**
  String get scheduledAnuleziPlataRecurenta;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plata de {amount} către {beneficiary} nu va mai fi executată.'**
  String scheduledPlataCatreVaMai(Object amount, Object beneficiary);

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Anulează plata'**
  String get scheduledAnuleazaPlata;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Păstrează'**
  String get scheduledPastreaza;

  /// Used in scheduled_transfers_screen.dart, transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Săptămânal'**
  String get commonSaptamanal;

  /// Used in scheduled_transfers_screen.dart, transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Lunar'**
  String get commonLunar;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'O singură dată'**
  String get scheduledSinguraData;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plăți programate'**
  String get scheduledPlatiProgramate;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nicio plată programată'**
  String get scheduledNicioPlataProgramata;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Poți seta plăți recurente sau viitoare direct din ecranul de transfer activând opțiunea \"Programare plată\".'**
  String get scheduledPotiSetaPlatiRecurente;

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Beneficiar'**
  String get scheduledBeneficiar;

  /// Used in scheduled_transfers_screen.dart, transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Detalii: {reason}'**
  String commonDetalii(Object reason);

  /// Used in scheduled_transfers_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Următoarea: {nextRun}'**
  String scheduledUrmatoarea(Object nextRun);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plată programată'**
  String get receiptPlataProgramata;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transfer efectuat'**
  String get receiptTransferEfectuat;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transfer în procesare'**
  String get receiptTransferProcesare;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programată'**
  String get receiptProgramata;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Finalizat'**
  String get receiptFinalizat;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'INT Bank - {title}'**
  String receiptIntBank(Object title);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Sumă: {amount}'**
  String receiptSuma(Object amount);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Beneficiar: {beneficiaryName}'**
  String receiptBeneficiar(Object beneficiaryName);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN beneficiar: {toIban}'**
  String receiptIbanBeneficiar(Object toIban);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Data: {createdAt}'**
  String receiptData(Object createdAt);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programare: {scheduleSummary}'**
  String receiptProgramare(Object scheduleSummary);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'ID tranzacție: {trackingId}'**
  String receiptIdTranzactie(Object trackingId);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'către {beneficiaryName}'**
  String receiptCatre(Object beneficiaryName);

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Banca procesează transferul. Vei primi o notificare când este finalizat.'**
  String get receiptBancaProceseazaTransferulVei;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Detaliile au fost copiate.'**
  String get receiptDetaliileAuFostCopiate;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Copiază detaliile'**
  String get receiptCopiazaDetaliile;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Gata'**
  String get receiptGata;

  /// Used in transfer_receipt_screen.dart, transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transfer nou'**
  String get commonTransferNou;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Status'**
  String get receiptStatus;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Data'**
  String get receiptData2;

  /// Used in transfer_confirmation_bottom_sheet.dart, transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programare'**
  String get commonProgramare;

  /// Used in transfer_confirmation_bottom_sheet.dart, transfer_receipt_screen.dart, transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Din contul'**
  String get commonContul;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Către'**
  String get receiptCatre2;

  /// Used in transfer_confirmation_bottom_sheet.dart, transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Detalii plată'**
  String get commonDetaliiPlata;

  /// Used in transfer_receipt_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'ID tranzacție'**
  String get receiptIdTranzactie2;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'O dată'**
  String get transferData;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'{frequency}, din {scheduledDate}'**
  String transferDin(Object frequency, Object scheduledDate);

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la transfer'**
  String get transferEroareTransfer;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transferul nu a putut fi efectuat. Încearcă din nou.'**
  String get transferTransferulPututFiEfectuat;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Completează datele pentru a efectua transferul'**
  String get transferCompleteazaDateleEfectuaTransferul;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'DESTINATAR'**
  String get transferDestinatar;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programate'**
  String get transferProgramate;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Agendă'**
  String get transferAgenda;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN destinatar'**
  String get transferIbanDestinatar;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nume beneficiar'**
  String get transferNumeBeneficiar;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Popescu Ion'**
  String get transferPopescuIon;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Suma ({currency})'**
  String transferSuma(Object currency);

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Disponibil: {availableBalance}'**
  String transferDisponibil(Object availableBalance);

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Motiv transfer'**
  String get transferMotivTransfer;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Plată factură, Rambursare etc.'**
  String get transferPlataFacturaRambursareEtc;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Salvează destinatarul în agenda de plăți'**
  String get transferSalveazaDestinatarulAgendaPlati;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programare plată / Recurență'**
  String get transferProgramarePlataRecurenta;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Frecvență execuție'**
  String get transferFrecventaExecutie;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Data execuției: {scheduledDate}'**
  String transferDataExecutiei(Object scheduledDate);

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Schimbă data'**
  String get transferSchimbaData;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Programează transferul'**
  String get transferProgrameazaTransferul;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Transferă acum'**
  String get transferTransferaAcum;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Disponibil'**
  String get transferDisponibil2;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu IBAN-ul destinatarului.'**
  String get transferValidationIntroduIbanUlDestinatarului;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN-ul începe cu codul țării și două cifre (ex. RO49).'**
  String get transferValidationIbanUlIncepeCodul;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN-ul poate conține doar litere și cifre.'**
  String get transferValidationIbanUlPoateContine;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN-ul are o lungime incorectă.'**
  String get transferValidationIbanUlAreLungime;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Acesta este contul din care plătești. Alege alt destinatar.'**
  String get transferValidationAcestaEsteContulCare;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Un IBAN românesc are 24 de caractere (ai introdus {c}).'**
  String transferValidationIbanRomanescAre24(Object c);

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN-ul nu este valid. Verifică dacă ai copiat corect toate caracterele.'**
  String get transferValidationIbanUlEsteValid;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu numele beneficiarului.'**
  String get transferValidationIntroduNumeleBeneficiarului;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Numele este prea scurt.'**
  String get transferValidationNumeleEstePreaScurt;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Numele poate avea cel mult {maxNameLength} de caractere.'**
  String transferValidationNumelePoateAveaCel(Object maxNameLength);

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Numele trebuie să conțină litere.'**
  String get transferValidationNumeleTrebuieSaContina;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu o sumă mai mare de 0.'**
  String get transferValidationIntroduSumaMaiMare;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Sold insuficient. Disponibil: {available}.'**
  String transferValidationSoldInsuficientDisponibil(Object available);

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Descrie pe scurt plata (ex. „Chirie octombrie”).'**
  String get transferValidationDescrieScurtPlataEx;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Detaliile plății trebuie să aibă minim 3 caractere.'**
  String get transferValidationDetaliilePlatiiTrebuieSa;

  /// Used in transfer_form_validator.dart
  ///
  /// In ro, this message translates to:
  /// **'Detaliile pot avea cel mult {maxReasonLength} de caractere.'**
  String transferValidationDetaliilePotAveaCel(Object maxReasonLength);

  /// Used in saved_beneficiaries_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Beneficiari salvați'**
  String get beneficiariesBeneficiariSalvati;

  /// Saved beneficiaries count
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} contact} few{{count} contacte} other{{count} de contacte}}'**
  String beneficiariesContacte(int count);

  /// Used in saved_beneficiaries_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Caută după nume sau IBAN...'**
  String get beneficiariesCautaDupaNumeIban;

  /// Used in saved_beneficiaries_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu ai niciun beneficiar salvat încă'**
  String get beneficiariesNiciunBeneficiarSalvatInca;

  /// Used in saved_beneficiaries_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Niciun rezultat găsit'**
  String get beneficiariesNiciunRezultatGasit;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Verificare transfer'**
  String get transferConfirmVerificareTransfer;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Verifică detaliile plății înainte de trimitere'**
  String get transferConfirmVerificaDetaliilePlatiiInainte;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'SUMĂ DE TRANSFERAT'**
  String get transferConfirmSumaTransferat;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Comision: {currency} • Transfer gratuit'**
  String transferConfirmComisionTransferGratuit(Object currency);

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Destinatar'**
  String get transferConfirmDestinatar;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Bancă beneficiar'**
  String get transferConfirmBancaBeneficiar;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Bancă Comercială'**
  String get transferConfirmBancaComerciala;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'IBAN Destinație'**
  String get transferConfirmIbanDestinatie;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Plata va fi executată automat. O poți anula oricând din „Plăți programate”.'**
  String get transferConfirmPlataVaFiExecutata;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Verifică IBAN-ul și suma. După confirmare, transferul este trimis imediat și nu mai poate fi anulat din aplicație.'**
  String get transferConfirmVerificaIbanUlSuma;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă programarea'**
  String get transferConfirmConfirmaProgramarea;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Confirmă transferul'**
  String get transferConfirmConfirmaTransferul;

  /// Used in transfer_confirmation_bottom_sheet.dart
  ///
  /// In ro, this message translates to:
  /// **'Modifică detaliile'**
  String get transferConfirmModificaDetaliile;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Salut și bine ai venit în INT Bank!'**
  String get welcomeSalutBineVenitInt;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ești deja client '**
  String get welcomeEstiDejaClient;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'? Continuă cu '**
  String get welcomeContinua;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Conectează-te'**
  String get welcomeConecteaza;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'.\n\nDacă nu ai cont, '**
  String get welcomeDacaCont;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'poți deveni client direct din INT Bank'**
  String get welcomePotiDeveniClientDirect;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'.\n\nEste '**
  String get welcomeEste;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'rapid și sigur'**
  String get welcomeRapidSigur;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **', iar tu vei avea acces la toate funcționalitățile contului tău bancar '**
  String get welcomeIarTuVeiAvea;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'instant și de la distanță'**
  String get welcomeInstantDistanta;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Înregistrează-te'**
  String get welcomeInregistreaza;

  /// Used in welcome_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Ai deja un cont? '**
  String get welcomeDejaCont;

  /// Used in app_router.dart
  ///
  /// In ro, this message translates to:
  /// **'Pagina solicitată nu a fost găsită. Te redirecționăm către ecranul principal...'**
  String get routerPaginaSolicitataFostGasita;

  /// Used in app_button.dart
  ///
  /// In ro, this message translates to:
  /// **'{label}, se procesează'**
  String commonSeProceseaza(Object label);

  /// Used in confirm_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Renunță'**
  String get commonRenunta;

  /// Used in country_dropdown.dart
  ///
  /// In ro, this message translates to:
  /// **'Prefix țară'**
  String get commonPrefixTara;

  /// Used in date_picker_field.dart
  ///
  /// In ro, this message translates to:
  /// **'Selectează data'**
  String get commonSelecteazaData;

  /// Used in error_retry_view.dart
  ///
  /// In ro, this message translates to:
  /// **'Reîncearcă'**
  String get commonReincearca;

  /// Used in pin_dot_indicator.dart
  ///
  /// In ro, this message translates to:
  /// **'{length} din {totalDots} cifre introduse'**
  String commonCifreIntroduse(Object length, Object totalDots);

  /// Used in pin_pad.dart
  ///
  /// In ro, this message translates to:
  /// **'Cifra {d}'**
  String commonCifra(Object d);

  /// Used in pin_pad.dart
  ///
  /// In ro, this message translates to:
  /// **'Șterge ultima cifră'**
  String get commonStergeUltimaCifra;

  /// Used in step_indicator.dart
  ///
  /// In ro, this message translates to:
  /// **'Pasul {currentStep} din {totalSteps}'**
  String commonPasul(Object currentStep, Object totalSteps);

  /// Statement period preset
  ///
  /// In ro, this message translates to:
  /// **'30 zile'**
  String get statement30Zile;

  /// Spoken when no date is chosen
  ///
  /// In ro, this message translates to:
  /// **'neselectată'**
  String get commonNeselectata;

  /// Transactions and share of spending in a category
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} tranzacție} few{{count} tranzacții} other{{count} de tranzacții}} • {percent}'**
  String analyticsCategoryCount(int count, String percent);

  /// Number of transactions matching the filters
  ///
  /// In ro, this message translates to:
  /// **'{count, plural, one{{count} tranzacție găsită} few{{count} tranzacții găsite} other{{count} de tranzacții găsite}}'**
  String historyResultsCount(int count);

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la autentificare. Încearcă din nou.'**
  String get pinEroareAutentificareIncearcaNou;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare: Nu te poți conecta la server'**
  String get pinEroarePotiConectaServer;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu te poți conecta la server. Încearcă din nou.'**
  String get pinPotiConectaServerIncearca;

  /// Used in pin_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'PIN-urile nu coincid'**
  String get pinPinUrileCoincid;

  /// Used in register_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu te poți conecta la server. Verifică conexiunea'**
  String get registerPotiConectaServerVerifica;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la obținerea tokenului client'**
  String get twoFactorEroareObtinereaTokenuluiClient;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Codul nu a putut fi trimis. Apasă „Retrimite” și încearcă din nou.'**
  String get twoFactorCodulPututFiTrimis;

  /// Used in two_factor_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Sesiune expirată. Te rugăm să te reconectezi'**
  String get twoFactorSesiuneExpirataRugamSa;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Nu ai un cont activ în {fromCurrency}.'**
  String exchangeContActiv(Object fromCurrency);

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Introdu o sumă validă pentru schimb'**
  String get exchangeIntroduSumaValidaSchimb;

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Fonduri insuficiente! Disponibil: {available}'**
  String exchangeFonduriInsuficienteDisponibil(Object available);

  /// Used in exchange_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la realizarea schimbului valutar'**
  String get exchangeEroareRealizareaSchimbuluiValutar;

  /// Used in open_currency_account_dialog.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la deschiderea contului'**
  String get openCurrencyEroareDeschidereaContului;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la programarea plății'**
  String get transferEroareProgramareaPlatii;

  /// Used in transfer_screen.dart
  ///
  /// In ro, this message translates to:
  /// **'Eroare la efectuarea transferului'**
  String get transferEroareEfectuareaTransferului;

  /// Screen-reader label for an incoming transaction row
  ///
  /// In ro, this message translates to:
  /// **'Încasare: {beneficiary}, {date}, {amount}'**
  String commonTxIncomingSemantics(
    String beneficiary,
    String date,
    String amount,
  );

  /// Screen-reader label for an outgoing transaction row
  ///
  /// In ro, this message translates to:
  /// **'Plată: {beneficiary}, {date}, {amount}'**
  String commonTxOutgoingSemantics(
    String beneficiary,
    String date,
    String amount,
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
