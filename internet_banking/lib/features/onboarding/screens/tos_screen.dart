// lib/features/onboarding/screens/tos_screen.dart

import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show HttpClient, X509Certificate, Platform;

import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;

import '../../../config/app_config.dart';
import 'approval_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../welcome/welcome_screen.dart';

class TosScreen extends StatefulWidget {
  final int userId;
  const TosScreen({super.key, required this.userId});

  @override
  State<TosScreen> createState() => _TosScreenState();
}

class _TosScreenState extends State<TosScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _canAccept = false;
  bool _loading = false;

  http.Client _createHttpClient() {
    final ioc = HttpClient();
    ioc.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor!;
    }
    return 'unknown-device';
  }

  Future<void> _acceptTerms() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final client = _createHttpClient();
    try {
      final deviceId = await getDeviceId();
      final tokenResponse = await client.post(
        Uri.parse('https://$serverUrl/auth/get-client-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'deviceId': deviceId}),
      );

      if (!mounted) return;
      final tokenData = jsonDecode(tokenResponse.body);
      final clientToken = tokenData['client_token'];

      final tosResponse = await client.get(
        Uri.parse('https://$serverUrl/users/${widget.userId}/has-tos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );

      if (!mounted) return;
      if (tosResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la verificarea TOS')),
        );
        return;
      }

      final tosData = jsonDecode(tosResponse.body);
      final acceptedTerms = tosData['termeniAcceptati'] ?? false;

      if (!acceptedTerms) {
        final putResponse = await client.put(
          Uri.parse('https://$serverUrl/users/${widget.userId}/accept-tos'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $clientToken',
          },
        );
        if (!mounted) return;
        if (putResponse.statusCode != 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eroare la actualizarea TOS')),
          );
          return;
        }
      }

      final approvedResponse = await client.get(
        Uri.parse('https://$serverUrl/users/${widget.userId}/has-approved/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $clientToken',
        },
      );

      if (!mounted) return;
      if (approvedResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Eroare la verificarea contului')),
        );
        return;
      }

      final approvedData = jsonDecode(approvedResponse.body);
      final isApproved = approvedData['contaprobat'] ?? false;

      if (!isApproved) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalScreen(userId: widget.userId),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nu se poate conecta la server')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      client.close();
    }
  }

  final List<Map<String, List<String>>> chapters = [
    {
      "1. Despre conturi": [
        "Toate conturile deschise la INT Bank trebuie să fie înregistrate cu date reale și corecte.",
        "Fiecare client poate deține un singur cont personal la INT Bank.",
        "Conturile inactive mai mult de 12 luni pot fi suspendate temporar.",
        "Clienții minori necesită consimțământul părinților sau tutorilor.",
        "Clientul trebuie să protejeze datele de acces și parolele.",
        "INT Bank poate solicita documente suplimentare pentru verificare.",
        "Tranzacțiile efectuate prin cont sunt responsabilitatea clientului.",
        "Partajarea conturilor cu alte persoane este strict interzisă.",
        "Clientul trebuie să accepte acești termeni pentru deschiderea contului.",
        "Conturile neregulate pot fi închise de INT Bank fără notificare prealabilă.",
        "Clientul trebuie să respecte limitele de tranzacționare și regulile băncii.",
        "Modificarea datelor personale trebuie raportată imediat la INT Bank.",
        "Datele contului trebuie păstrate confidențiale.",
        "Utilizarea contului pentru activități ilegale este interzisă.",
        "INT Bank nu răspunde pentru pierderi cauzate de neglijența clientului.",
        "Suspendarea contului poate fi efectuată pentru verificări suplimentare.",
        "Accesul la cont poate fi blocat temporar în caz de risc de securitate.",
      ],
    },
    {
      "2. Securitate și confidențialitate": [
        "Clienții trebuie să păstreze confidențialitatea parolelor și codurilor PIN.",
        "INT Bank nu va solicita niciodată parole prin email sau telefon.",
        "Raportați imediat orice activitate suspectă la INT Bank.",
        "Dispozitivele folosite pentru acces la cont trebuie să fie securizate.",
        "Autentificarea cu doi factori (2FA) este recomandată.",
        "Datele personale sunt procesate conform politicii de confidențialitate INT Bank.",
        "Este interzisă distribuirea de malware sau phishing prin aplicație.",
        "Clienții trebuie să folosească doar canalele oficiale INT Bank.",
        "Monitorizarea activității contului se face pentru siguranță.",
        "INT Bank poate introduce autentificări suplimentare pentru protecție.",
        "În caz de încălcare a securității, contul poate fi blocat temporar.",
        "Parolele trebuie să fie complexe și unice.",
        "Codurile de securitate nu trebuie distribuite altor persoane.",
        "Datele sensibile nu trebuie stocate pe dispozitive publice.",
        "Raportarea pierderii dispozitivului previne fraudele.",
        "INT Bank poate audita securitatea conturilor pentru prevenirea fraudei.",
      ],
    },
    {
      "3. Tranzacții și plăți": [
        "Plățile efectuate prin INT Bank sunt finale și ireversibile fără acordul băncii.",
        "Clientul trebuie să verifice detaliile înainte de confirmarea plății.",
        "Tranzacțiile internaționale sunt supuse cursului de schimb valutar.",
        "INT Bank poate refuza tranzacții suspecte fără notificare.",
        "Clienții trebuie să respecte limitele zilnice și lunare stabilite.",
        "Taxele și comisioanele aplicabile sunt cele afișate în ghidul tarifar.",
        "Clientul este responsabil pentru plata tuturor taxelor asociate contului.",
        "Tranzacțiile cu sume mari pot fi supuse verificărilor suplimentare.",
        "Plățile automate trebuie configurate corect conform instrucțiunilor INT Bank.",
        "Tranzacțiile frauduloase trebuie raportate imediat.",
        "Documentele suplimentare pot fi cerute pentru validarea plăților.",
        "Clientul trebuie să păstreze dovezi ale plăților efectuate.",
        "Orice eroare de tranzacție poate fi investigată conform procedurilor interne.",
        "INT Bank poate suspenda tranzacțiile dacă sunt detectate nereguli.",
        "Modificarea datelor bancare trebuie verificată înainte de transfer.",
      ],
    },
    {
      "4. Modificări ale serviciilor": [
        "INT Bank poate modifica termenii și condițiile în orice moment.",
        "Notificările oficiale sunt comunicate prin aplicație, email sau SMS.",
        "Serviciile pot fi suspendate temporar pentru mentenanță.",
        "Funcționalitățile suplimentare pot fi introduse fără notificare.",
        "Procedurile de autentificare și securitate pot fi actualizate.",
        "Structura conturilor, limitele și condițiile pot fi modificate.",
        "Clienții trebuie să folosească versiuni actualizate ale aplicației.",
        "Accesul la anumite funcționalități poate fi limitat pentru neconformitate.",
        "INT Bank poate schimba taxele și comisioanele percepute.",
        "Actualizările vor fi afișate și în aplicație.",
        "Limitele de tranzacționare pot fi ajustate.",
        "Clienții trebuie să accepte modificările pentru continuarea serviciilor.",
        "Schimbările majore vor fi notificate prin email oficial.",
        "Funcționalități pot fi suspendate temporar pentru upgrade-uri.",
        "Actualizările de securitate sunt obligatorii pentru toți utilizatorii.",
      ],
    },
    {
      "5. Obligațiile clientului": [
        "Clienții trebuie să raporteze pierderea sau furtul dispozitivelor imediat.",
        "Clientul trebuie să actualizeze informațiile personale la schimbarea datelor.",
        "Clienții trebuie să respecte legislația locală privind tranzacțiile financiare.",
        "Nu se poate folosi aplicația pentru scopuri ilegale.",
        "Respectarea regulilor de publicitate și promovare a serviciilor este obligatorie.",
        "Litigiile privind conturile vor fi soluționate conform legislației.",
        "Clienții sunt responsabili pentru toate datele introduse și confidențialitatea acestora.",
        "INT Bank nu garantează disponibilitatea neîntreruptă a serviciilor.",
        "Clientul trebuie să respecte cerințele pentru prevenirea fraudei.",
        "Verificarea periodică a extraselor de cont este responsabilitatea clientului.",
        "Respectarea limitelor de retragere și transfer impuse de INT Bank este obligatorie.",
        "Verificarea corectitudinii datelor în aplicație este responsabilitatea clientului.",
        "Protejarea dispozitivelor și a aplicației INT Bank este obligatorie.",
        "Este interzisă folosirea conturilor pentru activități comerciale fără aprobare.",
        "Respectarea termenelor de plată pentru serviciile asociate este responsabilitatea clientului.",
      ],
    },
    {
      "6. Protecția datelor": [
        "INT Bank colectează și procesează date personale conform legislației.",
        "Clientul trebuie să accepte politica de confidențialitate INT Bank.",
        "Datele sensibile nu trebuie distribuite către terți neautorizați.",
        "Clienții au dreptul de a solicita ștergerea datelor personale.",
        "Datele pot fi folosite pentru servicii personalizate și oferte.",
        "Toate datele sunt stocate securizat și criptat.",
        "Clienții trebuie să raporteze accesul neautorizat la date.",
        "INT Bank poate procesa date anonimizate pentru statistici interne.",
        "Folosirea datelor altor clienți fără consimțământ este interzisă.",
        "Acceptarea cookie-urilor și termenilor de procesare este obligatorie.",
        "Modificările politicii de confidențialitate vor fi notificate prin aplicație.",
        "Clienții trebuie să accepte termenii pentru a continua să folosească aplicația.",
        "Datele colectate sunt folosite exclusiv în scopuri legale.",
        "INT Bank poate bloca contul în caz de încălcare a politicii de date.",
        "Clienții trebuie să mențină informațiile personale actualizate.",
      ],
    },
    {
      "7. Limitarea răspunderii": [
        "INT Bank nu este responsabilă pentru pierderi cauzate de erori ale clienților.",
        "Nu se garantează disponibilitatea neîntreruptă a serviciilor.",
        "INT Bank nu răspunde pentru întârzieri cauzate de terți.",
        "Clienții sunt responsabili pentru protecția dispozitivelor și conturilor lor.",
        "Serviciile pot fi suspendate în caz de urgențe sau defecțiuni.",
        "Respectarea instrucțiunilor de utilizare este responsabilitatea clientului.",
        "INT Bank nu răspunde pentru pierderi cauzate de fraude externe.",
        "Serviciile sunt furnizate „așa cum sunt”, fără garanții suplimentare.",
        "INT Bank nu garantează exactitatea informațiilor terților.",
        "Clienții trebuie să verifice regulat extrasele de cont pentru erori.",
        "Accesul la cont poate fi limitat în caz de risc de securitate.",
        "Clienții sunt responsabili pentru folosirea aplicației conform legii.",
        "INT Bank poate ajusta termenii de responsabilitate prin notificare.",
        "Clienții trebuie să accepte termenii pentru a continua folosirea serviciilor.",
      ],
    },
    {
      "8. Diverse": [
        "INT Bank poate suspenda sau restricționa conturile care încalcă termenii.",
        "Conturile trebuie să respecte politicile fiscale locale.",
        "INT Bank nu este responsabilă pentru pierderile cauzate de terți.",
        "Clienții trebuie să utilizeze doar canalele oficiale INT Bank.",
        "Dispute privind tranzacțiile vor fi investigate conform procedurilor interne.",
        "Clienții trebuie să respecte cerințele de securitate.",
        "Conturile inactive sau nedeclarate pot fi dezactivate.",
        "Folosirea aplicației implică acordul față de toate regulile INT Bank.",
        "INT Bank poate introduce noi funcționalități și servicii.",
        "Nerespectarea termenilor poate duce la suspendarea contului.",
        "Clienții trebuie să respecte toate notificările INT Bank.",
        "Modificările legislative pot influența regulile aplicabile.",
        "Clientul trebuie să consulte periodic aplicația pentru actualizări.",
        "INT Bank poate modifica termenii pentru a proteja clienții.",
        "Clienții sunt responsabili pentru respectarea regulilor aplicației.",
      ],
    },
    {
      "9. Taxe și comisioane": [
        "Toate taxele aplicate contului vor fi afișate transparent în aplicație.",
        "INT Bank poate modifica comisioanele prin notificare prealabilă.",
        "Taxele pentru tranzacțiile internaționale pot varia conform cursului valutar.",
        "Clientul este responsabil pentru plata tuturor taxelor aferente contului.",
        "Taxele pot fi percepute pentru retrageri, transferuri și servicii adiționale.",
        "INT Bank poate suspenda contul pentru neplata taxelor aplicabile.",
        "Clienții trebuie să consulte ghidul tarifar actualizat al băncii.",
        "Reduceri și promoții pot fi aplicate doar conform regulilor INT Bank.",
        "Taxele percepute de terți pentru transferuri externe sunt responsabilitatea clientului.",
        "Schimbările de taxe vor fi comunicate prin aplicație și email.",
        "Comisioanele pentru servicii speciale sunt afișate separat.",
        "INT Bank poate ajusta limitele taxelor în funcție de cont.",
        "Taxele suplimentare pentru tranzacții urgente pot fi percepute.",
        "Clientul trebuie să accepte taxele pentru continuarea serviciului.",
        "Neplata taxelor poate duce la suspendarea funcționalităților contului.",
      ],
    },
    {
      "10. Reziliere și suspendare": [
        "INT Bank poate rezilia contul în caz de încălcare a termenilor.",
        "Suspendarea contului poate fi temporară sau permanentă.",
        "Clienții vor fi notificați prin aplicație sau email oficial.",
        "Rezilierea contului nu eliberează clientul de obligațiile financiare.",
        "INT Bank poate închide contul pentru activități ilegale.",
        "Suspendarea contului se poate realiza pentru verificări suplimentare.",
        "Conturile inactive pe termen lung pot fi dezactivate automat.",
        "Rezilierea contului nu afectează tranzacțiile deja efectuate.",
        "Clienții trebuie să coopereze pentru închiderea contului conform procedurilor.",
        "INT Bank poate suspenda serviciile în caz de risc de securitate.",
        "Reactivarea contului poate fi solicitată doar conform regulilor băncii.",
        "Clienții trebuie să își retragă fondurile înainte de închidere.",
        "Orice litigiu legat de contul suspendat va fi soluționat conform legislației.",
        "Suspendarea temporară poate fi decisă de banca pentru mentenanță sau upgrade.",
        "Rezilierea contului se realizează numai după respectarea tuturor procedurilor.",
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset >=
          _scrollController.position.maxScrollExtent) {
        setState(() => _canAccept = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildRule(String rule, int index) {
    String letter = String.fromCharCode(97 + index);
    List<TextSpan> spans = [];
    final exp = RegExp(r'\b(INT Bank|cont|tranzacț|confidențialitate|securitate)\b');
    int start = 0;

    for (final match in exp.allMatches(rule)) {
      if (match.start > start) {
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
    if (start < rule.length) {
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

  Widget _buildChapter(String title, List<String> rules) {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Image.asset('assets/images/logo.png', height: 80),
            const SizedBox(height: 16),
            Text('Termeni și Condiții', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
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
                            Text('Se procesează...', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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
