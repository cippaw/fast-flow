// lib/pages/fasting_review.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FastingReviewPage extends StatefulWidget {
  final DateTime date;
  const FastingReviewPage({super.key, required this.date});

  @override
  State<FastingReviewPage> createState() => _FastingReviewPageState();
}

class _FastingReviewPageState extends State<FastingReviewPage> {
  final _controller = TextEditingController();
  int _rating = 4;
  late Box _notesBox;
  bool _loading = true;

  String get _key => DateFormat('yyyy-MM-dd').format(widget.date);

  @override
  void initState() {
    super.initState();
    _notesBox = Hive.box('fastingNotes');
    _loadExisting();
  }

  void _loadExisting() {
    final saved = _notesBox.get(_key);
    if (saved != null && saved is Map) {
      _controller.text = saved['note'] as String? ?? '';
      _rating = (saved['rating'] as int?) ?? 4;
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final note = _controller.text.trim();
    final payload = {
      'rating': _rating,
      'note': note,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _notesBox.put(_key, payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Review disimpan.')));
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    await _notesBox.delete(_key);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Review dihapus.')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(widget.date);
    return Scaffold(
      appBar: AppBar(title: Text('Catat Puasa • $title')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(children: [
                  const Text('Rating:'),
                  const SizedBox(width: 12),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(i <= _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber),
                    )
                ]),
                const SizedBox(height: 6),
                TextField(
                  controller: _controller,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    hintText: 'Tulis review puasa (singkat & jujur)...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Review'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_notesBox.containsKey(_key))
                    OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      label: const Text('Hapus',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                ])
              ]),
            ),
    );
  }
}
