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
    setState(() => reviewList = box.get('list', defaultValue: []) as List);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Riwayat Review Puasa")),
      body: reviewList.isEmpty
          ? const Center(child: Text("Belum ada review puasa"))
          : ListView.builder(
              itemCount: reviewList.length,
              itemBuilder: (context, index) {
                final item = reviewList[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['tanggal'] ?? "",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text("Review: ${item['review'] ?? '-'}"),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
