import 'dart:convert' show jsonDecode;
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;
import '../../../widgets/app_logo.dart';
import '../../../theme/app_tokens.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/helpers.dart';
import '../../../core/network/dio_client.dart';
import 'approval_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../welcome/welcome_screen.dart';
import '../../../l10n/l10n.dart';

class TosScreen extends StatefulWidget
{
  final int userId;
  const TosScreen({super.key, required this.userId});

  @override
  State<TosScreen> createState() => _TosScreenState();
}

class _TosScreenState extends State<TosScreen>
{
  final ScrollController _scrollController = ScrollController();
  bool _canAccept = false;
  bool _loading = false;

  Future<String> getDeviceId() async
  {
    final deviceInfo = DeviceInfoPlugin();
    if(Platform.isAndroid)
    {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    else if(Platform.isIOS)
    {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor!;
    }
    return 'unknown-device';
  }

  Future<void> _acceptTerms() async
  {
    if(!mounted) return;
    setState(() => _loading = true);

    try
    {
      final deviceId = await getDeviceId();
      final tokenResponse = await DioClient().post(
        '/auth/get-client-token',
        data: {'deviceId': deviceId},
      );

      if(!mounted) return;
      final tokenData = tokenResponse.data is Map<String, dynamic>
          ? tokenResponse.data as Map<String, dynamic>
          : jsonDecode(tokenResponse.data.toString()) as Map<String, dynamic>;
      final clientToken = tokenData['client_token'];
      final authOptions = Options(headers: {'Authorization': 'Bearer $clientToken'});

      final tosResponse = await DioClient().get(
        '/users/${widget.userId}/has-tos',
        options: authOptions,
      );

      if(!mounted) return;
      if(tosResponse.statusCode != 200)
      {
        showErrorSnackBar(context, context.l10n.tosEroareVerificareaTos);
        return;
      }

      final tosData = tosResponse.data is Map<String, dynamic>
          ? tosResponse.data as Map<String, dynamic>
          : jsonDecode(tosResponse.data.toString()) as Map<String, dynamic>;
      final acceptedTerms = tosData['termeniAcceptati'] ?? false;

      if(!acceptedTerms)
      {
        final putResponse = await DioClient().put(
          '/users/${widget.userId}/accept-tos',
          options: authOptions,
        );
        if(!mounted) return;
        if(putResponse.statusCode != 200)
        {
          showErrorSnackBar(context, context.l10n.tosEroareActualizareaTos);
          return;
        }
      }

      final approvedResponse = await DioClient().get(
        '/users/${widget.userId}/has-approved/',
        options: authOptions,
      );

      if(!mounted) return;
      if(approvedResponse.statusCode != 200)
      {
        showErrorSnackBar(context, context.l10n.tosEroareVerificareaContului);
        return;
      }

      final approvedData = approvedResponse.data is Map<String, dynamic>
          ? approvedResponse.data as Map<String, dynamic>
          : jsonDecode(approvedResponse.data.toString()) as Map<String, dynamic>;
      final isApproved = approvedData['contaprobat'] ?? false;

      if(!isApproved)
      {
        if(mounted)
        {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        }
      }
      else
      {
        if(mounted)
        {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    }
    catch (e)
    {
      if(mounted)
      {
        showErrorSnackBar(context, context.l10n.tosSePoateConectaServer);
      }
    }
    finally
    {
      if(mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, List<String>>> get chapters => [
    {
      "1. Despre conturi": [
        context.l10n.tosToateConturileDeschiseInt,
        context.l10n.tosFiecareClientPoateDetine,
        context.l10n.tosConturileInactiveMaiMult,
        context.l10n.tosClientiiMinoriNecesitaConsimtamantul,
        context.l10n.tosClientulTrebuieSaProtejeze,
        context.l10n.tosIntBankPoateSolicita,
        context.l10n.tosTranzactiileEfectuatePrinCont,
        context.l10n.tosPartajareaConturilorAltePersoane,
        context.l10n.tosClientulTrebuieSaAccepte,
        context.l10n.tosConturileNeregulatePotFi,
        context.l10n.tosClientulTrebuieSaRespecte,
        context.l10n.tosModificareaDatelorPersonaleTrebuie,
        context.l10n.tosDateleContuluiTrebuiePastrate,
        context.l10n.tosUtilizareaContuluiActivitatiIlegale,
        context.l10n.tosIntBankRaspundePierderi,
        context.l10n.tosSuspendareaContuluiPoateFi,
        context.l10n.tosAccesulContPoateFi,
      ],
    },
    {
      "2. Securitate și confidențialitate": [
        context.l10n.tosClientiiTrebuieSaPastreze,
        context.l10n.tosIntBankVaSolicita,
        context.l10n.tosRaportatiImediatOriceActivitate,
        context.l10n.tosDispozitiveleFolositeAccesCont,
        context.l10n.tosAutentificareaDoiFactori2fa,
        context.l10n.tosDatelePersonaleSuntProcesate,
        context.l10n.tosEsteInterzisaDistribuireaMalware,
        context.l10n.tosClientiiTrebuieSaFoloseasca,
        context.l10n.tosMonitorizareaActivitatiiContuluiSe,
        context.l10n.tosIntBankPoateIntroduce,
        context.l10n.tosCazIncalcareSecuritatiiContul,
        context.l10n.tosParoleleTrebuieSaFie,
        context.l10n.tosCodurileSecuritateTrebuieDistribuite,
        context.l10n.tosDateleSensibileTrebuieStocate,
        context.l10n.tosRaportareaPierderiiDispozitivuluiPrevine,
        context.l10n.tosIntBankPoateAudita,
      ],
    },
    {
      "3. Tranzacții și plăți": [
        context.l10n.tosPlatileEfectuatePrinInt,
        context.l10n.tosClientulTrebuieSaVerifice,
        context.l10n.tosTranzactiileInternationaleSuntSupuse,
        context.l10n.tosIntBankPoateRefuza,
        context.l10n.tosClientiiTrebuieSaRespecte,
        context.l10n.tosTaxeleComisioaneleAplicabileSunt,
        context.l10n.tosClientulEsteResponsabilPlata,
        context.l10n.tosTranzactiileSumeMariPot,
        context.l10n.tosPlatileAutomateTrebuieConfigurate,
        context.l10n.tosTranzactiileFrauduloaseTrebuieRaportate,
        context.l10n.tosDocumenteleSuplimentarePotFi,
        context.l10n.tosClientulTrebuieSaPastreze,
        context.l10n.tosOriceEroareTranzactiePoate,
        context.l10n.tosIntBankPoateSuspenda,
        context.l10n.tosModificareaDatelorBancareTrebuie,
      ],
    },
    {
      "4. Modificări ale serviciilor": [
        context.l10n.tosIntBankPoateModifica,
        context.l10n.tosNotificarileOficialeSuntComunicate,
        context.l10n.tosServiciilePotFiSuspendate,
        context.l10n.tosFunctionalitatileSuplimentarePotFi,
        context.l10n.tosProcedurileAutentificareSecuritatePot,
        context.l10n.tosStructuraConturilorLimiteleConditiile,
        context.l10n.tosClientiiTrebuieSaFoloseasca2,
        context.l10n.tosAccesulAnumiteFunctionalitatiPoate,
        context.l10n.tosIntBankPoateSchimba,
        context.l10n.tosActualizarileVorFiAfisate,
        context.l10n.tosLimiteleTranzactionarePotFi,
        context.l10n.tosClientiiTrebuieSaAccepte,
        context.l10n.tosSchimbarileMajoreVorFi,
        context.l10n.tosFunctionalitatilePotFiSuspendate,
        context.l10n.tosActualizarileSecuritateSuntObligatorii,
      ],
    },
    {
      "5. Obligații clientului": [
        context.l10n.tosClientiiTrebuieSaRaporteze,
        context.l10n.tosClientulTrebuieSaActualizeze,
        context.l10n.tosClientiiTrebuieSaRespecte2,
        context.l10n.tosSePoateFolosiAplicatia,
        context.l10n.tosRespectareaRegulilorPublicitatePromovare,
        context.l10n.tosLitigiilePrivindConturileVor,
        context.l10n.tosClientiiSuntResponsabiliToate,
        context.l10n.tosIntBankGaranteazaDisponibilitatea,
        context.l10n.tosClientulTrebuieSaRespecte2,
        context.l10n.tosVerificareaPeriodicaExtraselorCont,
        context.l10n.tosRespectareaLimitelorRetragereTransfer,
        context.l10n.tosVerificareaCorectitudiniiDatelorAplicatie,
        context.l10n.tosProtejareaDispozitivelorAplicatieiInt,
        context.l10n.tosEsteInterzisaFolosireaConturilor,
        context.l10n.tosRespectareaTermenelorPlataServiciile,
      ],
    },
    {
      "6. Protecția datelor": [
        context.l10n.tosIntBankColecteazaProceseaza,
        context.l10n.tosClientulTrebuieSaAccepte2,
        context.l10n.tosDateleSensibileTrebuieDistribuite,
        context.l10n.tosClientiiAuDreptulSolicita,
        context.l10n.tosDatelePotFiFolosite,
        context.l10n.tosToateDateleSuntStocate,
        context.l10n.tosClientiiTrebuieSaRaporteze2,
        context.l10n.tosIntBankPoateProcesa,
        context.l10n.tosFolosireaDatelorAltorClienti,
        context.l10n.tosAcceptareaCookieUrilorTermenilor,
        context.l10n.tosModificarilePoliticiiConfidentialitateVor,
        context.l10n.tosClientiiTrebuieSaAccepte2,
        context.l10n.tosDateleColectateSuntFolosite,
        context.l10n.tosIntBankPoateBloca,
        context.l10n.tosClientiiTrebuieSaMentina,
      ],
    },
    {
      "7. Limitarea răspunderii": [
        context.l10n.tosIntBankEsteResponsabila,
        context.l10n.tosSeGaranteazaDisponibilitateaNeintrerupta,
        context.l10n.tosIntBankRaspundeIntarzieri,
        context.l10n.tosClientiiSuntResponsabiliProtectia,
        context.l10n.tosServiciilePotFiSuspendate2,
        context.l10n.tosRespectareaInstructiunilorUtilizareEste,
        context.l10n.tosIntBankRaspundePierderi2,
        context.l10n.tosServiciileSuntFurnizateAsa,
        context.l10n.tosIntBankGaranteazaExactitatea,
        context.l10n.tosClientiiTrebuieSaVerifice,
        context.l10n.tosAccesulContPoateFi2,
        context.l10n.tosClientiiSuntResponsabiliFolosirea,
        context.l10n.tosIntBankPoateAjusta,
        context.l10n.tosClientiiTrebuieSaAccepte3,
      ],
    },
    {
      "8. Diverse": [
        context.l10n.tosIntBankPoateSuspenda2,
        context.l10n.tosConturileTrebuieSaRespecte,
        context.l10n.tosIntBankEsteResponsabil,
        context.l10n.tosClientiiTrebuieSaUtilizeze,
        context.l10n.tosDisputePrivindTranzactiileVor,
        context.l10n.tosClientiiTrebuieSaRespecte3,
        context.l10n.tosConturileInactiveNedeclaratePot,
        context.l10n.tosFolosireaAplicatieiImplicaAcordul,
        context.l10n.tosIntBankPoateIntroduce2,
        context.l10n.tosNerespectareaTermenilorPoateDuce,
        context.l10n.tosClientiiTrebuieSaRespecte4,
        context.l10n.tosModificarileLegislativePotInfluenta,
        context.l10n.tosClientulTrebuieSaConsulte,
        context.l10n.tosIntBankPoateModifica2,
        context.l10n.tosClientiiSuntResponsabiliRespectarea,
      ],
    },
    {
      "9. Taxe și comisioane": [
        context.l10n.tosToateTaxeleAplicateContului,
        context.l10n.tosIntBankPoateModifica3,
        context.l10n.tosTaxeleTranzactiileInternationalePot,
        context.l10n.tosClientulEsteResponsabilPlata2,
        context.l10n.tosTaxelePotFiPercepute,
        context.l10n.tosIntBankPoateSuspenda3,
        context.l10n.tosClientiiTrebuieSaConsulte,
        context.l10n.tosReduceriPromotiiPotFi,
        context.l10n.tosTaxelePerceputeTertiTransferuri,
        context.l10n.tosSchimbarileTaxeVorFi,
        context.l10n.tosComisioaneleServiciiSpecialeSunt,
        context.l10n.tosIntBankPoateAjusta2,
        context.l10n.tosTaxeleSuplimentareTranzactiiUrgente,
        context.l10n.tosClientulTrebuieSaAccepte3,
        context.l10n.tosNeplataTaxelorPoateDuce,
      ],
    },
    {
      "10. Reziliere și suspendare": [
        context.l10n.tosIntBankPoateRezilia,
        context.l10n.tosSuspendareaContuluiPoateFi2,
        context.l10n.tosClientiiVorFiNotificati,
        context.l10n.tosReziliereaContuluiElibereazaClientul,
        context.l10n.tosIntBankPoateInchide,
        context.l10n.tosSuspendareaContuluiSePoate,
        context.l10n.tosConturileInactiveTermenLung,
        context.l10n.tosReziliereaContuluiAfecteazaTranzactiile,
        context.l10n.tosClientiiTrebuieSaCoopereze,
        context.l10n.tosIntBankPoateSuspenda4,
        context.l10n.tosReactivareaContuluiPoateFi,
        context.l10n.tosClientiiTrebuieSaIsi,
        context.l10n.tosOriceLitigiuLegatContul,
        context.l10n.tosSuspendareaTemporaraPoateFi,
        context.l10n.tosReziliereaContuluiSeRealizeaza,
      ],
    },
  ];

  @override
  void initState()
  {
    super.initState();
    _scrollController.addListener(() {
      if(_scrollController.offset >=
          _scrollController.position.maxScrollExtent)
{
        setState(() => _canAccept = true);
      }
    });
  }

  @override
  void dispose()
  {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildRule(String rule, int index)
  {
    String letter = String.fromCharCode(97 + index);
    List<TextSpan> spans = [];
    final exp = RegExp(r'\b(INT Bank|cont|tranzacții|confidențialitate|securitate)\b');
    int start = 0;

    for(final match in exp.allMatches(rule))
{
      if(match.start > start)
{
        spans.add(TextSpan(text: rule.substring(start, match.start)));
      }
      spans.add(
        TextSpan(
          text: rule.substring(match.start, match.end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.colors.brand,
          ),
        ),
      );
      start = match.end;
    }
    if(start < rule.length)
{
      spans.add(TextSpan(text: rule.substring(start)));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$letter. ', style: TextStyle(fontWeight: FontWeight.bold, color: context.colors.brand, fontSize: 15)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: context.colors.textSecondary, height: 1.5),
                children: spans,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapter(String title, List<String> rules)
  {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: context.colors.textPrimary)),
          const SizedBox(height: 8),
          ...List.generate(rules.length, (index) => _buildRule(rules[index], index)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const AppLogo(height: 80),
            const SizedBox(height: 16),
            Text(context.l10n.tosTermeniConditii, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 16),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: chapters.map((chapter) => _buildChapter(chapter.keys.first, chapter.values.first)).toList(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canAccept && !_loading ? _acceptTerms : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _loading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.onBrand)),
                            const SizedBox(width: 12),
                            Text(context.l10n.tosSeProceseaza, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.onBrand)),
                          ],
                        )
                      : Text(context.l10n.tosSuntAcord, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.onBrand)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

