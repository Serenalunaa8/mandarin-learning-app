import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hash-chain lokal untuk integritas riwayat kemajuan belajar.
/// Ini bukan blockchain publik dan tidak menyimpan transaksi koin.
class ProgressBlockchainService {
  ProgressBlockchainService._();

  static final instance = ProgressBlockchainService._();
  static const _storagePrefix = 'progress_blockchain_v1_';
  static const genesisHash = 'GENESIS_LEARNING_PROGRESS_V1';

  Future<void> appendProgress({
    required String userId,
    required int vocabId,
    required int hskLevel,
    required bool learned,
    required bool quizMastered,
    required bool favorite,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storagePrefix$userId';
    final chain = prefs.getStringList(key) ?? <String>[];
    final previousHash = chain.isEmpty
        ? genesisHash
        : (jsonDecode(chain.last) as Map<String, dynamic>)['block_hash']
            as String;
    final index = chain.length;
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final data = jsonEncode({
      'favorite': favorite,
      'hsk_level': hskLevel,
      'learned': learned,
      'previous_hash': previousHash,
      'quiz_mastered': quizMastered,
      'timestamp': timestamp,
      'user_id': userId,
      'vocab_id': vocabId,
    });
    final dataHash = sha256.convert(utf8.encode(data)).toString();
    final blockHash = sha256
        .convert(utf8.encode('$index|$timestamp|$dataHash|$previousHash'))
        .toString();

    chain.add(jsonEncode({
      'index': index,
      'vocab_id': vocabId,
      'hsk_level': hskLevel,
      'learned': learned,
      'quiz_mastered': quizMastered,
      'favorite': favorite,
      'timestamp': timestamp,
      'data_hash': dataHash,
      'previous_hash': previousHash,
      'block_hash': blockHash,
    }));
    await prefs.setStringList(key, chain);
  }

  Future<bool> verify(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final chain = prefs.getStringList('$_storagePrefix$userId') ?? <String>[];
    var previousHash = genesisHash;
    for (var index = 0; index < chain.length; index++) {
      final block = jsonDecode(chain[index]) as Map<String, dynamic>;
      if (block['index'] != index || block['previous_hash'] != previousHash) {
        return false;
      }
      previousHash = block['block_hash'] as String;
    }
    return true;
  }
}
