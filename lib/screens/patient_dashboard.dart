import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/models/plan_config.dart';
import 'package:gluco_care_app/widgets/health_charts.dart';
import 'package:intl/intl.dart';
import 'add_entry_modal.dart';
import 'welcome_screen.dart';
import 'plan_care_screen.dart';
import 'notification_settings_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _isLoading = false;
  int _currentIndex = 0;
  int _visibleCount = 20;
  final Map<String, ProductDetails> _products = {};

  static const Set<String> _productIds = {
    'glucocare_pro_monthly',
    'glucocare_pro_yearly',
  };

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _loadProducts();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () => _subscription.cancel(),
      onError: (error) => _showSnackBar("Error de conexión"),
    );
  }

  Future<void> _loadProducts() async {
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) return;
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(_productIds);
      if (mounted && response.productDetails.isNotEmpty) {
        setState(() {
          for (final p in response.productDetails) {
            _products[p.id] = p;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _checkAuthStatus() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // LISTA DE PESTAÑAS
    final List<Widget> screens = [
      _buildHomeContent(user), // TU DASHBOARD ACTUAL
      const PlanCareScreen(),   // LA NUEVA AGENDA
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: const Color(0xFF1E2746),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Resumen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Mi Plan',
          ),
        ],
      ),
    );
  }

  // --- TU DISEÑO ORIGINAL ENCAPSULADO (SIN CAMBIOS) ---
  Widget _buildHomeContent(User user) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final plan = PlanConfig.getSettings(
          userData?['subscription_status'] ?? 'free',
        );

        DateTime cutOffDate = DateTime.now().subtract(
          Duration(days: plan.historyDays),
        );
        Timestamp cutOffTimestamp = Timestamp.fromDate(cutOffDate);

        final String subStatus = userData?['subscription_status'] ?? 'free';
        final bool isPremium = subStatus == 'pro' || subStatus == 'premium' || subStatus == 'ideal';

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF0F2F8),
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: isDark ? Colors.white : Colors.black,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hola, ${() {
                    final raw = (userData?['full_name'] as String? ?? '').trim();
                    if (raw.isNotEmpty) return raw.split(' ').first;
                    final authName = (user.displayName ?? '').trim();
                    if (authName.isNotEmpty) return authName.split(' ').first;
                    return 'Paciente';
                  }()}",
                  style: TextStyle(
                    fontSize: 19,
                    color: isDark ? Colors.blueAccent : Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Tu Resumen de Salud",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _generatedLinkingCode,
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
                color: Colors.blue,
                tooltip: 'Configurar notificaciones',
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () => FirebaseAuth.instance.signOut(),
                color: Colors.blue,
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('glucose_logs')
                .where('user_id', isEqualTo: user.uid)
                .where('created_at', isGreaterThanOrEqualTo: cutOffTimestamp)
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, glucoseSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('blood_pressure_logs')
                    .where('user_id', isEqualTo: user.uid)
                    .where(
                      'created_at',
                      isGreaterThanOrEqualTo: cutOffTimestamp,
                    )
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (context, pressureSnapshot) {
                  if (glucoseSnapshot.hasError) {
                    return Center(
                      child: SelectableText("ERROR GLUCOSA: ${glucoseSnapshot.error}"),
                    );
                  }
                  if (pressureSnapshot.hasError) {
                    return Center(
                      child: SelectableText("ERROR PRESIÓN: ${pressureSnapshot.error}"),
                    );
                  }
                  if (!glucoseSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<Map<String, dynamic>> allLogs = [];
                  for (var doc in glucoseSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['type'] = 'glucose';
                    data['id'] = doc.id;
                    allLogs.add(data);
                  }
                  if (pressureSnapshot.hasData && pressureSnapshot.data != null) {
                    for (var doc in pressureSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      data['type'] = 'pressure';
                      data['id'] = doc.id;
                      allLogs.add(data);
                    }
                  }
                  allLogs.sort((a, b) => (b['created_at'] as Timestamp).compareTo(a['created_at'] as Timestamp));

                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildSubscriptionBanner(userData?['subscription_status'] ?? 'free'),
                          _buildQuickSummary(allLogs, isDark),
                          const SizedBox(height: 30),
                          HealthChart(allLogs: allLogs, isPremium: isPremium),
                          const SizedBox(height: 30),
                          _buildHistoryHeader(allLogs, user, isPremium),
                          const SizedBox(height: 10),
                          if (allLogs.isEmpty)
                            _buildEmptyState(isDark)
                          else ...[
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: min(_visibleCount, allLogs.length),
                              itemBuilder: (context, index) {
                                final logData = allLogs[index];
                                return _buildUnifiedLogTile(
                                  logData,
                                  onEdit: () => _showAddEntry(context, logData),
                                  onDelete: () => _confirmDelete(logData),
                                );
                              },
                            ),
                            if (allLogs.length > _visibleCount)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => setState(() => _visibleCount += 20),
                                        icon: const Icon(Icons.expand_more_rounded),
                                        label: Text(
                                          "Ver más  (${allLogs.length - _visibleCount} restantes)",
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (allLogs.length > 20)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => _visibleCount = 20),
                                    child: const Text("Mostrar menos"),
                                  ),
                                ),
                              ),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEntry(context),
            backgroundColor: const Color(0xFF1E2746),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text("Añadir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  // --- ABAJO SE MANTIENEN TODOS TUS MÉTODOS DE APOYO EXACTAMENTE IGUAL ---

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.assignment_late_outlined, size: 80, color: isDark ? Colors.white24 : Colors.grey.shade300),
            const SizedBox(height: 20),
            Text("¡Empieza tu camino hoy!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(height: 10),
            const Text("Aún no tienes registros de salud.\nPresiona el botón '+' para añadir el primero.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSummary(List<Map<String, dynamic>> logs, bool isDark) {
    final lastGluc = logs.firstWhere((l) => l['type'] == 'glucose', orElse: () => {});
    final lastPress = logs.firstWhere((l) => l['type'] == 'pressure', orElse: () => {});
    return Row(
      children: [
        _summaryCard("Glucosa", lastGluc['value']?.toString() ?? "--", "mg/dL", Icons.water_drop, Colors.blue, isDark),
        const SizedBox(width: 15),
        _summaryCard("Presión", lastPress['systolic'] != null ? "${lastPress['systolic']}/${lastPress['diastolic']}" : "--", "mmHg", Icons.favorite, Colors.redAccent, isDark),
      ],
    );
  }

  Widget _summaryCard(String title, String value, String unit, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.08), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 15),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("$title ($unit)", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(List<Map<String, dynamic>> allLogs, User user, bool isPremium) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final String status = userData?['subscription_status'] ?? 'free';
        final bool hasPdfAccess = status != 'free';
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Historial Médico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            TextButton.icon(
              onPressed: hasPdfAccess ? () => _generatePdfReport(allLogs, user.displayName ?? "Paciente", status == 'premium') : () => _showSnackBar("Función disponible en el Plan Ideal"),
              icon: Icon(Icons.picture_as_pdf_rounded, color: hasPdfAccess ? Colors.redAccent : Colors.grey.withOpacity(0.5), size: 18),
              label: Text("PDF", style: TextStyle(color: hasPdfAccess ? Theme.of(context).colorScheme.onSurface : Colors.grey.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 12)),
              style: TextButton.styleFrom(backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnifiedLogTile(
    Map<String, dynamic> data, {
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final bool isGluc = data['type'] == 'glucose';
    final DateTime date = (data['created_at'] as Timestamp).toDate();
    final bool isHigh = data['is_high_risk'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHigh ? Colors.red.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isGluc ? Colors.blue : Colors.red).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              isGluc ? Icons.bloodtype_outlined : Icons.favorite_outline,
              color: isGluc ? Colors.blue : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGluc
                      ? "${data['value']} mg/dL"
                      : "${data['systolic']}/${data['diastolic']} mmHg",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  DateFormat('hh:mm a • d MMM').format(date),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isHigh)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "ALERTA",
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: Colors.blueAccent),
                    SizedBox(width: 10),
                    Text("Editar"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text("Eliminar", style: TextStyle(color: Colors.redAccent)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEntry(BuildContext context, [Map<String, dynamic>? initialData]) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: AddEntryModal(initialData: initialData)));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  String _getRelativeDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) return "Hoy";
    if (date.day == now.day - 1) return "Ayer";
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      _handlePurchaseUpdate(purchaseDetails);
    }
  }

  Future<void> _handlePurchaseUpdate(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored) {
      await _updateUserSubscription(purchaseDetails.productID);
      _showSnackBar("¡Felicidades! Plan Pro activado.");
    } else if (purchaseDetails.status == PurchaseStatus.error) {
      _showSnackBar(
        "Error en la compra: ${purchaseDetails.error?.message ?? 'Inténtalo de nuevo'}",
      );
    } else if (purchaseDetails.status == PurchaseStatus.canceled) {
      _showSnackBar("Compra cancelada.");
    }
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
    }
  }

  // period: 'monthly' | 'yearly'
  Future<void> _startPurchaseFlow(String period) async {
    setState(() => _isLoading = true);
    try {
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        _showSnackBar("La tienda no está disponible en este momento.");
        return;
      }

      final String productId = 'glucocare_pro_$period';

      // Use cached ProductDetails when available to avoid an extra network call
      final ProductDetails? cached = _products[productId];
      if (cached != null) {
        final PurchaseParam purchaseParam = PurchaseParam(productDetails: cached);
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
        return;
      }

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails({productId});

      if (response.notFoundIDs.isNotEmpty) {
        final String storeName =
            Platform.isIOS ? 'App Store Connect' : 'Google Play Console';
        _showSnackBar(
          "Producto no disponible. Configúralo en $storeName "
          "y prueba en un dispositivo real con cuenta sandbox.",
        );
        return;
      }

      final PurchaseParam purchaseParam =
          PurchaseParam(productDetails: response.productDetails.first);
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _showSnackBar("Error al iniciar la compra: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUserSubscription(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // All active product IDs (new and legacy) map to 'pro'
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'subscription_status': 'pro'});
    setState(() {});
  }

  Future<void> _confirmDelete(Map<String, dynamic> data) async {
    final String? docId = data['id'];
    if (docId == null) return;

    final bool isGluc = data['type'] == 'glucose';
    final String label = isGluc ? 'glucosa' : 'presión arterial';
    final String value = isGluc
        ? "${data['value']} mg/dL"
        : "${data['systolic']}/${data['diastolic']} mmHg";

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Eliminar registro?"),
        content: Text(
          "Se eliminará el registro de $label ($value). Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCELAR"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("ELIMINAR"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection(isGluc ? 'glucose_logs' : 'blood_pressure_logs')
        .doc(docId)
        .delete();

    _showSnackBar("Registro eliminado");
  }

  Future<void> _generatedLinkingCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String code = String.fromCharCodes(Iterable.generate(6, (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'.codeUnitAt(Random().nextInt(32))));
    await FirebaseFirestore.instance.collection('connections').doc(code).set({'patientId': user.uid, 'patientName': user.displayName ?? 'Familiar', 'expiresAt': DateTime.now().add(const Duration(hours: 1))});
    _showCodeDialog(code);
  }

  void _showCodeDialog(String code) {
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Código de Vinculación"), content: Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar"))]));
  }

  Future<void> _generatePdfReport(List<Map<String, dynamic>> allLogs, String patientName, bool isPremium) async {
    final pdf = pw.Document();
    final glucoseLogs = allLogs.where((l) => l['type'] == 'glucose').toList();
    final pressureLogs = allLogs.where((l) => l['type'] == 'pressure').toList();
    pdf.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("Paciente: $patientName")),
      if (glucoseLogs.isNotEmpty) pw.TableHelper.fromTextArray(data: glucoseLogs.map((l) => [DateFormat('dd/MM').format((l['created_at'] as Timestamp).toDate()), l['timing'], "${l['value']} mg/dL"]).toList()),
      if (pressureLogs.isNotEmpty) pw.TableHelper.fromTextArray(data: pressureLogs.map((l) => [DateFormat('dd/MM').format((l['created_at'] as Timestamp).toDate()), "${l['systolic']}/${l['diastolic']}", "${l['pulse']} LPM"]).toList()),
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void _showPremiumModal(BuildContext context) {
    bool isYearly = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? Colors.blue.shade300 : const Color(0xFF1E2746);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final period = isYearly ? 'yearly' : 'monthly';
          final proPrice = _products['glucocare_pro_$period']?.price
              ?? (isYearly ? r'$39.99' : r'$4.99');

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "GlucoCare Pro",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "28 días de prueba gratis · Cancela cuando quieras",
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _periodTab("Mensual", !isYearly, isDark,
                          () => setModalState(() => isYearly = false)),
                      _periodTab("Anual  −33%", isYearly, isDark,
                          () => setModalState(() => isYearly = true)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildPlanCard(
                  title: "Plan Pro",
                  displayPrice: proPrice,
                  isYearly: isYearly,
                  isDark: isDark,
                  features: [
                    "Historial ilimitado",
                    "Hasta 5 cuidadores",
                    "Exportar PDF",
                    "28 días de prueba gratis",
                  ],
                  icon: Icons.all_inclusive,
                  accentColor: accentColor,
                  onTap: () {
                    Navigator.pop(context);
                    _startPurchaseFlow(period);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodTab(String label, bool active, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.blue.shade700 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? Colors.white
                  : isDark
                      ? Colors.grey.shade300
                      : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String displayPrice,
    required bool isYearly,
    required bool isDark,
    required List<String> features,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    bool isBestSeller = false,
  }) {
    final String period = isYearly ? '/año' : '/mes';
    final cardBg = isDark ? const Color(0xFF252D3D) : Colors.white;
    final borderColor = isDark ? Colors.blue.shade700 : const Color(0xFF1E2746);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                if (isBestSeller) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "POPULAR",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: displayPrice,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      TextSpan(
                        text: period,
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 15, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      f,
                      style: TextStyle(fontSize: 13, color: subTextColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  "Comenzar prueba gratis",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionBanner(String currentStatus) {
    if (currentStatus != 'free') return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _showPremiumModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Activa GlucoCare Pro — 28 días gratis", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text("Sin compromiso · Cancela cuando quieras", style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text("VER PLANES", style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}