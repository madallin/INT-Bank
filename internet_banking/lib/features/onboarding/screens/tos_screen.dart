import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show HttpClient, Platform;

import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;

import '../../../config/app_config.dart';
import 'approval_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../welcome/welcome_screen.dart';

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

  http.Client _createHttpClient()
  {
    return IOClient(HttpClient());
  }

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

    final client = _createHttpClient();
    try
    {
      final deviceId = await getDeviceId();
      final tokenResponse = await client.post(
        Uri.parse('https://${AppConfig.serverUrl}/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId}),
      );

      if(!mounted) return;
      final tokenData = jsonDecode(tokenResponse.body);
      final clientToken = tokenData['client_token'];

      final tosResponse = await client.get(
        Uri.parse('https://${AppConfig.serverUrl}/users/${widget.userId}/has-tos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );

      if(!mounted) return;
      if(tosResponse.statusCode != 200)
{
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la verificarea TOS')),
        );
        return;
      }

      final tosData = jsonDecode(tosResponse.body);
      final acceptedTerms = tosData['termeniAcceptati'] ?? false;

      if(!acceptedTerms)
{
        final putResponse = await client.put(
          Uri.parse('https://${AppConfig.serverUrl}/users/${widget.userId}/accept-tos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $clientToken',
          },
        );
        if(!mounted) return;
        if(putResponse.statusCode != 200)
{
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eroare la actualizarea TOS')),
          );
          return;
        }
      }

      final approvedResponse = await client.get(
        Uri.parse('https://${AppConfig.serverUrl}/users/${widget.userId}/has-approved/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );

      if(!mounted) return;
      if(approvedResponse.statusCode != 200)
{
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la verificarea contului')),
        );
        return;
      }

      final approvedData = jsonDecode(approvedResponse.body);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu se poate conecta la server')),
        );
      }
    }
    finally
    {
      if(mounted) setState(() => _loading = false);
      client.close();
    }
  }

  final List<Map<String, List<String>>> chapters = [
    {
      "1. Despre conturi": [
        "Toate conturile deschise la INT Bank trebuie s?? fie ??nregistrate cu date reale ??i corecte.",
        "Fiecare client poate de??ine un singur cont personal la INT Bank.",
        "Conturile inactive mai mult de 12 luni pot fi suspendate temporar.",
        "Clien??ii minori necesit?? consim????m??ntul p??rin??ilor sau tutorilor.",
        "Clientul trebuie s?? protejeze datele de acces ??i parolele.",
        "INT Bank poate solicita documente suplimentare pentru verificare.",
        "Tranzac??iile efectuate prin cont sunt responsabilitatea clientului.",
        "Partajarea conturilor cu alte persoane este strict interzis??.",
        "Clientul trebuie s?? accepte ace??ti termeni pentru deschiderea contului.",
        "Conturile neregulate pot fi ??nchise de INT Bank f??r?? notificare prealabil??.",
        "Clientul trebuie s?? respecte limitele de tranzac??ionare ??i regulile b??ncii.",
        "Modificarea datelor personale trebuie raportat?? imediat la INT Bank.",
        "Datele contului trebuie p??strate confiden??iale.",
        "Utilizarea contului pentru activit????i ilegale este interzis??.",
        "INT Bank nu r??spunde pentru pierderi cauzate de neglijen??a clientului.",
        "Suspendarea contului poate fi efectuat?? pentru verific??ri suplimentare.",
        "Accesul la cont poate fi blocat temporar ??n caz de risc de securitate.",
      ],
    },
    {
      "2. Securitate ??i confiden??ialitate": [
        "Clien??ii trebuie s?? p??streze confiden??ialitatea parolelor ??i codurilor PIN.",
        "INT Bank nu va solicita niciodat?? parole prin email sau telefon.",
        "Raporta??i imediat orice activitate suspect?? la INT Bank.",
        "Dispozitivele folosite pentru acces la cont trebuie s?? fie securizate.",
        "Autentificarea cu doi factori (2FA) este recomandat??.",
        "Datele personale sunt procesate conform politicii de confiden??ialitate INT Bank.",
        "Este interzis?? distribuirea de malware sau phishing prin aplica??ie.",
        "Clien??ii trebuie s?? foloseasc?? doar canalele oficiale INT Bank.",
        "Monitorizarea activit????ii contului se face pentru siguran????.",
        "INT Bank poate introduce autentific??ri suplimentare pentru protec??ie.",
        "??n caz de ??nc??lcare a securit????ii, contul poate fi blocat temporar.",
        "Parolele trebuie s?? fie complexe ??i unice.",
        "Codurile de securitate nu trebuie distribuite altor persoane.",
        "Datele sensibile nu trebuie stocate pe dispozitive publice.",
        "Raportarea pierderii dispozitivului previne fraudele.",
        "INT Bank poate audita securitatea conturilor pentru prevenirea fraudei.",
      ],
    },
    {
      "3. Tranzac??ii ??i pl????i": [
        "Pl????ile efectuate prin INT Bank sunt finale ??i ireversibile f??r?? acordul b??ncii.",
        "Clientul trebuie s?? verifice detaliile ??nainte de confirmarea pl????ii.",
        "Tranzac??iile interna??ionale sunt supuse cursului de schimb valutar.",
        "INT Bank poate refuza tranzac??ii suspecte f??r?? notificare.",
        "Clien??ii trebuie s?? respecte limitele zilnice ??i lunare stabilite.",
        "Taxele ??i comisioanele aplicabile sunt cele afi??ate ??n ghidul tarifar.",
        "Clientul este responsabil pentru plata tuturor taxelor asociate contului.",
        "Tranzac??iile cu sume mari pot fi supuse verific??rilor suplimentare.",
        "Pl????ile automate trebuie configurate corect conform instruc??iunilor INT Bank.",
        "Tranzac??iile frauduloase trebuie raportate imediat.",
        "Documentele suplimentare pot fi cerute pentru validarea pl????ilor.",
        "Clientul trebuie s?? p??streze dovezi ale pl????ilor efectuate.",
        "Orice eroare de tranzac??ie poate fi investigat?? conform procedurilor interne.",
        "INT Bank poate suspenda tranzac??iile dac?? sunt detectate nereguli.",
        "Modificarea datelor bancare trebuie verificat?? ??nainte de transfer.",
      ],
    },
    {
      "4. Modific??ri ale serviciilor": [
        "INT Bank poate modifica termenii ??i condi??iile ??n orice moment.",
        "Notific??rile oficiale sunt comunicate prin aplica??ie, email sau SMS.",
        "Serviciile pot fi suspendate temporar pentru mentenan????.",
        "Func??ionalit????ile suplimentare pot fi introduse f??r?? notificare.",
        "Procedurile de autentificare ??i securitate pot fi actualizate.",
        "Structura conturilor, limitele ??i condi??iile pot fi modificate.",
        "Clien??ii trebuie s?? foloseasc?? versiuni actualizate ale aplica??iei.",
        "Accesul la anumite func??ionalit????i poate fi limitat pentru neconformitate.",
        "INT Bank poate schimba taxele ??i comisioanele percepute.",
        "Actualiz??rile vor fi afi??ate ??i ??n aplica??ie.",
        "Limitele de tranzac??ionare pot fi ajustate.",
        "Clien??ii trebuie s?? accepte modific??rile pentru continuarea serviciilor.",
        "Schimb??rile majore vor fi notificate prin email oficial.",
        "Func??ionalit????i pot fi suspendate temporar pentru upgrade-uri.",
        "Actualiz??rile de securitate sunt obligatorii pentru to??i utilizatorii.",
      ],
    },
    {
      "5. Obliga??iile clientului": [
        "Clien??ii trebuie s?? raporteze pierderea sau furtul dispozitivelor imediat.",
        "Clientul trebuie s?? actualizeze informa??iile personale la schimbarea datelor.",
        "Clien??ii trebuie s?? respecte legisla??ia local?? privind tranzac??iile financiare.",
        "Nu se poate folosi aplica??ia pentru scopuri ilegale.",
        "Respectarea regulilor de publicitate ??i promovare a serviciilor este obligatorie.",
        "Litigiile privind conturile vor fi solu??ionate conform legisla??iei.",
        "Clien??ii sunt responsabili pentru toate datele introduse ??i confiden??ialitatea acestora.",
        "INT Bank nu garanteaz?? disponibilitatea ne??ntrerupt?? a serviciilor.",
        "Clientul trebuie s?? respecte cerin??ele pentru prevenirea fraudei.",
        "Verificarea periodic?? a extraselor de cont este responsabilitatea clientului.",
        "Respectarea limitelor de retragere ??i transfer impuse de INT Bank este obligatorie.",
        "Verificarea corectitudinii datelor ??n aplica??ie este responsabilitatea clientului.",
        "Protejarea dispozitivelor ??i a aplica??iei INT Bank este obligatorie.",
        "Este interzis?? folosirea conturilor pentru activit????i comerciale f??r?? aprobare.",
        "Respectarea termenelor de plat?? pentru serviciile asociate este responsabilitatea clientului.",
      ],
    },
    {
      "6. Protec??ia datelor": [
        "INT Bank colecteaz?? ??i proceseaz?? date personale conform legisla??iei.",
        "Clientul trebuie s?? accepte politica de confiden??ialitate INT Bank.",
        "Datele sensibile nu trebuie distribuite c??tre ter??i neautoriza??i.",
        "Clien??ii au dreptul de a solicita ??tergerea datelor personale.",
        "Datele pot fi folosite pentru servicii personalizate ??i oferte.",
        "Toate datele sunt stocate securizat ??i criptat.",
        "Clien??ii trebuie s?? raporteze accesul neautorizat la date.",
        "INT Bank poate procesa date anonimizate pentru statistici interne.",
        "Folosirea datelor altor clien??i f??r?? consim????m??nt este interzis??.",
        "Acceptarea cookie-urilor ??i termenilor de procesare este obligatorie.",
        "Modific??rile politicii de confiden??ialitate vor fi notificate prin aplica??ie.",
        "Clien??ii trebuie s?? accepte termenii pentru a continua s?? foloseasc?? aplica??ia.",
        "Datele colectate sunt folosite exclusiv ??n scopuri legale.",
        "INT Bank poate bloca contul ??n caz de ??nc??lcare a politicii de date.",
        "Clien??ii trebuie s?? men??in?? informa??iile personale actualizate.",
      ],
    },
    {
      "7. Limitarea r??spunderii": [
        "INT Bank nu este responsabil?? pentru pierderi cauzate de erori ale clien??ilor.",
        "Nu se garanteaz?? disponibilitatea ne??ntrerupt?? a serviciilor.",
        "INT Bank nu r??spunde pentru ??nt??rzieri cauzate de ter??i.",
        "Clien??ii sunt responsabili pentru protec??ia dispozitivelor ??i conturilor lor.",
        "Serviciile pot fi suspendate ??n caz de urgen??e sau defec??iuni.",
        "Respectarea instruc??iunilor de utilizare este responsabilitatea clientului.",
        "INT Bank nu r??spunde pentru pierderi cauzate de fraude externe.",
        "Serviciile sunt furnizate ???a??a cum sunt???, f??r?? garan??ii suplimentare.",
        "INT Bank nu garanteaz?? exactitatea informa??iilor ter??ilor.",
        "Clien??ii trebuie s?? verifice regulat extrasele de cont pentru erori.",
        "Accesul la cont poate fi limitat ??n caz de risc de securitate.",
        "Clien??ii sunt responsabili pentru folosirea aplica??iei conform legii.",
        "INT Bank poate ajusta termenii de responsabilitate prin notificare.",
        "Clien??ii trebuie s?? accepte termenii pentru a continua folosirea serviciilor.",
      ],
    },
    {
      "8. Diverse": [
        "INT Bank poate suspenda sau restric??iona conturile care ??ncalc?? termenii.",
        "Conturile trebuie s?? respecte politicile fiscale locale.",
        "INT Bank nu este responsabil?? pentru pierderile cauzate de ter??i.",
        "Clien??ii trebuie s?? utilizeze doar canalele oficiale INT Bank.",
        "Dispute privind tranzac??iile vor fi investigate conform procedurilor interne.",
        "Clien??ii trebuie s?? respecte cerin??ele de securitate.",
        "Conturile inactive sau nedeclarate pot fi dezactivate.",
        "Folosirea aplica??iei implic?? acordul fa???? de toate regulile INT Bank.",
        "INT Bank poate introduce noi func??ionalit????i ??i servicii.",
        "Nerespectarea termenilor poate duce la suspendarea contului.",
        "Clien??ii trebuie s?? respecte toate notific??rile INT Bank.",
        "Modific??rile legislative pot influen??a regulile aplicabile.",
        "Clientul trebuie s?? consulte periodic aplica??ia pentru actualiz??ri.",
        "INT Bank poate modifica termenii pentru a proteja clien??ii.",
        "Clien??ii sunt responsabili pentru respectarea regulilor aplica??iei.",
      ],
    },
    {
      "9. Taxe ??i comisioane": [
        "Toate taxele aplicate contului vor fi afi??ate transparent ??n aplica??ie.",
        "INT Bank poate modifica comisioanele prin notificare prealabil??.",
        "Taxele pentru tranzac??iile interna??ionale pot varia conform cursului valutar.",
        "Clientul este responsabil pentru plata tuturor taxelor aferente contului.",
        "Taxele pot fi percepute pentru retrageri, transferuri ??i servicii adi??ionale.",
        "INT Bank poate suspenda contul pentru neplata taxelor aplicabile.",
        "Clien??ii trebuie s?? consulte ghidul tarifar actualizat al b??ncii.",
        "Reduceri ??i promo??ii pot fi aplicate doar conform regulilor INT Bank.",
        "Taxele percepute de ter??i pentru transferuri externe sunt responsabilitatea clientului.",
        "Schimb??rile de taxe vor fi comunicate prin aplica??ie ??i email.",
        "Comisioanele pentru servicii speciale sunt afi??ate separat.",
        "INT Bank poate ajusta limitele taxelor ??n func??ie de cont.",
        "Taxele suplimentare pentru tranzac??ii urgente pot fi percepute.",
        "Clientul trebuie s?? accepte taxele pentru continuarea serviciului.",
        "Neplata taxelor poate duce la suspendarea func??ionalit????ilor contului.",
      ],
    },
    {
      "10. Reziliere ??i suspendare": [
        "INT Bank poate rezilia contul ??n caz de ??nc??lcare a termenilor.",
        "Suspendarea contului poate fi temporar?? sau permanent??.",
        "Clien??ii vor fi notifica??i prin aplica??ie sau email oficial.",
        "Rezilierea contului nu elibereaz?? clientul de obliga??iile financiare.",
        "INT Bank poate ??nchide contul pentru activit????i ilegale.",
        "Suspendarea contului se poate realiza pentru verific??ri suplimentare.",
        "Conturile inactive pe termen lung pot fi dezactivate automat.",
        "Rezilierea contului nu afecteaz?? tranzac??iile deja efectuate.",
        "Clien??ii trebuie s?? coopereze pentru ??nchiderea contului conform procedurilor.",
        "INT Bank poate suspenda serviciile ??n caz de risc de securitate.",
        "Reactivarea contului poate fi solicitat?? doar conform regulilor b??ncii.",
        "Clien??ii trebuie s?? ????i retrag?? fondurile ??nainte de ??nchidere.",
        "Orice litigiu legat de contul suspendat va fi solu??ionat conform legisla??iei.",
        "Suspendarea temporar?? poate fi decis?? de banca pentru mentenan???? sau upgrade.",
        "Rezilierea contului se realizeaz?? numai dup?? respectarea tuturor procedurilor.",
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
    final exp = RegExp(r'\b(INT Bank|cont|tranzac??|confiden??ialitate|securitate)\b');
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
            color: Color(lightForestGreenColor),
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
          Text('$letter. ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(lightForestGreenColor), fontSize: 15)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF4B4B4B), height: 1.5),
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
          Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1F2937))),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Image.asset('assets/images/logo.png', height: 80),
            const SizedBox(height: 16),
            Text('Termeni ??i Condi??ii', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
                    backgroundColor: const Color(lightForestGreenColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _loading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
                            const SizedBox(width: 12),
                            Text('Se proceseaz??...', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        )
                      : Text('Sunt de acord', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

