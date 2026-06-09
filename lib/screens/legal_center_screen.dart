import 'package:flutter/material.dart';
import '../services/app_animations.dart';
import '../services/app_ui_tokens.dart';

class LegalCenterScreen extends StatelessWidget {
  const LegalCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Legal & Privacy'),
          bottom: TabBar(
            indicator: BoxDecoration(
              color: AppUiTokens.brandBlue,
              borderRadius: BorderRadius.circular(999),
            ),
            indicatorPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            labelColor: AppUiTokens.white,
            unselectedLabelColor: AppUiTokens.textMuted,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Privacy'),
              Tab(text: 'Terms'),
              Tab(text: 'Data Safety'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _LegalText(
              title: 'Privacy Policy',
              body:
                  'CatatUang menyimpan data transaksi di perangkat Anda. Backup terenkripsi dibuat lokal. Kami tidak menjual data pengguna.\n\nData yang disimpan: transaksi, tagihan rutin, preferensi aplikasi, status keamanan.\n\nAnda dapat menghapus data dengan restore kosong/clear data aplikasi.',
            ),
            _LegalText(
              title: 'Terms of Service',
              body:
                  'Aplikasi ini ditujukan untuk pencatatan keuangan pribadi harian. Pengguna bertanggung jawab atas akurasi input data. Fitur analitik bersifat informatif dan bukan nasihat keuangan profesional.',
            ),
            _LegalText(
              title: 'Data Safety Summary',
              body:
                  'Data lokal: transaksi, tagihan, pengaturan, backup terenkripsi.\nData cloud: opsional jika backend diaktifkan.\nRetention: mengikuti data lokal perangkat sampai dihapus pengguna.',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalText extends StatelessWidget {
  const _LegalText({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AnimatedFadeSlide(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppUiTokens.borderSoft),
            boxShadow: [
              BoxShadow(
                color: AppUiTokens.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppUiTokens.surfaceBlueSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppUiTokens.brandBlueBorder),
            ),
            child: const Text(
              'CatatUang Policy',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppUiTokens.brandBlueDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.55, color: AppUiTokens.textPrimary),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
