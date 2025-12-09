import 'package:fast_flow/services/auth_service.dart';
import 'package:fast_flow/services/currency_service.dart';
import 'package:fast_flow/utils/notification.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class InfaqPage extends StatefulWidget {
  const InfaqPage({super.key});

  @override
  State<InfaqPage> createState() => _InfaqPageState();
}

class _InfaqPageState extends State<InfaqPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late Box infaqBox;
  String _currency = 'IDR';
  double? _convertedToIdr;

  String? get _currentUserEmail => AuthService().currentEmail;

  @override
  void initState() {
    super.initState();
    infaqBox = Hive.box('infaqBox');
  }

  // ================= KONVERSI =================
  Future<void> _convertAmount() async {
    final text = _amountController.text.trim();
    final val = double.tryParse(text) ?? 0.0;
    if (val <= 0) {
      setState(() => _convertedToIdr = null);
      return;
    }
    if (_currency.toUpperCase() == 'IDR') {
      setState(() => _convertedToIdr = val);
      return;
    }
    final res = await CurrencyService.convertCurrency(
        _currency.toUpperCase(), 'IDR', val);
    setState(() => _convertedToIdr = res);
  }

  // ================= KIRIM INFAQ =================
  Future<void> _submitInfaq() async {
    if (_currentUserEmail == null) return;

    if (_formKey.currentState!.validate()) {
      final rawAmount = double.tryParse(_amountController.text) ?? 0.0;
      final amount = _convertedToIdr ?? rawAmount;
      final notes = _notesController.text.trim();

      _showPaymentSheet(amount, rawAmount, notes);
    }
  }

  // ================= BOTTOM SHEET =================
  void _showPaymentSheet(
    double amount,
    double rawAmount,
    String notes,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF8F3E7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Pilih Metode Pembayaran',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F3B2E)),
                ),
              ),
              const SizedBox(height: 20),
              _methodButton(Icons.qr_code, "QRIS", () {
                _processPayment(amount, rawAmount, notes, 'QRIS');
              }),
              _methodButton(Icons.account_balance, "Transfer Bank", () {
                _processPayment(amount, rawAmount, notes, 'Bank');
              }),
              _methodButton(Icons.wallet, "E-Wallet", () {
                _processPayment(amount, rawAmount, notes, 'E-Wallet');
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _methodButton(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0F3B2E)),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF0F3B2E))),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // ================= SIMPAN =================
  // PERBAIKAN: Menambahkan prefix email untuk isolasi data per user
  Future<void> _processPayment(
    double amount,
    double rawAmount,
    String notes,
    String method,
  ) async {
    final date = DateTime.now();
    final userKey = '${_currentUserEmail}_infaq_list';

    // Ambil list existing untuk user ini
    final existing = infaqBox.get(userKey, defaultValue: []) as List;
    final updated = List<Map<String, dynamic>>.from(
      existing.map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // Tambahkan entry baru
    updated.add({
      'user_email': _currentUserEmail,
      'amount': amount,
      'original_amount': rawAmount,
      'original_currency': _currency,
      'notes': notes,
      'date': date.toIso8601String(),
      'method': method,
    });

    await infaqBox.put(userKey, updated);

    await NotificationService().showNotification(
      title: "Infaq Berhasil 🤲",
      body:
          "Terima kasih, infaq ${_formatCurrency(rawAmount, _currency)} via $method berhasil.",
    );

    if (mounted) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F3B2E),
          content: Text(
            'Pembayaran via $method berhasil!',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    _amountController.clear();
    _notesController.clear();
    setState(() {});
  }

  // PERBAIKAN: Format mata uang sesuai dengan currency asli
  String _formatCurrency(double amount, String currency) {
    if (currency == 'IDR') {
      return 'Rp${amount.toStringAsFixed(0)}';
    } else if (currency == 'USD') {
      return '\$${amount.toStringAsFixed(2)}';
    } else if (currency == 'EUR') {
      return '€${amount.toStringAsFixed(2)}';
    } else if (currency == 'SGD') {
      return 'S\$${amount.toStringAsFixed(2)}';
    }
    return '${amount.toStringAsFixed(2)} $currency';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    // PERBAIKAN: Ambil data infaq sesuai user yang login
    final userKey = '${_currentUserEmail}_infaq_list';
    final infaqList = infaqBox.get(userKey, defaultValue: []) as List;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F3E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3B2E),
        elevation: 0,
        title: const Text(
          'Infaq',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ayo Berinfaq Hari Ini!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3B2E),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '"Sedekah tidak akan mengurangi harta." (HR. Muslim)',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 30),

            // ================= FORM =================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      color: Colors.black.withOpacity(0.07)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Nominal',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF0F3B2E)),
                              prefixIcon: const Icon(Icons.volunteer_activism,
                                  color: Color(0xFF0F3B2E)),
                              filled: true,
                              fillColor: const Color(0xFFF8F3E7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (_) => _convertAmount(),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Masukkan nominal infaq';
                              }
                              if (double.tryParse(val) == null) {
                                return 'Nominal tidak valid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                  value: 'IDR', child: Text('IDR')),
                              DropdownMenuItem(
                                  value: 'USD', child: Text('USD')),
                              DropdownMenuItem(
                                  value: 'EUR', child: Text('EUR')),
                              DropdownMenuItem(
                                  value: 'SGD', child: Text('SGD')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _currency = v);
                              _convertAmount();
                            },
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFFF8F3E7),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_convertedToIdr != null && _currency != 'IDR')
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Preview konversi: Rp${_convertedToIdr!.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF0F3B2E),
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Catatan (opsional)',
                        labelStyle: const TextStyle(color: Color(0xFF0F3B2E)),
                        prefixIcon: const Icon(Icons.note_alt_outlined,
                            color: Color(0xFF0F3B2E)),
                        filled: true,
                        fillColor: const Color(0xFFF8F3E7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3B2E),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _submitInfaq,
                      child: const Text(
                        'Kirim Infaq',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Riwayat Infaq',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F3B2E),
              ),
            ),
            const SizedBox(height: 14),

            // ================= RIWAYAT =================
            if (infaqList.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Belum ada riwayat infaq.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                itemCount: infaqList.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final data =
                      Map<String, dynamic>.from(infaqList[index] as Map);
                  final date = DateTime.parse(data['date']);

                  // PERBAIKAN: Tampilkan dalam mata uang asli, bukan selalu IDR
                  final originalAmount =
                      (data['original_amount'] as num?)?.toDouble() ?? 0.0;
                  final originalCurrency =
                      data['original_currency'] as String? ?? 'IDR';
                  final displayAmount =
                      _formatCurrency(originalAmount, originalCurrency);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            const Color(0xFFD4A857).withOpacity(0.25),
                        child: const Icon(Icons.volunteer_activism_rounded,
                            color: Color(0xFF0F3B2E)),
                      ),
                      title: Text(
                        displayAmount,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F3B2E)),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('d MMM yyyy, HH:mm').format(date),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          Text(
                            'Metode: ${data['method']}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          // Tampilkan konversi jika bukan IDR
                          if (originalCurrency != 'IDR' &&
                              data['amount'] != null)
                            Text(
                              '≈ Rp${(data['amount'] as num).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (data['notes']?.toString().isNotEmpty == true)
                            Expanded(
                              child: Text(
                                data['notes'],
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF0F3B2E),
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            )
                          else
                            const Text(
                              'Tanpa catatan',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey,
                                  fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
