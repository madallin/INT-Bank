// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'INT Bank';

  @override
  String get errorsAparutEroareNeasteptataIncearca =>
      'Something went wrong. Please try again.';

  @override
  String get errorsServerulRaspundeIncearcaNou =>
      'The server isn\'t responding. Try again in a few moments.';

  @override
  String get errorsPotiConectaServerVerifica =>
      'Can\'t connect to the server. Check your internet connection.';

  @override
  String get errorsConexiuneaEsteSiguraOperatiunea =>
      'The connection isn\'t secure. The operation was stopped.';

  @override
  String get errorsOperatiuneaFostAnulata => 'The operation was cancelled.';

  @override
  String get errorsSesiuneaExpiratAutentificaNou =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorsPermisiuneaAceastaOperatiune =>
      'You don\'t have permission for this operation.';

  @override
  String get errorsResursaSolicitataFostGasita =>
      'The requested resource wasn\'t found.';

  @override
  String get errorsPreaMulteIncercariAsteapta =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errorsServiciulEsteTemporarIndisponibil =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get analyticsIanuarie => 'January';

  @override
  String get analyticsFebruarie => 'February';

  @override
  String get analyticsMartie => 'March';

  @override
  String get analyticsAprilie => 'April';

  @override
  String get analyticsMai => 'May';

  @override
  String get analyticsIunie => 'June';

  @override
  String get analyticsIulie => 'July';

  @override
  String get analyticsAugust => 'August';

  @override
  String get analyticsSeptembrie => 'September';

  @override
  String get analyticsOctombrie => 'October';

  @override
  String get analyticsNoiembrie => 'November';

  @override
  String get analyticsDecembrie => 'December';

  @override
  String get analyticsSAuPututIncarca => 'Couldn\'t load your statistics.';

  @override
  String get analyticsSAuPututIncarca2 => 'Couldn\'t load your statistics.';

  @override
  String get analyticsStatisticiCheltuieli => 'Spending insights';

  @override
  String get analyticsLunaAnterioara => 'Previous month';

  @override
  String get analyticsLunaUrmatoare => 'Next month';

  @override
  String analyticsTotalCheltuit(Object month) {
    return 'TOTAL SPENT IN $month';
  }

  @override
  String analyticsCategorieTop(Object topCategory) {
    return 'Top category: $topCategory';
  }

  @override
  String analyticsPlati(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '$count payment',
    );
    return '$_temp0';
  }

  @override
  String get analyticsDistributieCategorii => 'BREAKDOWN BY CATEGORY';

  @override
  String get analyticsNicioCheltuialaAceastaLuna => 'No spending this month';

  @override
  String get loginLungimeaNumaruluiEsteValida =>
      'The number has an invalid length';

  @override
  String get loginNumarulTelefonApartineUnui =>
      'This phone number doesn\'t belong to a customer';

  @override
  String loginEroareComunicareaServerulCod(Object statusCode) {
    return 'Error communicating with the server (code: $statusCode)';
  }

  @override
  String get loginPotiConectaServerVerifica =>
      'Can\'t connect to the server. Check your internet connection';

  @override
  String get loginIntroduNumarulTelefon => 'Enter your phone number';

  @override
  String get loginNumarulTelefonEsteValid => 'The phone number isn\'t valid';

  @override
  String get loginConectare => 'Sign in';

  @override
  String get loginRugamSaIntroduciNumarul =>
      'Please enter the number you registered with the bank';

  @override
  String get commonNumarTelefon => 'Phone number';

  @override
  String get commonIncarcare => 'Loading...';

  @override
  String get commonConfirma => 'Confirm';

  @override
  String get pinPinIncorect => 'Incorrect PIN';

  @override
  String get pinEroareSetareaPinUlui => 'Couldn\'t set your PIN';

  @override
  String get pinConfirmaPinUl => 'Confirm your PIN';

  @override
  String get pinSeteazaPinUl => 'Set your PIN';

  @override
  String get pinIntroduPinUl => 'Enter your PIN';

  @override
  String get pinReintroducetiCodulPinConfirmare =>
      'Re-enter your PIN to confirm';

  @override
  String get pinAlegetiCodPin6 => 'Choose a 6-digit PIN';

  @override
  String get pinContinuaRugamSaIntroduci =>
      'To continue, please enter your PIN';

  @override
  String get registerMasculin => 'Male';

  @override
  String get registerNecasatorit => 'Single';

  @override
  String get registerContulExistaDeja => 'This account already exists';

  @override
  String get registerEroareInregistrare => 'Registration failed';

  @override
  String get registerVerificareNumar => 'Verify number';

  @override
  String get registerIntroduNumarulTauTelefon => 'Enter your phone number';

  @override
  String get registerDatePersonale => 'Personal details';

  @override
  String get registerCompleteazaDateleTale => 'Fill in your details';

  @override
  String get registerPrenume => 'First name';

  @override
  String get registerIntroduPrenumele => 'Enter your first name';

  @override
  String get registerNume => 'Last name';

  @override
  String get registerIntroduNumele => 'Enter your last name';

  @override
  String get registerEmail => 'Email';

  @override
  String get registerEmailExempluRo => 'email@example.com';

  @override
  String get registerFeminin => 'Female';

  @override
  String get registerGen => 'Gender';

  @override
  String get registerCnp => 'Personal ID number (CNP)';

  @override
  String get registerCasatorit => 'Married';

  @override
  String get registerDivortat => 'Divorced';

  @override
  String get registerStareCivila => 'Marital status';

  @override
  String get registerConfirmareDate => 'Confirm your details';

  @override
  String get registerVerificaDateleIntroduse => 'Check the details you entered';

  @override
  String get registerTelefon => 'Phone';

  @override
  String get commonDataNasterii => 'Date of birth';

  @override
  String get registerInregistrare => 'Sign up';

  @override
  String get commonInapoi => 'Back';

  @override
  String get registerContinua => 'Continue';

  @override
  String get registerConfirmaInregistrarea => 'Confirm sign-up';

  @override
  String get twoFactorEroareTrimitereaCodului => 'Couldn\'t send the code';

  @override
  String get twoFactorTimpulVerificareExpiratRugam =>
      'The verification time has expired. Please start again.';

  @override
  String get twoFactorVerificareReusitaVeiFi => 'Verified! Redirecting you...';

  @override
  String get twoFactorCodInvalidDepasitNumarul =>
      'Invalid code, or you\'ve exceeded the number of attempts';

  @override
  String get twoFactorCodVerificareSms6 => '6-digit verification code from SMS';

  @override
  String get twoFactorVerificare => 'Verification';

  @override
  String get twoFactorIntroduCodulVerificare => 'Enter the verification code';

  @override
  String get twoFactorAmTrimisCodVerificare =>
      'We sent a verification code to\n';

  @override
  String get twoFactorPrimitCodul => 'Didn\'t get the code? ';

  @override
  String get twoFactorRetrimite => 'Resend';

  @override
  String twoFactorRetrimiteS(Object cooldownSeconds) {
    return 'Resend (${cooldownSeconds}s)';
  }

  @override
  String get cardSettingsBlocheziTemporarCardul =>
      'Temporarily block your card?';

  @override
  String cardSettingsPlatileCardulRetragerileAtm(Object last4) {
    return 'Payments with card •••• $last4 and ATM withdrawals will be declined until you unblock it. You can unblock it at any time from this page.';
  }

  @override
  String get cardSettingsBlocheaza => 'Block';

  @override
  String get cardSettingsCardulFostBlocatTemporar =>
      'Your card has been temporarily blocked';

  @override
  String get cardSettingsCardulFostDeblocatSucces =>
      'Your card has been unblocked';

  @override
  String get cardSettingsStareaCarduluiPututFi =>
      'Couldn\'t change the card status.';

  @override
  String cardSettingsNouaLimitaFostSalvata(Object spendingLimit) {
    return 'Your new limit ($spendingLimit) has been saved!';
  }

  @override
  String get cardSettingsLimitaPututFiSalvata => 'Couldn\'t save the limit.';

  @override
  String get cardSettingsOptiunilePlataAuFost => 'Payment options updated.';

  @override
  String get cardSettingsOptiunileAuPututFi => 'Couldn\'t save the options.';

  @override
  String get cardSettingsSetariCard => 'Card settings';

  @override
  String get cardSettingsBlocat => 'BLOCKED';

  @override
  String get cardSettingsActiv => 'ACTIVE';

  @override
  String cardSettingsExp(Object expiryDate) {
    return 'EXP: $expiryDate';
  }

  @override
  String get cardSettingsSecuritateCard => 'CARD SECURITY';

  @override
  String get cardSettingsBlocareTemporaraCard => 'Temporarily block card';

  @override
  String get cardSettingsDezactiveazaPlatileRetragerileAtm =>
      'Instantly disables payments and ATM withdrawals.';

  @override
  String get cardSettingsLimiteTranzactii => 'TRANSACTION LIMITS';

  @override
  String get cardSettingsLimitaZilnicaCheltuieli => 'Daily spending limit';

  @override
  String get cardSettingsSalveazaNouaLimita => 'Save new limit';

  @override
  String get cardSettingsOptiuniPlati => 'PAYMENT OPTIONS';

  @override
  String get cardSettingsPlatiOnlineECommerce => 'Online payments (e-commerce)';

  @override
  String get cardSettingsPermiteTranzactiiSecurizateInternet =>
      'Allows secure transactions on the internet.';

  @override
  String get cardSettingsPlatiContactlessPos => 'Contactless payments (POS)';

  @override
  String get cardSettingsPlatiRapideFaraContact =>
      'Quick contactless payments in shops.';

  @override
  String get errorUpsCevaFunctionat => 'Oops, something went wrong...';

  @override
  String get errorReincearcaAcum => 'Try again now';

  @override
  String get errorIncaAvemConexiuneReincercam =>
      'Still no connection. We\'ll keep trying automatically.';

  @override
  String exchangeContInexistent(Object toCurrency) {
    return 'No $toCurrency account';
  }

  @override
  String exchangeCumparaTrebuieSaDeschizi(Object toCurrency) {
    return 'To buy $toCurrency, first open a sub-account in that currency.';
  }

  @override
  String get commonInchide => 'Close';

  @override
  String get exchangeDeschideCont => 'Open account';

  @override
  String get exchangeConfirmaSchimbulValutar => 'Confirm currency exchange';

  @override
  String get exchangePlatesti => 'You pay:';

  @override
  String get exchangePrimesti => 'You get:';

  @override
  String get exchangeCursSchimb => 'Exchange rate:';

  @override
  String get exchangeComisionTranzactie => 'Transaction fee:';

  @override
  String get exchangeGratuit => 'Free';

  @override
  String get commonAnuleaza => 'Cancel';

  @override
  String get exchangeSchimbValutarRealizatSucces =>
      'Currency exchanged successfully!';

  @override
  String get exchangeSchimbulValutarPututFi =>
      'The currency exchange couldn\'t be completed.';

  @override
  String get exchangeSchimbValutar => 'Currency exchange';

  @override
  String get exchangeSchimbaIntreDiferiteValute =>
      'Exchange between currencies at today\'s rate';

  @override
  String get exchangeValuta => 'From currency';

  @override
  String get exchangeInverseazaValutele => 'Swap currencies';

  @override
  String get exchangeValuta2 => 'To currency';

  @override
  String get exchangeCursulValutarEsteDisponibil =>
      'The exchange rate isn\'t available';

  @override
  String exchangeComision(Object commissionPercent, Object commissionAmount) {
    return 'Fee $commissionPercent: $commissionAmount';
  }

  @override
  String exchangeRataEfectiva1(
    Object fromCurrency,
    Object rateWithCommission,
    Object toCurrency,
  ) {
    return 'Effective rate: 1 $fromCurrency = $rateWithCommission $toCurrency';
  }

  @override
  String get exchangeSchimbaValuta => 'Exchange currency';

  @override
  String get homeSeIncarcaDateleContului => 'Loading account details...';

  @override
  String get homeClientIntbank => 'INTBank customer';

  @override
  String get homeDeconectezi => 'Sign out?';

  @override
  String get homeVaTrebuiSaAutentifici =>
      'You\'ll need to sign in again to use the app.';

  @override
  String get homeDeconecteazaMa => 'Sign me out';

  @override
  String get homeBunVenit => 'Welcome!';

  @override
  String get homeArataSumele => 'Show amounts';

  @override
  String get homeAscundeSumele => 'Hide amounts';

  @override
  String get homeNotificari => 'Notifications';

  @override
  String get homeDeconectare => 'Sign out';

  @override
  String get homeCarduriDisponibile => 'You don\'t have any cards';

  @override
  String homeCard(Object currentCardIndex, Object cardList) {
    return 'Card $currentCardIndex of $cardList';
  }

  @override
  String get homeCardulAnterior => 'Previous card';

  @override
  String get homeCardulUrmator => 'Next card';

  @override
  String get homeSetariCard => 'Card settings';

  @override
  String get homeTitular => 'CARDHOLDER';

  @override
  String get homeExpira => 'EXPIRES';

  @override
  String get homePan => 'PAN  ';

  @override
  String get homeCvv => 'CVV';

  @override
  String homeExp(Object expiry) {
    return 'EXP: $expiry';
  }

  @override
  String get homeAscundeDateleCardului => 'Hide card details';

  @override
  String get homeAscunde => 'Hide';

  @override
  String get commonSoldDisponibil => 'Available balance';

  @override
  String get homeArataSoldul => 'Show balance';

  @override
  String get homeAscundeSoldul => 'Hide balance';

  @override
  String get homeValuta => 'Currency';

  @override
  String get homeExtras => 'Statement';

  @override
  String get homeDetaliiCont => 'Account details';

  @override
  String get commonTransfer => 'Transfer';

  @override
  String get homeIstoric => 'History';

  @override
  String get homeSchimb => 'Exchange';

  @override
  String get homeStatistici => 'Insights';

  @override
  String get homeSeifuriRoundUp => 'Vaults & Round-Up';

  @override
  String get homeNou => 'NEW';

  @override
  String get homeEconomisesteAutomatMaruntisulTranzactiilor =>
      'Automatically save the spare change from your payments.';

  @override
  String get homeCursValutar => 'Exchange rates';

  @override
  String get homeSeIncarca => 'Loading...';

  @override
  String get homeTranzactiiRecente => 'Recent transactions';

  @override
  String get homeVeziToate => 'See all';

  @override
  String get homeExistaTranzactiiRecente => 'No recent transactions';

  @override
  String homeNecitite(Object tooltip, Object badgeCount) {
    return '$tooltip, $badgeCount unread';
  }

  @override
  String get accountDetailsDetaliiContCurent => 'Current account details';

  @override
  String accountDetailsContPrincipal(Object currency) {
    return 'Main account · $currency';
  }

  @override
  String get accountDetailsContIban => 'IBAN';

  @override
  String get accountDetailsCopiazaIbanUl => 'Copy IBAN';

  @override
  String get accountDetailsIbanUlFostCopiat => 'IBAN copied to clipboard';

  @override
  String get accountDetailsTitularCont => 'Account holder';

  @override
  String get accountDetailsCodBicSwift => 'BIC / SWIFT code';

  @override
  String get commonBanca => 'Bank';

  @override
  String get accountDetailsIntbankSRomania => 'INTBank S.A. Romania';

  @override
  String get accountDetailsMonedaCont => 'Account currency';

  @override
  String accountDetailsDateContIntbankTitular(Object holderName, Object iban) {
    return 'INTBank account details:\nHolder: $holderName\nIBAN: $iban\nBIC/SWIFT: INTBROBUXXX\nBank: INTBank Romania';
  }

  @override
  String get accountDetailsToateDateleContuluiAu =>
      'All account details copied for sharing';

  @override
  String get accountDetailsCopiazaDateleTransfer =>
      'Copy details for a transfer';

  @override
  String commonCopiaza(Object label) {
    return 'Copy $label';
  }

  @override
  String accountDetailsCopiat(Object label) {
    return '$label copied';
  }

  @override
  String get openCurrencyEuro => 'Euro';

  @override
  String get openCurrencyContCurentEuroPlati =>
      'Current account in euro for SEPA payments';

  @override
  String get openCurrencyDolarAmerican => 'US dollar';

  @override
  String get openCurrencyContCurentUsdTransferuri =>
      'Current account in USD for international transfers';

  @override
  String get openCurrencyLiraSterlina => 'British pound';

  @override
  String get openCurrencyContCurentGbpPlati =>
      'Current account in GBP for payments in the United Kingdom';

  @override
  String openCurrencyContulTauFostDeschis(Object selectedCurrency) {
    return 'Your $selectedCurrency account is open!';
  }

  @override
  String get openCurrencyContulPututFiDeschis =>
      'The account couldn\'t be opened.';

  @override
  String get openCurrencyDeschideContValutar => 'Open a currency account';

  @override
  String get openCurrencyAlegeMonedaDoritaSe =>
      'Choose a currency. A unique IBAN is created instantly, with no maintenance fees.';

  @override
  String get openCurrencyDeschide => 'Open';

  @override
  String get notificationsTranzactii => 'Transactions';

  @override
  String get notificationsSecuritate => 'Security';

  @override
  String get notificationsCentruNotificari => 'Notification centre';

  @override
  String get notificationsMarcheazaCitite => 'Mark all as read';

  @override
  String get notificationsNicioNotificareDisponibila => 'No notifications';

  @override
  String get notificationsNotificare => 'Notification';

  @override
  String get approvalVerificareCurs => 'Verification in progress';

  @override
  String get approvalOperatorVerificaDateleTale =>
      'An operator is checking your details right now';

  @override
  String get approvalAprobareCatevaMomente => 'Approval in a few moments...';

  @override
  String get approvalContVerificatSucces => 'Account verified!';

  @override
  String get approvalDateleTaleAuFost =>
      'Your details have been approved.\nYou\'ll be redirected in 5 seconds.';

  @override
  String get approvalVerificareCompleta => 'Verification complete';

  @override
  String get tosEroareVerificareaTos => 'Couldn\'t check the terms of service';

  @override
  String get tosEroareActualizareaTos =>
      'Couldn\'t update the terms of service';

  @override
  String get tosEroareVerificareaContului => 'Couldn\'t verify the account';

  @override
  String get tosSePoateConectaServer => 'Can\'t connect to the server';

  @override
  String get tosToateConturileDeschiseInt =>
      'All accounts opened with INT Bank must be registered with real and correct details.';

  @override
  String get tosFiecareClientPoateDetine =>
      'Each customer may hold only one personal account with INT Bank.';

  @override
  String get tosConturileInactiveMaiMult =>
      'Accounts inactive for more than 12 months may be temporarily suspended.';

  @override
  String get tosClientiiMinoriNecesitaConsimtamantul =>
      'Customers who are minors need the consent of their parents or guardians.';

  @override
  String get tosClientulTrebuieSaProtejeze =>
      'The customer must protect their sign-in details and passwords.';

  @override
  String get tosIntBankPoateSolicita =>
      'INT Bank may request additional documents for verification.';

  @override
  String get tosTranzactiileEfectuatePrinCont =>
      'Transactions made through the account are the customer\'s responsibility.';

  @override
  String get tosPartajareaConturilorAltePersoane =>
      'Sharing accounts with other people is strictly prohibited.';

  @override
  String get tosClientulTrebuieSaAccepte =>
      'The customer must accept these terms to open an account.';

  @override
  String get tosConturileNeregulatePotFi =>
      'Irregular accounts may be closed by INT Bank without prior notice.';

  @override
  String get tosClientulTrebuieSaRespecte =>
      'The customer must respect the bank\'s transaction limits and rules.';

  @override
  String get tosModificareaDatelorPersonaleTrebuie =>
      'Changes to personal details must be reported to INT Bank immediately.';

  @override
  String get tosDateleContuluiTrebuiePastrate =>
      'Account details must be kept confidential.';

  @override
  String get tosUtilizareaContuluiActivitatiIlegale =>
      'Using the account for illegal activities is prohibited.';

  @override
  String get tosIntBankRaspundePierderi =>
      'INT Bank is not liable for losses caused by the customer\'s negligence.';

  @override
  String get tosSuspendareaContuluiPoateFi =>
      'The account may be suspended for additional checks.';

  @override
  String get tosAccesulContPoateFi =>
      'Access to the account may be temporarily blocked if there is a security risk.';

  @override
  String get tosClientiiTrebuieSaPastreze =>
      'Customers must keep their passwords and PINs confidential.';

  @override
  String get tosIntBankVaSolicita =>
      'INT Bank will never ask for passwords by email or phone.';

  @override
  String get tosRaportatiImediatOriceActivitate =>
      'Report any suspicious activity to INT Bank immediately.';

  @override
  String get tosDispozitiveleFolositeAccesCont =>
      'Devices used to access the account must be secured.';

  @override
  String get tosAutentificareaDoiFactori2fa =>
      'Two-factor authentication (2FA) is recommended.';

  @override
  String get tosDatelePersonaleSuntProcesate =>
      'Personal data is processed in line with the INT Bank privacy policy.';

  @override
  String get tosEsteInterzisaDistribuireaMalware =>
      'Distributing malware or phishing through the app is prohibited.';

  @override
  String get tosClientiiTrebuieSaFoloseasca =>
      'Customers must use only official INT Bank channels.';

  @override
  String get tosMonitorizareaActivitatiiContuluiSe =>
      'Account activity is monitored for safety.';

  @override
  String get tosIntBankPoateIntroduce =>
      'INT Bank may introduce additional authentication for protection.';

  @override
  String get tosCazIncalcareSecuritatiiContul =>
      'If security is breached, the account may be temporarily blocked.';

  @override
  String get tosParoleleTrebuieSaFie => 'Passwords must be complex and unique.';

  @override
  String get tosCodurileSecuritateTrebuieDistribuite =>
      'Security codes must not be shared with other people.';

  @override
  String get tosDateleSensibileTrebuieStocate =>
      'Sensitive data must not be stored on public devices.';

  @override
  String get tosRaportareaPierderiiDispozitivuluiPrevine =>
      'Reporting a lost device helps prevent fraud.';

  @override
  String get tosIntBankPoateAudita =>
      'INT Bank may audit account security to prevent fraud.';

  @override
  String get tosPlatileEfectuatePrinInt =>
      'Payments made through INT Bank are final and irreversible without the bank\'s agreement.';

  @override
  String get tosClientulTrebuieSaVerifice =>
      'The customer must check the details before confirming a payment.';

  @override
  String get tosTranzactiileInternationaleSuntSupuse =>
      'International transactions are subject to the exchange rate.';

  @override
  String get tosIntBankPoateRefuza =>
      'INT Bank may decline suspicious transactions without notice.';

  @override
  String get tosClientiiTrebuieSaRespecte =>
      'Customers must respect the daily and monthly limits that apply.';

  @override
  String get tosTaxeleComisioaneleAplicabileSunt =>
      'The applicable fees and charges are those shown in the price list.';

  @override
  String get tosClientulEsteResponsabilPlata =>
      'The customer is responsible for paying all fees associated with the account.';

  @override
  String get tosTranzactiileSumeMariPot =>
      'Large transactions may be subject to additional checks.';

  @override
  String get tosPlatileAutomateTrebuieConfigurate =>
      'Automatic payments must be set up correctly following INT Bank\'s instructions.';

  @override
  String get tosTranzactiileFrauduloaseTrebuieRaportate =>
      'Fraudulent transactions must be reported immediately.';

  @override
  String get tosDocumenteleSuplimentarePotFi =>
      'Additional documents may be requested to validate payments.';

  @override
  String get tosClientulTrebuieSaPastreze =>
      'The customer must keep proof of payments made.';

  @override
  String get tosOriceEroareTranzactiePoate =>
      'Any transaction error may be investigated according to internal procedures.';

  @override
  String get tosIntBankPoateSuspenda =>
      'INT Bank may suspend transactions if irregularities are detected.';

  @override
  String get tosModificareaDatelorBancareTrebuie =>
      'Changes to bank details must be verified before a transfer.';

  @override
  String get tosIntBankPoateModifica =>
      'INT Bank may change these terms and conditions at any time.';

  @override
  String get tosNotificarileOficialeSuntComunicate =>
      'Official notices are sent through the app, by email or by SMS.';

  @override
  String get tosServiciilePotFiSuspendate =>
      'Services may be temporarily suspended for maintenance.';

  @override
  String get tosFunctionalitatileSuplimentarePotFi =>
      'Additional features may be introduced without notice.';

  @override
  String get tosProcedurileAutentificareSecuritatePot =>
      'Authentication and security procedures may be updated.';

  @override
  String get tosStructuraConturilorLimiteleConditiile =>
      'Account structure, limits and conditions may be changed.';

  @override
  String get tosClientiiTrebuieSaFoloseasca2 =>
      'Customers must use up-to-date versions of the app.';

  @override
  String get tosAccesulAnumiteFunctionalitatiPoate =>
      'Access to some features may be limited for non-compliance.';

  @override
  String get tosIntBankPoateSchimba =>
      'INT Bank may change the fees and charges it applies.';

  @override
  String get tosActualizarileVorFiAfisate =>
      'Updates will also be shown in the app.';

  @override
  String get tosLimiteleTranzactionarePotFi =>
      'Transaction limits may be adjusted.';

  @override
  String get tosClientiiTrebuieSaAccepte =>
      'Customers must accept changes to keep using the services.';

  @override
  String get tosSchimbarileMajoreVorFi =>
      'Major changes will be announced by official email.';

  @override
  String get tosFunctionalitatilePotFiSuspendate =>
      'Features may be temporarily suspended for upgrades.';

  @override
  String get tosActualizarileSecuritateSuntObligatorii =>
      'Security updates are mandatory for all users.';

  @override
  String get tosClientiiTrebuieSaRaporteze =>
      'Customers must report lost or stolen devices immediately.';

  @override
  String get tosClientulTrebuieSaActualizeze =>
      'The customer must update their personal information when it changes.';

  @override
  String get tosClientiiTrebuieSaRespecte2 =>
      'Customers must comply with local laws on financial transactions.';

  @override
  String get tosSePoateFolosiAplicatia =>
      'The app must not be used for illegal purposes.';

  @override
  String get tosRespectareaRegulilorPublicitatePromovare =>
      'Compliance with the rules on advertising and promoting services is mandatory.';

  @override
  String get tosLitigiilePrivindConturileVor =>
      'Disputes about accounts will be resolved according to the law.';

  @override
  String get tosClientiiSuntResponsabiliToate =>
      'Customers are responsible for all the data they enter and for keeping it confidential.';

  @override
  String get tosIntBankGaranteazaDisponibilitatea =>
      'INT Bank does not guarantee uninterrupted availability of its services.';

  @override
  String get tosClientulTrebuieSaRespecte2 =>
      'The customer must comply with fraud-prevention requirements.';

  @override
  String get tosVerificareaPeriodicaExtraselorCont =>
      'Regularly checking account statements is the customer\'s responsibility.';

  @override
  String get tosRespectareaLimitelorRetragereTransfer =>
      'Respecting the withdrawal and transfer limits set by INT Bank is mandatory.';

  @override
  String get tosVerificareaCorectitudiniiDatelorAplicatie =>
      'Checking that the data in the app is correct is the customer\'s responsibility.';

  @override
  String get tosProtejareaDispozitivelorAplicatieiInt =>
      'Protecting your devices and the INT Bank app is mandatory.';

  @override
  String get tosEsteInterzisaFolosireaConturilor =>
      'Using accounts for commercial activities without approval is prohibited.';

  @override
  String get tosRespectareaTermenelorPlataServiciile =>
      'Meeting the payment deadlines for associated services is the customer\'s responsibility.';

  @override
  String get tosIntBankColecteazaProceseaza =>
      'INT Bank collects and processes personal data in accordance with the law.';

  @override
  String get tosClientulTrebuieSaAccepte2 =>
      'The customer must accept the INT Bank privacy policy.';

  @override
  String get tosDateleSensibileTrebuieDistribuite =>
      'Sensitive data must not be shared with unauthorised third parties.';

  @override
  String get tosClientiiAuDreptulSolicita =>
      'Customers have the right to request deletion of their personal data.';

  @override
  String get tosDatelePotFiFolosite =>
      'Data may be used for personalised services and offers.';

  @override
  String get tosToateDateleSuntStocate =>
      'All data is stored securely and encrypted.';

  @override
  String get tosClientiiTrebuieSaRaporteze2 =>
      'Customers must report unauthorised access to data.';

  @override
  String get tosIntBankPoateProcesa =>
      'INT Bank may process anonymised data for internal statistics.';

  @override
  String get tosFolosireaDatelorAltorClienti =>
      'Using other customers\' data without consent is prohibited.';

  @override
  String get tosAcceptareaCookieUrilorTermenilor =>
      'Accepting cookies and the data-processing terms is mandatory.';

  @override
  String get tosModificarilePoliticiiConfidentialitateVor =>
      'Changes to the privacy policy will be announced in the app.';

  @override
  String get tosClientiiTrebuieSaAccepte2 =>
      'Customers must accept the terms to keep using the app.';

  @override
  String get tosDateleColectateSuntFolosite =>
      'The data collected is used for lawful purposes only.';

  @override
  String get tosIntBankPoateBloca =>
      'INT Bank may block the account if the data policy is breached.';

  @override
  String get tosClientiiTrebuieSaMentina =>
      'Customers must keep their personal information up to date.';

  @override
  String get tosIntBankEsteResponsabila =>
      'INT Bank is not liable for losses caused by customer errors.';

  @override
  String get tosSeGaranteazaDisponibilitateaNeintrerupta =>
      'Uninterrupted availability of the services is not guaranteed.';

  @override
  String get tosIntBankRaspundeIntarzieri =>
      'INT Bank is not liable for delays caused by third parties.';

  @override
  String get tosClientiiSuntResponsabiliProtectia =>
      'Customers are responsible for protecting their devices and accounts.';

  @override
  String get tosServiciilePotFiSuspendate2 =>
      'Services may be suspended in an emergency or in case of failure.';

  @override
  String get tosRespectareaInstructiunilorUtilizareEste =>
      'Following the usage instructions is the customer\'s responsibility.';

  @override
  String get tosIntBankRaspundePierderi2 =>
      'INT Bank is not liable for losses caused by external fraud.';

  @override
  String get tosServiciileSuntFurnizateAsa =>
      'The services are provided as is, without additional guarantees.';

  @override
  String get tosIntBankGaranteazaExactitatea =>
      'INT Bank does not guarantee the accuracy of third-party information.';

  @override
  String get tosClientiiTrebuieSaVerifice =>
      'Customers must regularly check their statements for errors.';

  @override
  String get tosAccesulContPoateFi2 =>
      'Access to the account may be limited if there is a security risk.';

  @override
  String get tosClientiiSuntResponsabiliFolosirea =>
      'Customers are responsible for using the app in accordance with the law.';

  @override
  String get tosIntBankPoateAjusta =>
      'INT Bank may adjust the liability terms by giving notice.';

  @override
  String get tosClientiiTrebuieSaAccepte3 =>
      'Customers must accept the terms to keep using the services.';

  @override
  String get tosIntBankPoateSuspenda2 =>
      'INT Bank may suspend or restrict accounts that breach the terms.';

  @override
  String get tosConturileTrebuieSaRespecte =>
      'Accounts must comply with local tax rules.';

  @override
  String get tosIntBankEsteResponsabil =>
      'INT Bank is not liable for losses caused by third parties.';

  @override
  String get tosClientiiTrebuieSaUtilizeze =>
      'Customers must use only official INT Bank channels.';

  @override
  String get tosDisputePrivindTranzactiileVor =>
      'Transaction disputes will be investigated according to internal procedures.';

  @override
  String get tosClientiiTrebuieSaRespecte3 =>
      'Customers must comply with the security requirements.';

  @override
  String get tosConturileInactiveNedeclaratePot =>
      'Inactive or undeclared accounts may be deactivated.';

  @override
  String get tosFolosireaAplicatieiImplicaAcordul =>
      'Using the app means agreeing to all INT Bank rules.';

  @override
  String get tosIntBankPoateIntroduce2 =>
      'INT Bank may introduce new features and services.';

  @override
  String get tosNerespectareaTermenilorPoateDuce =>
      'Failing to comply with the terms may lead to the account being suspended.';

  @override
  String get tosClientiiTrebuieSaRespecte4 =>
      'Customers must follow all notices from INT Bank.';

  @override
  String get tosModificarileLegislativePotInfluenta =>
      'Changes in legislation may affect the rules that apply.';

  @override
  String get tosClientulTrebuieSaConsulte =>
      'The customer should check the app regularly for updates.';

  @override
  String get tosIntBankPoateModifica2 =>
      'INT Bank may change the terms to protect customers.';

  @override
  String get tosClientiiSuntResponsabiliRespectarea =>
      'Customers are responsible for following the app\'s rules.';

  @override
  String get tosToateTaxeleAplicateContului =>
      'All fees applied to the account will be shown transparently in the app.';

  @override
  String get tosIntBankPoateModifica3 =>
      'INT Bank may change its charges with prior notice.';

  @override
  String get tosTaxeleTranzactiileInternationalePot =>
      'Fees for international transactions may vary with the exchange rate.';

  @override
  String get tosClientulEsteResponsabilPlata2 =>
      'The customer is responsible for paying all fees related to the account.';

  @override
  String get tosTaxelePotFiPercepute =>
      'Fees may be charged for withdrawals, transfers and additional services.';

  @override
  String get tosIntBankPoateSuspenda3 =>
      'INT Bank may suspend the account if applicable fees are not paid.';

  @override
  String get tosClientiiTrebuieSaConsulte =>
      'Customers should consult the bank\'s current price list.';

  @override
  String get tosReduceriPromotiiPotFi =>
      'Discounts and promotions may only be applied according to INT Bank\'s rules.';

  @override
  String get tosTaxelePerceputeTertiTransferuri =>
      'Fees charged by third parties for external transfers are the customer\'s responsibility.';

  @override
  String get tosSchimbarileTaxeVorFi =>
      'Fee changes will be announced in the app and by email.';

  @override
  String get tosComisioaneleServiciiSpecialeSunt =>
      'Charges for special services are shown separately.';

  @override
  String get tosIntBankPoateAjusta2 =>
      'INT Bank may adjust fee limits depending on the account.';

  @override
  String get tosTaxeleSuplimentareTranzactiiUrgente =>
      'Additional fees may be charged for urgent transactions.';

  @override
  String get tosClientulTrebuieSaAccepte3 =>
      'The customer must accept the fees to keep using the service.';

  @override
  String get tosNeplataTaxelorPoateDuce =>
      'Not paying fees may lead to account features being suspended.';

  @override
  String get tosIntBankPoateRezilia =>
      'INT Bank may terminate the account if the terms are breached.';

  @override
  String get tosSuspendareaContuluiPoateFi2 =>
      'Account suspension may be temporary or permanent.';

  @override
  String get tosClientiiVorFiNotificati =>
      'Customers will be notified through the app or by official email.';

  @override
  String get tosReziliereaContuluiElibereazaClientul =>
      'Closing the account does not release the customer from financial obligations.';

  @override
  String get tosIntBankPoateInchide =>
      'INT Bank may close the account for illegal activities.';

  @override
  String get tosSuspendareaContuluiSePoate =>
      'The account may be suspended for additional checks.';

  @override
  String get tosConturileInactiveTermenLung =>
      'Accounts inactive for a long time may be deactivated automatically.';

  @override
  String get tosReziliereaContuluiAfecteazaTranzactiile =>
      'Closing the account does not affect transactions already made.';

  @override
  String get tosClientiiTrebuieSaCoopereze =>
      'Customers must cooperate in closing the account according to the procedures.';

  @override
  String get tosIntBankPoateSuspenda4 =>
      'INT Bank may suspend services if there is a security risk.';

  @override
  String get tosReactivareaContuluiPoateFi =>
      'Reactivating the account may only be requested according to the bank\'s rules.';

  @override
  String get tosClientiiTrebuieSaIsi =>
      'Customers must withdraw their funds before the account is closed.';

  @override
  String get tosOriceLitigiuLegatContul =>
      'Any dispute about a suspended account will be resolved according to the law.';

  @override
  String get tosSuspendareaTemporaraPoateFi =>
      'The bank may decide on a temporary suspension for maintenance or upgrades.';

  @override
  String get tosReziliereaContuluiSeRealizeaza =>
      'The account is closed only after all procedures have been completed.';

  @override
  String get tosTermeniConditii => 'Terms and Conditions';

  @override
  String get tosSeProceseaza => 'Processing...';

  @override
  String get tosSuntAcord => 'I agree';

  @override
  String get splashSPututRealizaConexiunea =>
      'Couldn\'t connect to the server. Waiting for a connection...';

  @override
  String get statement3Luni => '3 months';

  @override
  String get statement6Luni => '6 months';

  @override
  String get statement1An => '1 year';

  @override
  String get statementPersonalizat => 'Custom';

  @override
  String get statementSPututIncarcaExtrasul =>
      'Couldn\'t load the account statement.';

  @override
  String statementExtrasulPdfFostGenerat(Object startDate, Object endDate) {
    return 'PDF statement ($startDate - $endDate) created!';
  }

  @override
  String get statementPdfUlPututFi => 'Couldn\'t download the PDF.';

  @override
  String get statementExtrasCont => 'Account statement';

  @override
  String statementPerioada(Object startDate, Object endDate) {
    return 'Period: $startDate - $endDate';
  }

  @override
  String get statementSeGenereazaPdf => 'Creating PDF...';

  @override
  String get statementDescarcaExtrasPdf => 'Download PDF statement';

  @override
  String get statementSoldInitial => 'OPENING BALANCE';

  @override
  String get statementSoldFinal => 'CLOSING BALANCE';

  @override
  String get statementIncasari => 'MONEY IN (+)';

  @override
  String get statementPlati => 'MONEY OUT (-)';

  @override
  String statementOperatiuni(Object transactions) {
    return 'TRANSACTIONS ($transactions)';
  }

  @override
  String get statementAtingeTranzactieDetalii =>
      'Tap a transaction for details';

  @override
  String get statementNicioOperatiuneAceastaPerioada =>
      'No transactions in this period';

  @override
  String get historyToate => 'All';

  @override
  String get historyIntrari => 'Money in (+)';

  @override
  String get historyIesiri => 'Money out (-)';

  @override
  String get historyLunaCurenta => 'This month';

  @override
  String get historySPututIncarcaIstoricul =>
      'Couldn\'t load your transaction history.';

  @override
  String get historyIstoricTranzactii => 'Transaction history';

  @override
  String get historyCautaComerciantDescriere =>
      'Search merchant, description...';

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
      'No transactions match your search.';

  @override
  String get commonTransferBancar => 'Bank transfer';

  @override
  String get txDetailsDovadaPlata => 'Proof of payment';

  @override
  String get txDetailsFinalizata => 'Completed';

  @override
  String get commonProcesare => 'Processing';

  @override
  String get txDetailsDataOra => 'Date & time';

  @override
  String get txDetailsReferintaTranzactie => 'Transaction reference';

  @override
  String get txDetailsTipOperatiune => 'Type';

  @override
  String get txDetailsPlataTransferTrimis => 'Payment / Transfer sent';

  @override
  String get txDetailsIncasareTransferPrimit => 'Money in / Transfer received';

  @override
  String get txDetailsContExpeditorIban => 'Sender account (IBAN)';

  @override
  String get txDetailsContBeneficiarIban => 'Beneficiary account (IBAN)';

  @override
  String txDetailsTranzactieIntbankSumaData(
    Object trackingId,
    Object signedAmount,
    Object date,
  ) {
    return 'INTBank transaction: $trackingId | Amount: $signedAmount | Date: $date';
  }

  @override
  String get txDetailsDetaliileTranzactieiAuFost =>
      'Transaction details copied';

  @override
  String get txDetailsCopiaza => 'Copy';

  @override
  String txDetailsFostCopiatClipboard(Object label) {
    return '$label copied to clipboard';
  }

  @override
  String get scheduledSAuPututIncarca =>
      'Couldn\'t load your scheduled payments.';

  @override
  String get scheduledPlataProgramataFostAnulata =>
      'Scheduled payment cancelled.';

  @override
  String get scheduledPlataProgramataPututFi =>
      'Couldn\'t cancel the scheduled payment.';

  @override
  String get scheduledAnuleziPlataRecurenta => 'Cancel this recurring payment?';

  @override
  String scheduledPlataCatreVaMai(Object amount, Object beneficiary) {
    return 'The payment of $amount to $beneficiary will no longer be made.';
  }

  @override
  String get scheduledAnuleazaPlata => 'Cancel payment';

  @override
  String get scheduledPastreaza => 'Keep';

  @override
  String get commonSaptamanal => 'Weekly';

  @override
  String get commonLunar => 'Monthly';

  @override
  String get scheduledSinguraData => 'One time';

  @override
  String get scheduledPlatiProgramate => 'Scheduled payments';

  @override
  String get scheduledNicioPlataProgramata => 'No scheduled payments';

  @override
  String get scheduledPotiSetaPlatiRecurente =>
      'You can set up recurring or future payments from the transfer screen by turning on \"Schedule payment\".';

  @override
  String get scheduledBeneficiar => 'Beneficiary';

  @override
  String commonDetalii(Object reason) {
    return 'Details: $reason';
  }

  @override
  String scheduledUrmatoarea(Object nextRun) {
    return 'Next: $nextRun';
  }

  @override
  String get receiptPlataProgramata => 'Payment scheduled';

  @override
  String get receiptTransferEfectuat => 'Transfer complete';

  @override
  String get receiptTransferProcesare => 'Transfer processing';

  @override
  String get receiptProgramata => 'Scheduled';

  @override
  String get receiptFinalizat => 'Completed';

  @override
  String receiptIntBank(Object title) {
    return 'INT Bank - $title';
  }

  @override
  String receiptSuma(Object amount) {
    return 'Amount: $amount';
  }

  @override
  String receiptBeneficiar(Object beneficiaryName) {
    return 'Beneficiary: $beneficiaryName';
  }

  @override
  String receiptIbanBeneficiar(Object toIban) {
    return 'Beneficiary IBAN: $toIban';
  }

  @override
  String receiptData(Object createdAt) {
    return 'Date: $createdAt';
  }

  @override
  String receiptProgramare(Object scheduleSummary) {
    return 'Schedule: $scheduleSummary';
  }

  @override
  String receiptIdTranzactie(Object trackingId) {
    return 'Transaction ID: $trackingId';
  }

  @override
  String receiptCatre(Object beneficiaryName) {
    return 'to $beneficiaryName';
  }

  @override
  String get receiptBancaProceseazaTransferulVei =>
      'The bank is processing your transfer. You\'ll get a notification when it\'s complete.';

  @override
  String get receiptDetaliileAuFostCopiate => 'Details copied.';

  @override
  String get receiptCopiazaDetaliile => 'Copy details';

  @override
  String get receiptGata => 'Done';

  @override
  String get commonTransferNou => 'New transfer';

  @override
  String get receiptStatus => 'Status';

  @override
  String get receiptData2 => 'Date';

  @override
  String get commonProgramare => 'Schedule';

  @override
  String get commonContul => 'From account';

  @override
  String get receiptCatre2 => 'To';

  @override
  String get commonDetaliiPlata => 'Payment details';

  @override
  String get receiptIdTranzactie2 => 'Transaction ID';

  @override
  String get transferData => 'Once';

  @override
  String transferDin(Object frequency, Object scheduledDate) {
    return '$frequency, from $scheduledDate';
  }

  @override
  String get transferEroareTransfer => 'Transfer failed';

  @override
  String get transferTransferulPututFiEfectuat =>
      'The transfer couldn\'t be made. Please try again.';

  @override
  String get transferCompleteazaDateleEfectuaTransferul =>
      'Fill in the details to make a transfer';

  @override
  String get transferDestinatar => 'RECIPIENT';

  @override
  String get transferProgramate => 'Scheduled';

  @override
  String get transferAgenda => 'Contacts';

  @override
  String get transferIbanDestinatar => 'Recipient IBAN';

  @override
  String get transferNumeBeneficiar => 'Beneficiary name';

  @override
  String get transferPopescuIon => 'John Smith';

  @override
  String transferSuma(Object currency) {
    return 'Amount ($currency)';
  }

  @override
  String transferDisponibil(Object availableBalance) {
    return 'Available: $availableBalance';
  }

  @override
  String get transferMotivTransfer => 'Payment reference';

  @override
  String get transferPlataFacturaRambursareEtc => 'Bill payment, refund, etc.';

  @override
  String get transferSalveazaDestinatarulAgendaPlati =>
      'Save recipient to contacts';

  @override
  String get transferProgramarePlataRecurenta => 'Schedule payment / Recurring';

  @override
  String get transferFrecventaExecutie => 'Frequency';

  @override
  String transferDataExecutiei(Object scheduledDate) {
    return 'Payment date: $scheduledDate';
  }

  @override
  String get transferSchimbaData => 'Change date';

  @override
  String get transferProgrameazaTransferul => 'Schedule transfer';

  @override
  String get transferTransferaAcum => 'Send now';

  @override
  String get transferDisponibil2 => 'Available';

  @override
  String get transferValidationIntroduIbanUlDestinatarului =>
      'Enter the recipient\'s IBAN.';

  @override
  String get transferValidationIbanUlIncepeCodul =>
      'An IBAN starts with the country code and two digits (e.g. RO49).';

  @override
  String get transferValidationIbanUlPoateContine =>
      'An IBAN can contain only letters and digits.';

  @override
  String get transferValidationIbanUlAreLungime =>
      'The IBAN has an incorrect length.';

  @override
  String get transferValidationAcestaEsteContulCare =>
      'This is the account you\'re paying from. Choose another recipient.';

  @override
  String transferValidationIbanRomanescAre24(Object c) {
    return 'A Romanian IBAN has 24 characters (you entered $c).';
  }

  @override
  String get transferValidationIbanUlEsteValid =>
      'This IBAN isn\'t valid. Check that you copied every character correctly.';

  @override
  String get transferValidationIntroduNumeleBeneficiarului =>
      'Enter the beneficiary\'s name.';

  @override
  String get transferValidationNumeleEstePreaScurt => 'The name is too short.';

  @override
  String transferValidationNumelePoateAveaCel(Object maxNameLength) {
    return 'The name can have at most $maxNameLength characters.';
  }

  @override
  String get transferValidationNumeleTrebuieSaContina =>
      'The name must contain letters.';

  @override
  String get transferValidationIntroduSumaMaiMare =>
      'Enter an amount greater than 0.';

  @override
  String transferValidationSoldInsuficientDisponibil(Object available) {
    return 'Insufficient balance. Available: $available.';
  }

  @override
  String get transferValidationDescrieScurtPlataEx =>
      'Briefly describe the payment (e.g. \"October rent\").';

  @override
  String get transferValidationDetaliilePlatiiTrebuieSa =>
      'Payment details must be at least 3 characters.';

  @override
  String transferValidationDetaliilePotAveaCel(Object maxReasonLength) {
    return 'Details can have at most $maxReasonLength characters.';
  }

  @override
  String get beneficiariesBeneficiariSalvati => 'Saved beneficiaries';

  @override
  String beneficiariesContacte(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '$count contact',
    );
    return '$_temp0';
  }

  @override
  String get beneficiariesCautaDupaNumeIban => 'Search by name or IBAN...';

  @override
  String get beneficiariesNiciunBeneficiarSalvatInca =>
      'You haven\'t saved any beneficiaries yet';

  @override
  String get beneficiariesNiciunRezultatGasit => 'No results found';

  @override
  String get transferConfirmVerificareTransfer => 'Review transfer';

  @override
  String get transferConfirmVerificaDetaliilePlatiiInainte =>
      'Check the payment details before sending';

  @override
  String get transferConfirmSumaTransferat => 'AMOUNT TO SEND';

  @override
  String transferConfirmComisionTransferGratuit(Object currency) {
    return 'Fee: $currency • Free transfer';
  }

  @override
  String get transferConfirmDestinatar => 'Recipient';

  @override
  String get transferConfirmBancaBeneficiar => 'Beneficiary bank';

  @override
  String get transferConfirmBancaComerciala => 'Commercial bank';

  @override
  String get transferConfirmIbanDestinatie => 'Destination IBAN';

  @override
  String get transferConfirmPlataVaFiExecutata =>
      'The payment will be made automatically. You can cancel it at any time from \"Scheduled payments\".';

  @override
  String get transferConfirmVerificaIbanUlSuma =>
      'Check the IBAN and amount. Once confirmed, the transfer is sent immediately and can\'t be cancelled in the app.';

  @override
  String get transferConfirmConfirmaProgramarea => 'Confirm schedule';

  @override
  String get transferConfirmConfirmaTransferul => 'Confirm transfer';

  @override
  String get transferConfirmModificaDetaliile => 'Edit details';

  @override
  String get welcomeSalutBineVenitInt => 'Hello, and welcome to INT Bank!';

  @override
  String get welcomeEstiDejaClient => 'Already a customer of ';

  @override
  String get welcomeContinua => '? Continue with ';

  @override
  String get welcomeConecteaza => 'Sign in';

  @override
  String get welcomeDacaCont => '.\n\nIf you don\'t have an account, ';

  @override
  String get welcomePotiDeveniClientDirect =>
      'you can become a customer right here in the app';

  @override
  String get welcomeEste => '.\n\nIt\'s ';

  @override
  String get welcomeRapidSigur => 'quick and secure';

  @override
  String get welcomeIarTuVeiAvea =>
      ', and you\'ll have access to all your bank account features ';

  @override
  String get welcomeInstantDistanta => 'instantly and remotely';

  @override
  String get welcomeInregistreaza => 'Sign up';

  @override
  String get welcomeDejaCont => 'Already have an account? ';

  @override
  String get routerPaginaSolicitataFostGasita =>
      'The page you asked for wasn\'t found. Taking you to the home screen...';

  @override
  String commonSeProceseaza(Object label) {
    return '$label, processing';
  }

  @override
  String get commonRenunta => 'Cancel';

  @override
  String get commonPrefixTara => 'Country code';

  @override
  String get commonSelecteazaData => 'Select date';

  @override
  String get commonReincearca => 'Try again';

  @override
  String commonCifreIntroduse(Object length, Object totalDots) {
    return '$length of $totalDots digits entered';
  }

  @override
  String commonCifra(Object d) {
    return 'Digit $d';
  }

  @override
  String get commonStergeUltimaCifra => 'Delete last digit';

  @override
  String commonPasul(Object currentStep, Object totalSteps) {
    return 'Step $currentStep of $totalSteps';
  }

  @override
  String get statement30Zile => '30 days';

  @override
  String get commonNeselectata => 'not selected';

  @override
  String analyticsCategoryCount(int count, String percent) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '$count transaction',
    );
    return '$_temp0 • $percent';
  }

  @override
  String historyResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions found',
      one: '$count transaction found',
    );
    return '$_temp0';
  }

  @override
  String get pinEroareAutentificareIncearcaNou =>
      'Sign-in failed. Please try again.';

  @override
  String get pinEroarePotiConectaServer =>
      'Error: can\'t connect to the server';

  @override
  String get pinPotiConectaServerIncearca =>
      'Can\'t connect to the server. Please try again.';

  @override
  String get pinPinUrileCoincid => 'The PINs don\'t match';

  @override
  String get registerPotiConectaServerVerifica =>
      'Can\'t connect to the server. Check your connection';

  @override
  String get twoFactorEroareObtinereaTokenuluiClient =>
      'Couldn\'t start a secure session';

  @override
  String get twoFactorCodulPututFiTrimis =>
      'The code couldn\'t be sent. Tap \"Resend\" and try again.';

  @override
  String get twoFactorSesiuneExpirataRugamSa =>
      'Session expired. Please sign in again';

  @override
  String exchangeContActiv(Object fromCurrency) {
    return 'You don\'t have an active $fromCurrency account.';
  }

  @override
  String get exchangeIntroduSumaValidaSchimb =>
      'Enter a valid amount to exchange';

  @override
  String exchangeFonduriInsuficienteDisponibil(Object available) {
    return 'Insufficient funds! Available: $available';
  }

  @override
  String get exchangeEroareRealizareaSchimbuluiValutar =>
      'The currency exchange couldn\'t be completed';

  @override
  String get openCurrencyEroareDeschidereaContului =>
      'Couldn\'t open the account';

  @override
  String get transferEroareProgramareaPlatii =>
      'Couldn\'t schedule the payment';

  @override
  String get transferEroareEfectuareaTransferului =>
      'The transfer couldn\'t be made';

  @override
  String commonTxIncomingSemantics(
    String beneficiary,
    String date,
    String amount,
  ) {
    return 'Money in: $beneficiary, $date, $amount';
  }

  @override
  String commonTxOutgoingSemantics(
    String beneficiary,
    String date,
    String amount,
  ) {
    return 'Payment: $beneficiary, $date, $amount';
  }
}
