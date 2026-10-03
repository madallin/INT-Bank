import '../../../theme/app_tokens.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../widgets/app_button.dart';
import '../../../core/network/dio_client.dart';
import '../../../l10n/l10n.dart';

class ErrorScreen extends StatefulWidget
{
  final String errorMessage;
  final Function(BuildContext) onConnectionRestored;

  const ErrorScreen({
    super.key,
    required this.errorMessage,
    required this.onConnectionRestored,
  });

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen>
    with TickerProviderStateMixin
{
  late AnimationController _craneController;

  bool _pillar1InBank = true;
  bool _pillar5InBank = false;
  bool _pillar1OnGround = false;
  bool _pillar5OnGround = true;

  bool _cycle1Active = true;
  bool _cycleFlipped = false;

  Timer? _connectionTimer;
  bool _checking = false;
  bool _manualChecking = false;
  bool _manualCheckFailed = false;

  @override
  void initState()
  {
    super.initState();

    _craneController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _craneController.addListener(() {
      if(!mounted) return;

      final value = _craneController.value;

      const double takeTimeStart = 0.28;
      const double takeTimeEnd = 0.32;
      const double putTimeStart = 0.52;
      const double putTimeEnd = 0.56;

      if(_cycle1Active)
{
        if(value > takeTimeStart && value < takeTimeEnd)
{
          if(_pillar1InBank) setState(() => _pillar1InBank = false);
          if(_pillar5OnGround) setState(() => _pillar5OnGround = false);
        }
        if(value > putTimeStart && value < putTimeEnd)
{
          if(!_pillar1OnGround) setState(() => _pillar1OnGround = true);
          if(!_pillar5InBank) setState(() => _pillar5InBank = true);
        }
      }
      else
{
        if(value > takeTimeStart && value < takeTimeEnd)
{
          if(_pillar1OnGround) setState(() => _pillar1OnGround = false);
          if(_pillar5InBank) setState(() => _pillar5InBank = false);
        }
        if(value > putTimeStart && value < putTimeEnd)
{
          if(!_pillar1InBank) setState(() => _pillar1InBank = true);
          if(!_pillar5OnGround) setState(() => _pillar5OnGround = true);
        }
      }

      if(value > 0.98)
{
        if(!_cycleFlipped)
{
          setState(() => _cycle1Active = !_cycle1Active);
          _cycleFlipped = true;
        }
      }
      else if(value < 0.1)
{
        _cycleFlipped = false;
      }
    });

    _startConnectionCheck();
  }

  void _startConnectionCheck()
  {
    _connectionTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _attemptReconnect(),
    );
  }

  Future<void> _attemptReconnect({bool manual = false}) async
  {
    if(manual)
    {
      setState(() {
        _manualChecking = true;
        _manualCheckFailed = false;
      });
    }
    // A slow health check must not overlap the next tick and navigate twice;
    // a tap during an in-flight check is answered by that check's result.
    if(_checking) return;
    _checking = true;

    final isConnected = await _checkServerConnection();
    _checking = false;
    if(!mounted) return;

    if(isConnected)
    {
      _connectionTimer?.cancel();
      widget.onConnectionRestored(context);
    }
    else if(_manualChecking)
    {
      setState(() {
        _manualChecking = false;
        _manualCheckFailed = true;
      });
    }
  }

