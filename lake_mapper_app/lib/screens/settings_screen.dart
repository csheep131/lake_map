import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = SyncService.instance.databaseName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Namen eingeben')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SyncService.instance.setDatabaseName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einstellungen gespeichert'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme-Umschalter
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHighlight),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      themeMode == AppThemeMode.dark ? Icons.dark_mode : Icons.wb_sunny,
                      color: themeMode == AppThemeMode.dark ? AppColors.cyan : AppColors.amber,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            themeMode == AppThemeMode.dark ? 'Dark Mode' : 'Familien-Modus',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            themeMode == AppThemeMode.dark 
                                ? 'Dunkle Optik für Nacht' 
                                : 'Helle Optik + OSM Karten',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: themeMode == AppThemeMode.family,
                      onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                      activeTrackColor: AppColors.cyan,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Club-Login Bereich
              Text(
                'CLUB-MITGLIEDER',
                style: TextStyle(fontFamily: 'RobotoMono', 
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHighlight),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      authService.isLoggedIn ? Icons.check_circle : Icons.login,
                      color: authService.isLoggedIn ? AppColors.success : AppColors.textMuted,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authService.isLoggedIn 
                                ? 'Angemeldet als ${authService.clubId}' 
                                : 'Nicht angemeldet',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            authService.isLoggedIn
                                ? 'Sync aktiviert'
                                : 'Anmelden für Sync',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (authService.isLoggedIn) {
                          await authService.logout();
                          setState(() {});
                        } else {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                          if (result == true) {
                            setState(() {});
                          }
                        }
                      },
                      child: Text(
                        authService.isLoggedIn ? 'ABMELDEN' : 'ANMELDEN',
                        style: TextStyle(
                          color: authService.isLoggedIn
                              ? AppColors.error
                              : AppColors.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SYNC-KONFIGURATION',
                style: TextStyle(fontFamily: 'RobotoMono', 
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceHighlight),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameController,
                      style: TextStyle(fontFamily: 'RobotoMono', 
                        fontSize: 16,
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Datenbankname',
                        hintText: 'z. B. wammsee, rhein, ...',
                        prefixIcon: const Icon(Icons.storage, color: AppColors.cyan),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () => _nameController.clear(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.deep,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Daten werden mit arxlabs.dev/lakedb/${_nameController.text.isEmpty ? '{name}' : _nameController.text} synchronisiert.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _save,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.abyss),
                              )
                            : const Text('SPEICHERN'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
