import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/auth_provider.dart';
import 'avatar_image_helper.dart';

void showAvatarPickerModal(BuildContext context, AuthProvider auth) {
  final currentAvatar =
      (auth.profile?.avatarUrl != null && auth.profile!.avatarUrl.isNotEmpty)
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
    {'name': 'Penuh Kasih', 'asset': 'assets/image/beranda/wajah_04_cinta.png'},
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
    {'name': 'Fokus Kuat', 'asset': 'assets/image/beranda/wajah_08_marah.png'},
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
  ];

  final imagePicker = ImagePicker();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      String selectedAvatar = currentAvatar;
      bool isDevicePhotoMode = !selectedAvatar.startsWith('assets/');

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> pickFromDevice(ImageSource source) async {
            try {
              final picked = await imagePicker.pickImage(
                source: source,
                maxWidth: 512,
                maxHeight: 512,
                imageQuality: 80,
              );
              if (picked != null) {
                final bytes = await picked.readAsBytes();
                final base64String =
                    'data:image/jpeg;base64,${base64Encode(bytes)}';
                setModalState(() {
                  selectedAvatar = base64String;
                  isDevicePhotoMode = true;
                });
              }
            } catch (e) {
              if (modalContext.mounted) {
                ScaffoldMessenger.of(modalContext).showSnackBar(
                  SnackBar(
                    content: Text('Gagal membuka atau memilih foto: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }

          Future<void> openCamera() async {
            if (!kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.android ||
                    defaultTargetPlatform == TargetPlatform.iOS)) {
              try {
                final permission = await Permission.camera.request();
                if (!permission.isGranted) {
                  if (!modalContext.mounted) return;

                  if (permission.isPermanentlyDenied ||
                      permission.isRestricted) {
                    await showDialog<void>(
                      context: modalContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Izin Kamera Diperlukan'),
                        content: const Text(
                          'Izinkan akses kamera di pengaturan perangkat agar bisa mengambil foto profil.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Nanti'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await openAppSettings();
                            },
                            child: const Text('Buka Pengaturan'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(modalContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Izin kamera diperlukan untuk mengambil foto profil.',
                        ),
                      ),
                    );
                  }
                  return;
                }
              } catch (e) {
                if (modalContext.mounted) {
                  ScaffoldMessenger.of(modalContext).showSnackBar(
                    SnackBar(
                      content: Text('Gagal meminta izin kamera: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }
            }

            await pickFromDevice(ImageSource.camera);
          }

          return Container(
            height: MediaQuery.of(modalContext).size.height * 0.82,
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
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDCFCE7),
                        border: Border.all(
                          color: const Color(0xFF16A34A),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: ClipOval(
                        child: buildUserAvatarWidget(
                          selectedAvatar,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
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
                            'Pilih avatar maskot atau gunakan foto dari perangkat',
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

                // Switcher: Maskot vs Foto dari Perangkat
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
                              isDevicePhotoMode = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !isDevicePhotoMode
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: !isDevicePhotoMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
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
                                  fontWeight: !isDevicePhotoMode
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: !isDevicePhotoMode
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
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
                              isDevicePhotoMode = true;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isDevicePhotoMode
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: isDevicePhotoMode
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'Foto Perangkat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isDevicePhotoMode
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isDevicePhotoMode
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
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
                  child: !isDevicePhotoMode
                      ? GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.88,
                              ),
                          itemCount: mascotAvatars.length,
                          itemBuilder: (gridCtx, index) {
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
                                  color: isSelected
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2.5 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF16A34A)
                                                .withValues(alpha: 0.15),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? const Color(0xFF1E3A24)
                                                : const Color(0xFF64748B),
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
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 12),
                              // Big Live Preview Circle
                              Center(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFDCFCE7),
                                    border: Border.all(
                                      color: const Color(0xFF16A34A),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF16A34A)
                                            .withValues(alpha: 0.18),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: ClipOval(
                                    child: buildUserAvatarWidget(
                                      selectedAvatar,
                                      width: 110,
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                !selectedAvatar.startsWith('assets/')
                                    ? 'Foto dari perangkat siap digunakan'
                                    : 'Pilih foto profil dari galeri atau kamera perangkatmu',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      !selectedAvatar.startsWith('assets/')
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: !selectedAvatar.startsWith('assets/')
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Pick from Gallery Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFDCFCE7),
                                    foregroundColor: const Color(0xFF16A34A),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                        color: Color(0xFF86EFAC),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.photo_library_rounded,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Pilih Foto dari Galeri / File',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () =>
                                      pickFromDevice(ImageSource.gallery),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Take Photo with Camera Button (disesuaikan untuk mobile/desktop)
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1E3A24),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 22,
                                  ),
                                  label: const Text(
                                    'Buka Kamera',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: openCamera,
                                ),
                              ),

                              if (!selectedAvatar.startsWith('assets/')) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () {
                                    setModalState(() {
                                      selectedAvatar = 'assets/image/register/09_mascot_head.png';
                                      isDevicePhotoMode = false;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.restore_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  label: const Text(
                                    'Kembalikan ke Avatar Maskot Bawaan',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
                      final chosenAvatar = selectedAvatar;
                      Navigator.pop(sheetContext);
                      await auth.updateAvatar(chosenAvatar);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Foto profil berhasil diperbarui! 🎉',
                            ),
                            backgroundColor: Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Gunakan Foto / Avatar Ini',
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