  Future<bool> _checkServerConnection() async
  {
    try
    {
      final response = await DioClient().get(
        '/health',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return response.statusCode == 200;
    }
    catch (e)
    {
      return false;
    }
  }

  @override
  void dispose()
  {
    _connectionTimer?.cancel();
    _craneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context)
  {
    final Color bankDark = context.colors.textPrimary;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(child: _buildContent(bankDark)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color bankDark)
  {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              SizedBox(
                height: 350,
                child: AnimatedBuilder(
                  animation: _craneController,
                  builder: (context, child)
                  {
                    return CustomPaint(
                      size: const Size(400, 350),
                      painter: ScenePainter(
                        ink: context.colors.textPrimary,
                        metal: context.colors.textSecondary,
                        progress: _craneController.value,
                        pillar1InBank: _pillar1InBank,
                        pillar5InBank: _pillar5InBank,
                        pillar1OnGround: _pillar1OnGround,
                        pillar5OnGround: _pillar5OnGround,
                        cycle1Active: _cycle1Active,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 48),
              Text(
                context.l10n.errorUpsCevaFunctionat,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: bankDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.errorMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: context.l10n.errorReincearcaAcum,
                icon: Icons.refresh_rounded,
                variant: AppButtonVariant.outline,
                expand: false,
                isLoading: _manualChecking,
                onPressed: () => _attemptReconnect(manual: true),
              ),
              if(_manualCheckFailed) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.errorIncaAvemConexiuneReincercam,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: context.colors.textSecondary),
                ),
              ],
              const Spacer(),
              const SizedBox(height: 16),
            ],
          ),
        );
  }
}

class ScenePainter extends CustomPainter
{
  final double progress;
  final bool pillar1InBank;
  final bool pillar5InBank;
  final bool pillar1OnGround;
  final bool pillar5OnGround;
  final bool cycle1Active;

  /// Building and crane-metal colours, from the theme so the drawing stays
  /// visible on dark backgrounds.
  final Color ink;
  final Color metal;

  ScenePainter({
    required this.ink,
    required this.metal,
    required this.progress,
    required this.pillar1InBank,
    required this.pillar5InBank,
    required this.pillar1OnGround,
    required this.pillar5OnGround,
    required this.cycle1Active,
  });

