import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Uint8List? _decodeBase64Image(String source) {
  try {
    if (source.startsWith('data:image')) {
      final commaIndex = source.indexOf(',');
      if (commaIndex != -1) {
        return base64Decode(source.substring(commaIndex + 1).replaceAll(RegExp(r'\s+'), ''));
      }
    } else if (source.startsWith('base64,')) {
      return base64Decode(source.substring(7).replaceAll(RegExp(r'\s+'), ''));
    } else if (source.length > 100 &&
        !source.startsWith('/') &&
        !source.contains('\\') &&
        !source.startsWith('assets/')) {
      return base64Decode(source.replaceAll(RegExp(r'\s+'), ''));
    }
  } catch (_) {}
  return null;
}

Widget buildUserAvatarWidget(
  String avatarUrl, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  const fallbackAsset = 'assets/image/register/09_mascot_head.png';

  if (avatarUrl.isEmpty) {
    return Image.asset(
      fallbackAsset,
      width: width,
      height: height,
      fit: fit,
    );
  }

  // 1. Check if base64 encoded image
  final memoryBytes = _decodeBase64Image(avatarUrl);
  if (memoryBytes != null) {
    return Image.memory(
      memoryBytes,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  // 2. Asset image
  if (avatarUrl.startsWith('assets/')) {
    return Image.asset(
      avatarUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  // 3. Network or Blob URLs
  if (avatarUrl.startsWith('http://') ||
      avatarUrl.startsWith('https://') ||
      avatarUrl.startsWith('blob:')) {
    return Image.network(
      avatarUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      ),
    );
  }

  // 4. Local device file path
  if (!kIsWeb) {
    try {
      final file = File(avatarUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            fallbackAsset,
            width: width,
            height: height,
            fit: fit,
          ),
        );
      }
    } catch (_) {}
  }

  return Image.asset(
    fallbackAsset,
    width: width,
    height: height,
    fit: fit,
  );
}
