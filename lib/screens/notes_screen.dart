import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../db/db_helper.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> _notes = [];

  static const List<Color> noteColors = [
    AppTheme.limeAccent,
    AppTheme.lavender,
    AppTheme.peach,
    AppTheme.coral,
    Color(0xFF7BCDFF),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = await DBHelper.instance.getAllNotes();
    setState(() => _notes = n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notes',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _editNote(null),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _notes.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 60),
                        Icon(Icons.edit_note_rounded, color: AppTheme.textMuted, size: 50),
                        SizedBox(height: 12),
                        Center(child: Text('No notes yet', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
                        SizedBox(height: 4),
                        Center(child: Text('Tap "New" to add a note', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
                      ],
                    )
                  : RefreshIndicator(
                      color: AppTheme.limeAccent,
                      backgroundColor: AppTheme.surface,
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: _notes.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.85,
                        ),
                        itemBuilder: (ctx, i) {
                          final note = _notes[i];
                          final color = noteColors[i % noteColors.length];
                          return _NoteCard(
                            note: note,
                            color: color,
                            onTap: () => _editNote(note),
                            onDelete: () async {
                              await DBHelper.instance.deleteNote(note['id'] as int);
                              _load();
                            },
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(Map<String, dynamic>? existing) async {
    final title = TextEditingController(text: existing?['title'] as String? ?? '');
    final content = TextEditingController(text: existing?['content'] as String? ?? '');

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 18),
              Text(existing == null ? 'New Note' : 'Edit Note',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: title,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(hintText: 'Title (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                style: const TextStyle(color: AppTheme.textPrimary),
                maxLines: 6,
                minLines: 4,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Write your note...'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final c = content.text.trim();
                    if (c.isEmpty) return;
                    final data = {
                      'date': existing?['date'] as String? ?? DateTime.now().toIso8601String(),
                      'title': title.text.trim(),
                      'content': c,
                    };
                    if (existing == null) {
                      await DBHelper.instance.insertNote(data);
                    } else {
                      await DBHelper.instance.updateNote(existing['id'] as int, {
                        ...data,
                        'date': DateTime.now().toIso8601String(),
                      });
                    }
                    if (mounted) Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.color, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(note['date'] as String);
    final title = note['title'] as String?;
    final content = note['content'] as String;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null && title.isNotEmpty) ...[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: Text(
                content,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    date != null ? DateFormat('MMM d').format(date) : '',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
