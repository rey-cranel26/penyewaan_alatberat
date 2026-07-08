import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// KONFIGURASI SUPABASE - PERHATIKAN https:// DI URL
const supabaseUrl = 'https://prgcepqtudwvxdrpgznm.supabase.co';
const supabasePublishableKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InByZ2NlcHF0dWR3dnhkcnBnem5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMyMzM2MjIsImV4cCI6MjA5ODgwOTYyMn0.wXWWFrilDUHZeHi4D8u3gdlRqOT_HyqyV7xsPh_SwGE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey, // Gunakan anonKey parameter (publishableKey juga bisa)
  );
  
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PT JAWA SENTOSA',
      theme: ThemeData(primarySwatch: Colors.orange, useMaterial3: false),
      debugShowCheckedModeBanner: false, // ← Tambahkan baris ini!
      home: const HomePage(),
    );
  }
}

// ==================== HALAMAN UTAMA ====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> equipments = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchEquipments();
  }

  Future<void> fetchEquipments() async {
    try {
      final response = await supabase.from('equipments').select();
      if (mounted) {
        setState(() {
          equipments = List<Map<String, dynamic>>.from(response);
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('PT JAWA SENTOSA'), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 60),
                      const SizedBox(height: 16),
                      Text(errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: fetchEquipments,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : equipments.isEmpty
                  ? const Center(child: Text('Belum ada alat berat tersedia'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: equipments.length,
                        itemBuilder: (context, index) {
                          final item = equipments[index];
                          return Card(
                            elevation: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Image.network(
                                    item['image_url'] ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 50),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text('${item['category'] ?? ''}', style: TextStyle(color: Colors.grey[600])),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${formatRupiah.format(item['price_per_day'] ?? 0)} / hari',
                                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => BookingPage(equipment: item),
                                            ));
                                          },
                                          child: const Text('Sewa Sekarang'),
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ==================== HALAMAN BOOKING & PEMBAYARAN ====================
class BookingPage extends StatefulWidget {
  final Map<String, dynamic> equipment;
  const BookingPage({super.key, required this.equipment});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  int _days = 1;
  String _paymentMethod = 'qris';
  bool _isProcessing = false;
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final pricePerDay = widget.equipment['price_per_day'] as int? ?? 0;
    final totalPrice = pricePerDay * _days;
    final formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.equipment['name'] ?? '', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email / No HP Anda', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Durasi Sewa (Hari): '),
                      const SizedBox(width: 16),
                      IconButton(onPressed: _days > 1 ? () => setState(() => _days--) : null, icon: const Icon(Icons.remove_circle)),
                      Text('$_days', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => setState(() => _days++), icon: const Icon(Icons.add_circle)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Harga:', style: TextStyle(fontSize: 18)),
                      Text(formatRupiah.format(totalPrice), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Pilih Metode Pembayaran:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('QRIS'),
                          selected: _paymentMethod == 'qris',
                          onSelected: (selected) => setState(() => _paymentMethod = 'qris'),
                          selectedColor: Colors.orange.shade100,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Transfer Bank (VA)'),
                          selected: _paymentMethod == 'transfer',
                          onSelected: (selected) => setState(() => _paymentMethod = 'transfer'),
                          selectedColor: Colors.orange.shade100,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : () => _processPayment(totalPrice),
                      child: _isProcessing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('BAYAR SEKARANG', style: TextStyle(fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayment(int totalPrice) async {
    if (_emailController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mohon isi Email/No HP')));
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      // Simpan ke Supabase dengan try-catch (versi terbaru)
      await supabase.from('transactions').insert({
        'user_email': _emailController.text,
        'equipment_id': widget.equipment['id'],
        'rental_days': _days,
        'total_price': totalPrice,
        'payment_method': _paymentMethod,
        'status': 'menunggu_pembayaran'
      });

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => PaymentDetailPage(
          paymentMethod: _paymentMethod,
          totalPrice: totalPrice,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// ==================== HALAMAN DETAIL PEMBAYARAN ====================
class PaymentDetailPage extends StatelessWidget {
  final String paymentMethod;
  final int totalPrice;

  const PaymentDetailPage({super.key, required this.paymentMethod, required this.totalPrice});

  @override
  Widget build(BuildContext context) {
    final formatRupiah = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pembayaran')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 60),
                  const SizedBox(height: 16),
                  const Text('Pesanan Berhasil Dibuat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Total: ${formatRupiah.format(totalPrice)}', style: const TextStyle(fontSize: 18, color: Colors.orange)),
                  const SizedBox(height: 24),
                  if (paymentMethod == 'qris') ...[
                    const Text('Silakan Scan QRIS di bawah ini:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      width: 200, height: 200,
                      color: Colors.grey[200],
                      child: const Center(child: Text('[ QRIS IMAGE ]')),
                    ),
                  ] else ...[
                    const Text('Silakan Transfer ke rekening berikut:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Bank BCA', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('1234567890 (PT JAWA SENTOSA)'),
                    const Text('A.n: PT JAWA SENTOSA'),
                  ],
                  const SizedBox(height: 24),
                  const Text('Status: Menunggu Pembayaran', style: TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomePage()), (route) => false),
                    child: const Text('Kembali ke Beranda'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
