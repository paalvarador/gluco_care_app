import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gluco_care_app/models/plan_config.dart';
import 'package:gluco_care_app/widgets/health_charts.dart';
import 'package:intl/intl.dart';
import 'add_entry_modal.dart';
import 'welcome_screen.dart';
import 'plan_care_screen.dart'; // Asegúrate de crear este archivo
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
  int _currentIndex = 0; // NUEVO: Control de pestaña

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
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

        final bool isPremium = userData?['subscription_status'] == 'premium';

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
                  "Hola, ${userData?['full_name']?.split(' ')[0] ?? 'Paciente'}",
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
                    color: Colors.blue.withOpacity(0.1),
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
                          allLogs.isEmpty
                              ? _buildEmptyState(isDark)
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: allLogs.length,
                                  itemBuilder: (context, index) {
                                    final logData = allLogs[index];
                                    return Dismissible(
                                      key: Key(logData['id'] ?? index.toString()),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                                        child: const Icon(Icons.delete_sweep, color: Colors.white),
                                      ),
                                      confirmDismiss: (direction) => _confirmDelete(logData),
                                      child: InkWell(
                                        onLongPress: () => _showAddEntry(context, logData),
                                        borderRadius: BorderRadius.circular(20),
                                        child: _buildUnifiedLogTile(logData),
                                      ),
                                    );
                                  },
                                ),
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

  Widget _buildUnifiedLogTile(Map<String, dynamic> data) {
    final bool isGluc = data['type'] == 'glucose';
    final DateTime date = (data['created_at'] as Timestamp).toDate();
    final bool isHigh = data['is_high_risk'] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: isHigh ? Colors.red.withOpacity(0.2) : Colors.transparent)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isGluc ? Colors.blue : Colors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(isGluc ? Icons.bloodtype_outlined : Icons.favorite_outline, color: isGluc ? Colors.blue : Colors.red, size: 22)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isGluc ? "${data['value']} mg/dL" : "${data['systolic']}/${data['diastolic']} mmHg", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(DateFormat('hh:mm a • d MMM').format(date), style: TextStyle(color: Colors.grey.shade500, fontSize: 12))])),
          if (isHigh) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Text("ALERTA", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
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
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        await _updateUserSubscription(purchaseDetails.productID);
        _showSnackBar("¡Felicidades! Ya eres Premium.");
      }
      if (purchaseDetails.pendingCompletePurchase) await _inAppPurchase.completePurchase(purchaseDetails);
    });
  }

  Future<void> _startPurchaseFlow(String planType) async {
    setState(() => _isLoading = true);
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) { _showSnackBar("La tienda no está disponible."); return; }
    String productId = planType == 'basic' ? 'glucocare_basic_new' : (planType == 'ideal' ? 'glucocare_ideal_new' : 'glucocare_premium_new');
    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({productId});
    if (response.notFoundIDs.isNotEmpty) { _showSnackBar("No se encontró el producto."); return; }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: response.productDetails.first);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    setState(() => _isLoading = false);
  }

  Future<void> _updateUserSubscription(String productId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String finalStatus = productId.contains('basic') ? 'basic' : (productId.contains('ideal') ? 'ideal' : 'premium');
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'subscription_status': finalStatus});
    setState(() {});
  }

  Future<bool?> _confirmDelete(Map<String, dynamic> data) async {
    final String? docId = data['id'];
    if (docId == null) return false;
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¿Borrar registro?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(onPressed: () async {
            await FirebaseFirestore.instance.collection(data['type'] == 'glucose' ? 'glucose_logs' : 'blood_pressure_logs').doc(docId).delete();
            Navigator.pop(context, true);
            _showSnackBar("Registro eliminado");
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("BORRAR")),
        ],
      ),
    );
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
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))), builder: (context) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      _buildPlanCard(title: "Plan Básico", price: "4.99", description: "30 días", icon: Icons.person, color: Colors.blueGrey, onTap: () => _startPurchaseFlow('basic')),
      _buildPlanCard(title: "Plan Ideal", price: "9.99", description: "90 días", icon: Icons.star, color: Colors.blue, onTap: () => _startPurchaseFlow('ideal'), isBestSeller: true),
      _buildPlanCard(title: "Plan Premium", price: "14.99", description: "Ilimitado", icon: Icons.all_inclusive, color: const Color(0xFF1E2746), onTap: () => _startPurchaseFlow('premium')),
    ])));
  }

  Widget _buildPlanCard({required String title, required String price, required String description, required IconData icon, required Color color, required VoidCallback onTap, bool isBestSeller = false}) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isBestSeller ? color : Colors.grey.shade200, width: 2)), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(description, style: const TextStyle(fontSize: 12))])), Text("\$$price")])));
  }

  Widget _buildSubscriptionBanner(String currentStatus) {
    if (currentStatus != 'free') return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade500]), borderRadius: BorderRadius.circular(20)),
      child: Row(children: [const Expanded(child: Text("Modo Gratuito", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), TextButton(onPressed: () => _showPremiumModal(context), child: const Text("SUBIR", style: TextStyle(color: Colors.white)))]),
    );
  }
}