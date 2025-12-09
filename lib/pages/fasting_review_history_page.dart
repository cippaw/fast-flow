// lib/pages/fasting_review_history_page.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class FastingReviewHistoryPage extends StatefulWidget {
  const FastingReviewHistoryPage({Key? key}) : super(key: key);

  @override
  State<FastingReviewHistoryPage> createState() =>
      _FastingReviewHistoryPageState();
}

class _FastingReviewHistoryPageState extends State<FastingReviewHistoryPage> {
  List<dynamic> reviewList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReview();
  }

  void _loadReview() async {
    if (!Hive.isBoxOpen('reviewHistory')) {
      await Hive.openBox('reviewHistory');
    }
    final box = Hive.box('reviewHistory');
    setState(() {
      reviewList = box.get('list', defaultValue: []) as List;
      _loading = false;
    });
  }

  Future<void> _deleteReview(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Review?'),
        content: const Text('Review akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final box = Hive.box('reviewHistory');
      final updated = List<Map<String, dynamic>>.from(
        reviewList.map((e) => Map<String, dynamic>.from(e as Map)),
      );
      updated.removeAt(index);
      await box.put('list', updated);

      setState(() {
        reviewList = updated;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review berhasil dihapus')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting review: $e');
    }
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 16,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Review Puasa"),
        actions: [
          if (reviewList.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadReview,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : reviewList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Belum ada review puasa",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Review akan muncul di sini setelah Anda\nmenyimpan catatan puasa",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: reviewList.length,
                  itemBuilder: (context, index) {
                    final item = reviewList[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['tanggal'] ?? "",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.redAccent),
                                  onPressed: () => _deleteReview(index),
                                  tooltip: 'Hapus',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Rating: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                _buildRatingStars(item['rating'] ?? 0),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item['review']?.toString().isEmpty == true ||
                                        item['review'] == null
                                    ? "Tidak ada catatan"
                                    : item['review'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dibuat: ${_formatDateTime(item['created_at'])}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDateTime(dynamic dateTimeStr) {
    try {
      if (dateTimeStr == null) return '-';
      final dt = DateTime.parse(dateTimeStr.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
  }
}
