import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../utils/theme.dart';
import '../utils/auth_helper.dart';
import '../db/db_helper.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await AuthHelper.getUsername();
    setState(() => _username = u);
  }

  Future<void> _exportData() async {
    try {
      final data = await DBHelper.instance.exportAllData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/fitness_backup_$timestamp.json');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], subject: 'Fitness Tracker Backup');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup ready - save it to Drive or Files'), backgroundColor: AppTheme.surfaceLight),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _importData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Replace all data?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Importing will replace all current data with the backup. This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import', style: TextStyle(color: AppTheme.limeAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.first.path!);
      final text = await file.readAsString();
      final data = jsonDecode(text) as Map<String, dynamic>;
      await DBHelper.instance.importAllData(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data imported successfully'), backgroundColor: AppTheme.surfaceLight),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _changeCredentials() async {
    final currentPass = TextEditingController();
    final newUser = TextEditingController(text: _username);
    final newPass = TextEditingController();
    String? error;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                const Text('Change Credentials', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPass,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newUser,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'New username', prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPass,
                  obscureText: true,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (newUser.text.trim().isEmpty || newPass.text.isEmpty) {
                        setSheet(() => error = 'Username and password required');
                        return;
                      }
                      final ok = await AuthHelper.changeCredentials(currentPass.text, newUser.text.trim(), newPass.text);
                      if (!ok) {
                        setSheet(() => error = 'Current password is incorrect');
                        return;
                      }
                      if (mounted) Navigator.pop(ctx);
                      _load();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Credentials updated'), backgroundColor: AppTheme.surfaceLight),
                      );
                    },
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthHelper.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Account
            _SectionHeader(title: 'Account'),
            _SettingTile(
              icon: Icons.person_outline,
              iconColor: AppTheme.lavender,
              title: 'Username',
              subtitle: _username,
            ),
            _SettingTile(
              icon: Icons.lock_outline,
              iconColor: AppTheme.lavender,
              title: 'Change credentials',
              onTap: _changeCredentials,
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: 'Backup'),
            _SettingTile(
              icon: Icons.upload_rounded,
              iconColor: AppTheme.limeAccent,
              title: 'Export all data',
              subtitle: 'Save backup to Drive, email, Files',
              onTap: _exportData,
            ),
            _SettingTile(
              icon: Icons.download_rounded,
              iconColor: AppTheme.peach,
              title: 'Import data',
              subtitle: 'Restore from a backup file',
              onTap: _importData,
            ),
            const SizedBox(height: 20),
            _SectionHeader(title: 'Other'),
            _SettingTile(
              icon: Icons.logout_rounded,
              iconColor: AppTheme.coral,
              title: 'Sign out',
              onTap: _logout,
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text(
                'Fitness Tracker v1.0\nBuilt for personal use',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingTile({required this.icon, required this.iconColor, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.cardDark, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.18), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