  @override
  void paint(Canvas canvas, Size size)
  {
    final w = size.width;
    final h = size.height;

    final bankPaint = Paint()..color = ink;
    final cranePaint = Paint()..color = const Color(0xFFFFB300);
    final craneMetalPaint = Paint()..color = metal;
    final hookPaint = Paint()
      ..color = metal
      ..style = PaintingStyle.fill;
    final cablePaint = Paint()
      ..color = metal.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final double bankWidth = w * 0.35;
    final double bankHeight = h * 0.40;
    final double bankX = (w - bankWidth) / 2;
    final double bankY = h * 0.5;

    final double baseHeight = bankHeight * 0.18;
    final double stepHeight = baseHeight / 3;

    canvas.drawRect(
      Rect.fromLTWH(bankX, bankY + bankHeight - stepHeight, bankWidth, stepHeight),
      bankPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bankX + bankWidth * 0.05, bankY + bankHeight - stepHeight * 2,
          bankWidth * 0.9, stepHeight),
      bankPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bankX + bankWidth * 0.1, bankY + bankHeight - stepHeight * 3,
          bankWidth * 0.8, stepHeight),
      bankPaint,
    );

    final double pillarWidth = bankWidth * 0.09;
    final double pillarHeight = bankHeight * 0.45;
    final double spacing = (bankWidth * 0.7 - pillarWidth * 5) / 4;
    final double pillarsStartX =
        bankX + (bankWidth - (5 * pillarWidth + 4 * spacing)) / 2;
    final double pillarsY = bankY + bankHeight - baseHeight - pillarHeight;

    if(pillar1InBank)
{
      final double x = pillarsStartX;
      canvas.drawRect(
        Rect.fromLTWH(x, pillarsY, pillarWidth, pillarHeight),
        bankPaint,
      );
    }
    for(int i = 1; i <= 3; i++)
{
      final double x = pillarsStartX + i * (pillarWidth + spacing);
      canvas.drawRect(
        Rect.fromLTWH(x, pillarsY, pillarWidth, pillarHeight),
        bankPaint,
      );
    }
    if(pillar5InBank)
{
      final double x = pillarsStartX + 4 * (pillarWidth + spacing);
      canvas.drawRect(
        Rect.fromLTWH(x, pillarsY, pillarWidth, pillarHeight),
        bankPaint,
      );
    }

    final roofPath = Path();
    final double roofBase = pillarsY - bankHeight * 0.05;
    final double roofPeakY = bankY + bankHeight * 0.05;
    roofPath.moveTo(bankX + bankWidth * 0.15, roofBase);
    roofPath.lineTo(bankX + bankWidth * 0.85, roofBase);
    roofPath.lineTo(bankX + bankWidth / 2, roofPeakY);
    roofPath.close();
    canvas.drawPath(roofPath, bankPaint);

    final double groundY = bankY + bankHeight;

    if(pillar1OnGround)
{
      final double groundPillarX = w * 0.12;
      canvas.drawRect(
        Rect.fromLTWH(groundPillarX, groundY - pillarHeight, pillarWidth, pillarHeight),
        bankPaint,
      );
    }
    if(pillar5OnGround)
{
      final double groundPillarX = w * 0.88 - pillarWidth / 2;
      canvas.drawRect(
        Rect.fromLTWH(groundPillarX, groundY - pillarHeight, pillarWidth, pillarHeight),
        bankPaint,
      );
    }

    final double crane1Progress = progress;
    final double crane2Progress = (progress + 0.5) % 1.0;

    _drawCrane1(canvas, size, crane1Progress, cranePaint, craneMetalPaint,
        hookPaint, cablePaint, pillarWidth, pillarHeight, bankPaint, pillarsY, groundY, cycle1Active);
    _drawCrane2(canvas, size, crane2Progress, cranePaint, craneMetalPaint,
        hookPaint, cablePaint, pillarWidth, pillarHeight, bankPaint, pillarsY, groundY, cycle1Active);
  }

  void _drawCrane1(
      Canvas canvas, Size size, double progress, Paint cranePaint,
      Paint craneMetalPaint, Paint hookPaint, Paint cablePaint,
      double pillarWidth, double pillarHeight, Paint bankPaint,
      double pillarsY, double groundY, bool cycle1Active)
  {
    final w = size.width;

    final double craneBaseX = w * 0.08;
    const double craneBaseWidth = 10;
    const double towerHeight = 150;
    const double jibLength = 100;

    final double towerTopY = groundY - towerHeight;
    final double jibX = craneBaseX + craneBaseWidth / 2;
    final double jibY = towerTopY - 5;

    const double counterweightLength = 35;
    canvas.drawRect(Rect.fromLTWH(craneBaseX, groundY - 10, craneBaseWidth, 10), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(craneBaseX, towerTopY, craneBaseWidth, towerHeight), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(jibX, jibY, jibLength, 5), cranePaint);
    canvas.drawRect(Rect.fromLTWH(jibX - counterweightLength, jibY, counterweightLength, 5), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(jibX - 5, jibY + 5, 10, 10), craneMetalPaint);

    double trolleyXProgress = 0.0;
    double hookY = jibY;
    bool drawPillar = false;

    final double bankEntranceY = pillarsY + pillarHeight * 0.6;
    final double groundPillarY = groundY - pillarHeight;

    const double idlePos = 0.3;
    const double bankPos = 0.7;
    const double groundPos = 0.2;

    if(cycle1Active)
{
      if(progress < 0.12)
{
        trolleyXProgress = idlePos + (bankPos - idlePos) * (progress / 0.12);
        hookY = jibY;
      }
      else if(progress < 0.20)
{
        trolleyXProgress = bankPos;
        hookY = jibY + (bankEntranceY - jibY) * ((progress - 0.12) / 0.08);
      }
      else if(progress < 0.30)
{
        trolleyXProgress = bankPos;
        final liftProgress = (progress - 0.20) / 0.10;
        hookY = bankEntranceY - (bankEntranceY - jibY) * liftProgress;
        drawPillar = liftProgress > 0.8;
      }
      else if(progress < 0.42)
{
        trolleyXProgress = bankPos - (bankPos - groundPos) * ((progress - 0.30) / 0.12);
        hookY = jibY;
        drawPillar = true;
      }
      else if(progress < 0.52)
{
        trolleyXProgress = groundPos;
        hookY = jibY + (groundPillarY - jibY) * ((progress - 0.42) / 0.10);
        drawPillar = true;
      }
      else if(progress < 0.62)
{
        trolleyXProgress = groundPos;
        final liftProgress = (progress - 0.52) / 0.10;
        hookY = groundPillarY - (groundPillarY - jibY) * liftProgress;
        drawPillar = liftProgress < 0.2;
      }
      else
{
        trolleyXProgress = groundPos + (idlePos - groundPos) * ((progress - 0.62) / 0.38);
        hookY = jibY;
      }
    }
    else
{
      if(progress < 0.12)
{
        trolleyXProgress = idlePos - (idlePos - groundPos) * (progress / 0.12);
        hookY = jibY;
      }
      else if(progress < 0.20)
{
        trolleyXProgress = groundPos;
        hookY = jibY + (groundPillarY - jibY) * ((progress - 0.12) / 0.08);
      }
      else if(progress < 0.30)
{
        trolleyXProgress = groundPos;
        final liftProgress = (progress - 0.20) / 0.10;
        hookY = groundPillarY - (groundPillarY - jibY) * liftProgress;
        drawPillar = liftProgress > 0.8;
      }
      else if(progress < 0.42)
{
        trolleyXProgress = groundPos + (bankPos - groundPos) * ((progress - 0.30) / 0.12);
        hookY = jibY;
        drawPillar = true;
      }
      else if(progress < 0.52)
{
        trolleyXProgress = bankPos;
        hookY = jibY + (bankEntranceY - jibY) * ((progress - 0.42) / 0.10);
        drawPillar = true;
      }
      else if(progress < 0.62)
{
        trolleyXProgress = bankPos;
        final liftProgress = (progress - 0.52) / 0.10;
        hookY = bankEntranceY - (bankEntranceY - jibY) * liftProgress;
        drawPillar = liftProgress < 0.2;
      }
      else
{
        trolleyXProgress = bankPos - (bankPos - idlePos) * ((progress - 0.62) / 0.38);
        hookY = jibY;
      }
    }

    final double hookX = jibX + jibLength * trolleyXProgress;
    canvas.drawRect(Rect.fromLTWH(hookX - 2, jibY - 2, 4, 7), craneMetalPaint);
    canvas.drawLine(Offset(hookX, jibY + 2.5), Offset(hookX, hookY), cablePaint);
    canvas.drawRect(Rect.fromLTWH(hookX - 4, hookY, 8, 4), hookPaint);

    if(drawPillar)
{
      canvas.drawRect(
        Rect.fromLTWH(hookX - pillarWidth / 2, hookY + 4, pillarWidth, pillarHeight),
        bankPaint,
      );
    }
  }

  void _drawCrane2(
      Canvas canvas, Size size, double progress, Paint cranePaint,
      Paint craneMetalPaint, Paint hookPaint, Paint cablePaint,
      double pillarWidth, double pillarHeight, Paint bankPaint,
      double pillarsY, double groundY, bool cycle1Active)
  {
    final w = size.width;

    final double craneBaseX = w * 0.92;
    const double craneBaseWidth = 10;
    const double towerHeight = 150;
    const double jibLength = 100;

    final double towerTopY = groundY - towerHeight;
    final double jibX = craneBaseX - craneBaseWidth / 2;
    final double jibY = towerTopY - 5;

    const double counterweightLength = 35;
    canvas.drawRect(Rect.fromLTWH(craneBaseX - craneBaseWidth, groundY - 10, craneBaseWidth, 10), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(craneBaseX - craneBaseWidth, towerTopY, craneBaseWidth, towerHeight), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(jibX - jibLength, jibY, jibLength, 5), cranePaint);
    canvas.drawRect(Rect.fromLTWH(jibX, jibY, counterweightLength, 5), craneMetalPaint);
    canvas.drawRect(Rect.fromLTWH(jibX - 5, jibY + 5, 10, 10), craneMetalPaint);

    double trolleyXProgress = 0.0;
    double hookY = jibY;
    bool drawPillar = false;

    final double bankEntranceY = pillarsY + pillarHeight * 0.6;
    final double groundPillarY = groundY - pillarHeight;

    const double idlePos = 0.9;
    const double bankPos = 0.7;
    const double groundPos = 0.2;

    if(cycle1Active)
{
      if(progress < 0.12)
{
        trolleyXProgress = idlePos - (idlePos - groundPos) * (progress / 0.12);
        hookY = jibY;
      }
      else if(progress < 0.20)
{
        trolleyXProgress = groundPos;
        hookY = jibY + (groundPillarY - jibY) * ((progress - 0.12) / 0.08);
      }
      else if(progress < 0.30)
{
        trolleyXProgress = groundPos;
        final liftProgress = (progress - 0.20) / 0.10;
        hookY = groundPillarY - (groundPillarY - jibY) * liftProgress;
        drawPillar = liftProgress > 0.8;
      }
      else if(progress < 0.42)
{
        trolleyXProgress = groundPos + (bankPos - groundPos) * ((progress - 0.30) / 0.12);
        hookY = jibY;
        drawPillar = true;
      }
      else if(progress < 0.52)
{
        trolleyXProgress = bankPos;
        hookY = jibY + (bankEntranceY - jibY) * ((progress - 0.42) / 0.10);
        drawPillar = true;
      }
      else if(progress < 0.62)
{
        trolleyXProgress = bankPos;
        final liftProgress = (progress - 0.52) / 0.10;
        hookY = bankEntranceY - (bankEntranceY - jibY) * liftProgress;
        drawPillar = liftProgress < 0.2;
      }
      else
{
        trolleyXProgress = bankPos + (idlePos - bankPos) * ((progress - 0.62) / 0.38);
        hookY = jibY;
      }
    }
    else
{
      if(progress < 0.12)
{
        trolleyXProgress = idlePos - (idlePos - bankPos) * (progress / 0.12);
        hookY = jibY;
      }
      else if(progress < 0.20)
{
        trolleyXProgress = bankPos;
        hookY = jibY + (bankEntranceY - jibY) * ((progress - 0.12) / 0.08);
      }
      else if(progress < 0.30)
{
        trolleyXProgress = bankPos;
        final liftProgress = (progress - 0.20) / 0.10;
        hookY = bankEntranceY - (bankEntranceY - jibY) * liftProgress;
        drawPillar = liftProgress > 0.8;
      }
      else if(progress < 0.42)
{
        trolleyXProgress = bankPos - (bankPos - groundPos) * ((progress - 0.30) / 0.12);
        hookY = jibY;
        drawPillar = true;
      }
      else if(progress < 0.52)
{
        trolleyXProgress = groundPos;
        hookY = jibY + (groundPillarY - jibY) * ((progress - 0.42) / 0.10);
        drawPillar = true;
      }
      else if(progress < 0.62)
{
        trolleyXProgress = groundPos;
        final liftProgress = (progress - 0.52) / 0.10;
        hookY = groundPillarY - (groundPillarY - jibY) * liftProgress;
        drawPillar = liftProgress < 0.2;
      }
      else
{
        trolleyXProgress = groundPos + (idlePos - groundPos) * ((progress - 0.62) / 0.38);
        hookY = jibY;
      }
    }

    final double hookX = jibX - jibLength * trolleyXProgress;
    canvas.drawRect(Rect.fromLTWH(hookX - 2, jibY - 2, 4, 7), craneMetalPaint);
    canvas.drawLine(Offset(hookX, jibY + 2.5), Offset(hookX, hookY), cablePaint);
    canvas.drawRect(Rect.fromLTWH(hookX - 4, hookY, 8, 4), hookPaint);

    if(drawPillar)
{
      canvas.drawRect(
        Rect.fromLTWH(hookX - pillarWidth / 2, hookY + 4, pillarWidth, pillarHeight),
        bankPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

