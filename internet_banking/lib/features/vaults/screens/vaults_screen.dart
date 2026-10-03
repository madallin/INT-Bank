import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_config.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../../widgets/simple_app_bar.dart';
import '../services/round_up_engine.dart';
import '../services/savings_vault_service.dart';

class VaultsScreen extends StatefulWidget {
  final int userId;

  const VaultsScreen({super.key, required this.userId});

  @override
  State<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends State<VaultsScreen> {
  final SavingsVaultService _vaultService = SavingsVaultService();

  // In-memory persistent state initialized with realistic banking defaults
  late List<SavingsVault> _vaults;
  RoundUpRule _roundUpRule = const RoundUpRule(
    enabled: true,
    boundary: RoundUpBoundary.nearestFive,
    multiplier: 1,
    targetVaultId: 'vault-1',
  );

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _vaults = [
      SavingsVault(
        id: 'vault-1',
        name: 'Fond de Urgență',
        targetAmount: 10000.0,
        currentAmount: 6500.0,
        currency: 'RON',
        targetDate: now.add(const Duration(days: 180)),
        lockType: VaultLockType.flexible,
        interestRateAnnualPercent: 5.5,
        status: VaultStatus.active,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      SavingsVault(
        id: 'vault-2',
        name: 'Vacanță Grecia',
        targetAmount: 4000.0,
        currentAmount: 4000.0,
        currency: 'RON',
        targetDate: now.add(const Duration(days: 60)),
        lockType: VaultLockType.lockedUntilDate,
        interestRateAnnualPercent: 6.0,
        status: VaultStatus.goalReached,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      SavingsVault(
        id: 'vault-3',
        name: 'Upgrade Laptop',
        targetAmount: 8500.0,
        currentAmount: 2200.0,
        currency: 'RON',
        targetDate: now.add(const Duration(days: 270)),
        lockType: VaultLockType.flexible,
        interestRateAnnualPercent: 4.8,
        status: VaultStatus.active,
        createdAt: now.subtract(const Duration(days: 30)),
      ),
    ];
  }

  double get _totalSaved => _vaults.fold(0.0, (sum, v) => sum + v.currentAmount);
  double get _totalTarget => _vaults.fold(0.0, (sum, v) => sum + v.targetAmount);

  void _depositToVault(SavingsVault vault, double amount) {
    HapticFeedbackHelper.selection();
    try {
      final updated = _vaultService.deposit(vault, amount);
      setState(() {
        final index = _vaults.indexWhere((v) => v.id == vault.id);
        if (index != -1) _vaults[index] = updated;
      });
      HapticFeedbackHelper.success();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ai adăugat ${amount.toStringAsFixed(0)} RON în seiful "${vault.name}"!',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(lightForestGreenColor),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      HapticFeedbackHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _withdrawFromVault(SavingsVault vault, double amount) {
    HapticFeedbackHelper.selection();
    try {
      final updated = _vaultService.withdraw(
        vault,
        amount,
        currentDate: DateTime.now(),
        emergencyBreakLock: true,
      );
      setState(() {
        final index = _vaults.indexWhere((v) => v.id == vault.id);
        if (index != -1) _vaults[index] = updated;
      });
      HapticFeedbackHelper.buttonTap();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ai retras ${amount.toStringAsFixed(0)} RON din "${vault.name}" în contul principal.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(darkForestGreenColor),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      HapticFeedbackHelper.error();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Eroare: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openAmountSheet(SavingsVault vault, bool isDeposit) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDeposit ? 'Alimentează Seif' : 'Retrage din Seif',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(darkGreyColor),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              vault.name,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: '0.00',
                suffixText: 'RON',
                suffixStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(lightForestGreenColor), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(controller.text.replaceAll(',', '.'));
                if (amount != null && amount > 0) {
                  Navigator.pop(ctx);
                  if (isDeposit) {
                    _depositToVault(vault, amount);
                  } else {
                    _withdrawFromVault(vault, amount);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDeposit ? const Color(lightForestGreenColor) : Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                isDeposit ? 'Confirmă Alimentarea' : 'Confirmă Retragerea',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateVaultSheet() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    VaultLockType lockType = VaultLockType.flexible;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Creează Seif Nou',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(darkGreyColor),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nume Seif (ex: Fond de Urgență, Vacanță)',
                  labelStyle: GoogleFonts.inter(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Țintă de Economisire (RON)',
                  labelStyle: GoogleFonts.inter(fontSize: 13),
                  suffixText: 'RON',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<VaultLockType>(
                value: lockType,
                decoration: InputDecoration(
                  labelText: 'Tip Seif',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: VaultLockType.flexible,
                    child: Text('Flexibil (retrageri oricând fără penalizare)'),
                  ),
                  DropdownMenuItem(
                    value: VaultLockType.lockedUntilDate,
                    child: Text('Blocat până la scadență (dobândă superioară 6%)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setSheetState(() => lockType = val);
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final target = double.tryParse(targetCtrl.text.replaceAll(',', '.'));
                  if (name.isNotEmpty && target != null && target > 0) {
                    final newVault = SavingsVault(
                      id: 'vault-${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      targetAmount: target,
                      currentAmount: 0.0,
                      currency: 'RON',
                      targetDate: DateTime.now().add(const Duration(days: 180)),
                      lockType: lockType,
                      interestRateAnnualPercent: lockType == VaultLockType.lockedUntilDate ? 6.0 : 4.5,
                      status: VaultStatus.active,
                      createdAt: DateTime.now(),
                    );
                    setState(() => _vaults.add(newVault));
                    Navigator.pop(ctx);
                    HapticFeedbackHelper.success();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Seiful "$name" a fost creat cu succes!'),
                        backgroundColor: const Color(lightForestGreenColor),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(lightForestGreenColor),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Creează Seiful', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overallProgress = _totalTarget > 0 ? (_totalSaved / _totalTarget).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SimpleAppBar(
        title: 'Seifuri de Economii',
        onBack: () => Navigator.pop(context),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateVaultSheet,
        backgroundColor: const Color(lightForestGreenColor),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Seif Nou', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Summary Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(lightForestGreenColor), Color(darkForestGreenColor)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(lightForestGreenColor).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL ECONOMII',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(overallProgress * 100).toStringAsFixed(0)}% atins',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_totalSaved.toStringAsFixed(2)} RON',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Țintă totală: ${_totalTarget.toStringAsFixed(0)} RON',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: overallProgress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Spare-Change Round-Up Feature Box
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(lightForestGreenColor).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.toll_rounded,
                          color: Color(lightForestGreenColor),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mărunțiș Automat (Round-Up)',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(darkGreyColor),
                              ),
                            ),
                            Text(
                              'Rotunjește plățile cu cardul și economisește restul.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _roundUpRule.enabled,
                        activeColor: const Color(lightForestGreenColor),
                        onChanged: (val) {
                          HapticFeedbackHelper.selection();
                          setState(() {
                            _roundUpRule = _roundUpRule.copyWith(enabled: val);
                          });
                        },
                      ),
                    ],
                  ),
                  if (_roundUpRule.enabled) ...[
                    const Divider(height: 24),
                    Text(
                      'Multiplicator economisire:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [1, 2, 3].map((mult) {
                        final isSelected = _roundUpRule.multiplier == mult;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${mult}x'),
                            selected: isSelected,
                            selectedColor: const Color(lightForestGreenColor),
                            labelStyle: GoogleFonts.inter(
                              color: isSelected ? Colors.white : const Color(darkGreyColor),
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) {
                              HapticFeedbackHelper.selection();
                              setState(() {
                                _roundUpRule = _roundUpRule.copyWith(multiplier: mult);
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text(
              'SEIFURILE TALE ACTIVE',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Vault Cards
            ..._vaults.map((vault) {
              final progress = _vaultService.calculateProgressPercentage(vault);
              final isReached = vault.status == VaultStatus.goalReached;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isReached
                      ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                      : Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isReached
                                    ? const Color(0xFFF59E0B).withOpacity(0.12)
                                    : const Color(lightForestGreenColor).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isReached ? Icons.stars_rounded : Icons.savings_rounded,
                                color: isReached
                                    ? const Color(0xFFF59E0B)
                                    : const Color(lightForestGreenColor),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vault.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(darkGreyColor),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      vault.lockType == VaultLockType.lockedUntilDate
                                          ? Icons.lock_outline_rounded
                                          : Icons.lock_open_rounded,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      vault.lockType == VaultLockType.lockedUntilDate
                                          ? 'Blocat până la ${vault.targetDate.day}.${vault.targetDate.month}.${vault.targetDate.year}'
                                          : 'Flexibil',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(lightForestGreenColor).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${vault.interestRateAnnualPercent}% p.a.',
                            style: GoogleFonts.inter(
                              color: const Color(lightForestGreenColor),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${vault.currentAmount.toStringAsFixed(0)} RON',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(darkGreyColor),
                          ),
                        ),
                        Text(
                          'din ${vault.targetAmount.toStringAsFixed(0)} RON (${progress.toStringAsFixed(0)}%)',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (progress / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isReached
                              ? const Color(0xFFF59E0B)
                              : const Color(lightForestGreenColor),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openAmountSheet(vault, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                              'Retrage',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(darkGreyColor),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _openAmountSheet(vault, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(lightForestGreenColor),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: Text(
                              'Alimentează',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
