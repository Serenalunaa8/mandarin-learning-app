import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coin_transaction_model.dart';
import '../models/user_profile_model.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  UserProfile? _profile;
  final List<CoinTransaction> _coinTransactions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isGuest = false;

  UserProfile? get profile => _profile;
  List<CoinTransaction> get coinTransactions =>
      List.unmodifiable(_coinTransactions);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _profile != null;
  bool get isGuest => _isGuest;

  int get coins => _profile?.coins ?? 50;
  int get streak => _profile?.streak ?? 1;
  int get totalXp => _profile?.totalXp ?? 0;
  int get currentHskLevel => _profile?.currentHskLevel ?? 1;

  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final guestMode = prefs.getBool('is_guest_mode') ?? false;

      if (guestMode) {
        _isGuest = true;
        _profile = UserProfile(
          id: 'guest_local_user',
          fullName: prefs.getString('guest_name') ?? 'Pelajar Mandarin',
          avatarUrl: '',
          currentHskLevel: prefs.getInt('guest_hsk') ?? 1,
          streak: prefs.getInt('guest_streak') ?? 1,
          lastActiveDate: DateTime.now(),
          totalXp: prefs.getInt('guest_xp') ?? 120,
          coins: prefs.getInt('guest_coins') ?? 50,
        );
      } else {
        final user = SupabaseService.instance.currentUser;
        if (user != null) {
          final p = await SupabaseService.instance.getProfile(user.id);
          _profile =
              p ??
              UserProfile(
                id: user.id,
                fullName: user.userMetadata?['full_name'] ?? 'Pelajar Mandarin',
                avatarUrl: '',
                currentHskLevel: 1,
                streak: 1,
                lastActiveDate: DateTime.now(),
                totalXp: 0,
                coins: 50,
              );
        }
      }
    } catch (e) {
      debugPrint('[AuthProvider] checkSession error: $e');
    }

    if (_profile != null && !_isGuest) {
      _coinTransactions
        ..clear()
        ..addAll(await SupabaseService.instance.fetchCoinHistory(_profile!.id));
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await SupabaseService.instance.signIn(
        email: email.trim(),
        password: password,
      );

      if (res.user != null) {
        _isGuest = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);

        _profile = await SupabaseService.instance.getProfile(res.user!.id);
        _profile ??= UserProfile(
          id: res.user!.id,
          fullName: res.user!.userMetadata?['full_name'] ?? 'Pelajar Mandarin',
          avatarUrl: '',
          currentHskLevel: 1,
          streak: 1,
          lastActiveDate: DateTime.now(),
          totalXp: 0,
          coins: 50,
        );
        _coinTransactions
          ..clear()
          ..addAll(
            await SupabaseService.instance.fetchCoinHistory(_profile!.id),
          );

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Gagal masuk: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String email, String password, String fullName) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await SupabaseService.instance.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
      );

      if (res.user != null) {
        _isGuest = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', false);

        _profile = UserProfile(
          id: res.user!.id,
          fullName: fullName.trim(),
          avatarUrl: '',
          currentHskLevel: 1,
          streak: 1,
          lastActiveDate: DateTime.now(),
          totalXp: 0,
          coins: 50,
        );

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Gagal mendaftar: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> loginAsGuest() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest_mode', true);

    _profile = UserProfile(
      id: 'guest_local_user',
      fullName: 'Pelajar Mandiri',
      avatarUrl: '',
      currentHskLevel: 1,
      streak: 3,
      lastActiveDate: DateTime.now(),
      totalXp: 150,
      coins: 50,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await SupabaseService.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_guest_mode');
    _profile = null;
    _coinTransactions.clear();
    _isGuest = false;
    notifyListeners();
  }

  Future<void> addCoins(
    int amount,
    String type,
    String description, {
    String? attemptId,
  }) async {
    if (_profile == null || amount <= 0) return;

    final profile = _profile!;
    final transactionId =
        attemptId ?? '${type}_${DateTime.now().microsecondsSinceEpoch}';
    if (_coinTransactions.any(
      (transaction) => transaction.attemptId == transactionId,
    )) {
      return;
    }

    if (!_isGuest) {
      final saved = await SupabaseService.instance.addCoinTransaction(
        userId: profile.id,
        amount: amount,
        transactionType: type,
        description: description,
        attemptId: transactionId,
      );
      if (!saved) return;
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_coins', profile.coins + amount);
      await prefs.setInt('guest_xp', profile.totalXp + amount);
    }

    final newCoins = profile.coins + amount;
    final newXp = profile.totalXp + amount;
    _profile = profile.copyWith(coins: newCoins, totalXp: newXp);
    if (!_isGuest) {
      await SupabaseService.instance.updateProfile(profile.id, {
        'total_xp': newXp,
      });
    }
    _coinTransactions.insert(
      0,
      CoinTransaction(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        userId: profile.id,
        attemptId: transactionId,
        amount: amount,
        transactionType: type,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  Future<bool> deductCoins(
    int amount,
    String type,
    String description, {
    String? attemptId,
  }) async {
    if (_profile == null || _profile!.coins < amount) return false;

    final profile = _profile!;
    final transactionId =
        attemptId ?? '${type}_${DateTime.now().microsecondsSinceEpoch}';
    if (_coinTransactions.any(
      (transaction) => transaction.attemptId == transactionId,
    )) {
      return false;
    }

    if (!_isGuest) {
      final saved = await SupabaseService.instance.addCoinTransaction(
        userId: profile.id,
        amount: -amount,
        transactionType: type,
        description: description,
        attemptId: transactionId,
      );
      if (!saved) return false;
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_coins', profile.coins - amount);
    }

    _profile = profile.copyWith(coins: profile.coins - amount);
    _coinTransactions.insert(
      0,
      CoinTransaction(
        id: 'local_${DateTime.now().microsecondsSinceEpoch}',
        userId: profile.id,
        attemptId: transactionId,
        amount: -amount,
        transactionType: type,
        description: description,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  Future<void> setHskLevel(int level) async {
    if (_profile == null || level < 1 || level > 6) return;
    _profile = _profile!.copyWith(currentHskLevel: level);
    notifyListeners();

    if (!_isGuest) {
      await SupabaseService.instance.updateProfile(_profile!.id, {
        'current_hsk_level': level,
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_hsk', level);
    }
  }
}
