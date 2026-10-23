import 'package:flutter/material.dart';
import '../providers/auth_provider.dart';

void showAvatarPickerModal(BuildContext context, AuthProvider auth) {
  final currentAvatar = (auth.profile?.avatarUrl != null && auth.profile!.avatarUrl.isNotEmpty)
      ? auth.profile!.avatarUrl
      : 'assets/image/register/09_mascot_head.png';

  final List<Map<String, String>> mascotAvatars = [
    {
      'name': 'Panda Tunas',
      'asset': 'assets/image/register/09_mascot_head.png',
    },
    {
      'name': 'Senyum Ceria',
      'asset': 'assets/image/beranda/wajah_01_senyum.png',
    },
    {
      'name': 'Kedipan Ramah',
      'asset': 'assets/image/beranda/wajah_02_kedip.png',
    },
    {
      'name': 'Tertawa Riang',
      'asset': 'assets/image/beranda/wajah_03_tertawa.png',
    },
    {
      'name': 'Penuh Kasih',
      'asset': 'assets/image/beranda/wajah_04_cinta.png',
    },
    {
      'name': 'Terkejut Lucu',
      'asset': 'assets/image/beranda/wajah_05_kaget.png',
    },
    {
      'name': 'Santai Rileks',
      'asset': 'assets/image/beranda/wajah_06_tidur.png',
    },
    {
      'name': 'Terharu Bangga',
      'asset': 'assets/image/beranda/wajah_07_menangis.png',
    },
    {
      'name': 'Fokus Kuat',
      'asset': 'assets/image/beranda/wajah_08_marah.png',
    },
    {
      'name': 'Bintang Juara',
      'asset': 'assets/image/beranda/maskot_01_bintang.png',
    },
    {
      'name': 'Rajin Belajar',
      'asset': 'assets/image/beranda/maskot_02_baca_buku.png',
    },
    {
      'name': 'Penuh Semangat',
      'asset': 'assets/image/beranda/maskot_03_semangat.png',
    },
    {
      'name': 'Detektif Hanzi',
      'asset': 'assets/image/beranda/maskot_04_lup.png',
    },
    {
      'name': 'Panda Pemalu',
      'asset': 'assets/image/beranda/maskot_05_malu.png',
    },
    {
      'name': 'Petualang Cilik',
      'asset': 'assets/image/landing_page/01_maskot.png',
    },
    {
      'name': 'Sahabat Belajar',
      'asset': 'assets/image/landing_page/08_anak_anak.png',
    },
  ];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      String selectedAvatar = currentAvatar;
      final urlController = TextEditingController();
      bool isCustomUrlMode = !selectedAvatar.startsWith('assets/');
      if (isCustomUrlMode) {
        urlController.text = selectedAvatar;
      }

      return StatefulBuilder(
        builder: (context, setModalState) {
          Widget buildAvatarPreview() {
            if (selectedAvatar.startsWith('http://') || selectedAvatar.startsWith('https://')) {
              return Image.network(
                selectedAvatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40, color: Color(0xFF16A34A)),
              );
            }
            return Image.asset(
              selectedAvatar,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40, color: Color(0xFF16A34A)),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Current Preview
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDCFCE7),
                        border: Border.all(color: const Color(0xFF16A34A), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(child: buildAvatarPreview()),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ganti Foto / Avatar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A24),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Pilih avatar karakter maskot atau masukkan URL foto',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Switcher: Maskot vs Foto URL
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isCustomUrlMode = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isCustomUrlMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !isCustomUrlMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Karakter Maskot',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: !isCustomUrlMode ? FontWeight.bold : FontWeight.w500,
                                  color: !isCustomUrlMode ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              isCustomUrlMode = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isCustomUrlMode ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isCustomUrlMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Tautan Foto Web',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCustomUrlMode ? FontWeight.bold : FontWeight.w500,
                                  color: isCustomUrlMode ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Content Area
                Expanded(
                  child: !isCustomUrlMode
                      ? GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.88,
                          ),
                          itemCount: mascotAvatars.length,
                          itemBuilder: (ctx, index) {
                            final item = mascotAvatars[index];
                            final assetPath = item['asset']!;
                            final isSelected = selectedAvatar == assetPath;

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  selectedAvatar = assetPath;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Stack(
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: Image.asset(
                                              assetPath,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item['name']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? const Color(0xFF1E3A24) : const Color(0xFF64748B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF16A34A),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              const Text(
                                'Alamat URL Foto:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E3A24),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: urlController,
                                decoration: InputDecoration(
                                  hintText: 'https://example.com/avatar.png',
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: Color(0xFF16A34A), width: 1.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDCFCE7),
                                  foregroundColor: const Color(0xFF16A34A),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                label: const Text('Pratinjau Foto', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  final input = urlController.text.trim();
                                  if (input.isNotEmpty) {
                                    setModalState(() {
                                      selectedAvatar = input;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Contoh Preset Foto Pelajar:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF1E3A24),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200',
                                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200',
                                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
                                  'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
                                ].map((url) {
                                  final isSelected = selectedAvatar == url;
                                  return GestureDetector(
                                    onTap: () {
                                      urlController.text = url;
                                      setModalState(() {
                                        selectedAvatar = url;
                                      });
                                    },
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await auth.updateAvatar(selectedAvatar);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto profil berhasil diperbarui! 🎉'),
                            backgroundColor: Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Gunakan Avatar Ini',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
