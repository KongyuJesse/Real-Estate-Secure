import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../data/consumer_api.dart';
import '../../data/consumer_catalog_cache_store.dart';
import '../../data/consumer_kyc_capture_service.dart';
import '../../data/consumer_security_preferences_store.dart';
import '../../data/consumer_session_store.dart';
import '../../data/consumer_workspace_cache_store.dart';
import '../../data/device_permission_service.dart';
import '../../data/device_biometric_service.dart';
import 'consumer_models.dart';
import 'pages/workspace/cameroon_location_catalog.dart';

String _resolveDefaultConsumerApiBaseUrl([String? runtimeOverride]) {
  final normalizedRuntimeOverride = runtimeOverride?.trim() ?? '';
  if (normalizedRuntimeOverride.isNotEmpty) {
    return normalizedRuntimeOverride;
  }

  const configuredBaseUrl = String.fromEnvironment('RES_API_BASE_URL');
  if (configuredBaseUrl.trim().isNotEmpty) {
    return configuredBaseUrl.trim();
  }

  if (kReleaseMode) {
    return 'https://api.realestatesecure.cm/v1';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8080/v1',
    _ => 'http://127.0.0.1:8080/v1',
  };
}

class ConsumerController extends ChangeNotifier {
  ConsumerController({
    required ConsumerApiClient apiClient,
    required ConsumerSessionStore sessionStore,
    ConsumerBiometricService? biometricService,
    ConsumerDevicePermissionService? devicePermissionService,
    ConsumerSecurityPreferencesStore? securityPreferencesStore,
    ConsumerCatalogCacheStore? catalogCacheStore,
    ConsumerWorkspaceCacheStore? workspaceCacheStore,
    ConsumerKycCaptureService? kycCaptureService,
    String? defaultBaseUrlOverride,
    this.splashDuration = const Duration(milliseconds: 1800),
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _biometricService =
           biometricService ?? const PlatformConsumerBiometricService(),
       _devicePermissionService =
           devicePermissionService ??
           const PlatformConsumerDevicePermissionService(),
       _securityPreferencesStore =
           securityPreferencesStore ??
           const SecureConsumerSecurityPreferencesStore(),
       _catalogCacheStore =
           catalogCacheStore ?? LocalDatabaseConsumerCatalogCacheStore(),
       _workspaceCacheStore =
           workspaceCacheStore ?? LocalDatabaseConsumerWorkspaceCacheStore(),
       _kycCaptureService =
           kycCaptureService ?? const SumsubConsumerKycCaptureService(),
       _defaultBaseUrl = _resolveDefaultConsumerApiBaseUrl(
         defaultBaseUrlOverride,
       ) {
    _apiClient.onSessionUpdated = _handleSessionRefresh;
  }

  final ConsumerApiClient _apiClient;
  final ConsumerSessionStore _sessionStore;
  final ConsumerBiometricService _biometricService;
  final ConsumerDevicePermissionService _devicePermissionService;
  final ConsumerSecurityPreferencesStore _securityPreferencesStore;
  final ConsumerCatalogCacheStore _catalogCacheStore;
  final ConsumerWorkspaceCacheStore _workspaceCacheStore;
  final ConsumerKycCaptureService _kycCaptureService;
  final Duration splashDuration;
  final String _defaultBaseUrl;
  static const int _catalogPageSize = 12;
  static const Duration _catalogReconnectInterval = Duration(seconds: 10);

  ConsumerStage stage = ConsumerStage.splash;
  ConsumerTab currentTab = ConsumerTab.home;

  late ConsumerSession _session = ConsumerSession(baseUrl: _defaultBaseUrl);
  ConsumerUserProfile? profile;
  List<ConsumerTask> tasks = const [];
  List<ConsumerPropertySummary> featuredProperties = const [];
  List<ConsumerPropertySummary> listings = const [];
  List<ConsumerPropertyMapPoint> mapPoints = const [];
  List<ConsumerPropertySummary> savedProperties = const [];
  List<ConsumerNotificationRecord> notifications = const [];

  String searchQuery = '';
  String? listingTypeFilter;
  String? propertyTypeFilter;
  bool usingCachedCatalog = false;
  String? catalogWarning;
  DateTime? catalogSnapshotSavedAt;
  String? authError;
  int unreadNotificationCount = 0;
  bool isCatalogLoading = false;
  bool isLoadingMoreListings = false;
  bool hasMoreListings = true;
  bool isSubmittingAuth = false;
  bool isSubmittingMfa = false;
  bool isLoadingNotifications = false;
  bool isLoadingSavedProperties = false;
  bool isProcessingBiometric = false;
  bool biometricQuickUnlockEnabled = false;
  ConsumerCameraPermissionStatus cameraPermissionStatus =
      const ConsumerCameraPermissionStatus();
  String? _pendingMfaToken;
  DateTime? _pendingMfaExpiresAt;
  ConsumerBiometricCapability biometricCapability =
      const ConsumerBiometricCapability();
  int _catalogPage = 1;
  Timer? _catalogReconnectTimer;

  ConsumerSession get session => _session;
  String? get pendingMfaToken => _pendingMfaToken;
  DateTime? get pendingMfaExpiresAt => _pendingMfaExpiresAt;
  bool get hasPendingMfaChallenge => (_pendingMfaToken ?? '').isNotEmpty;

  bool get isAuthenticated => _session.isAuthenticated;
  bool get canOfferBiometricQuickUnlock =>
      isAuthenticated && biometricCapability.canAuthenticate;
  bool get hasBiometricQuickUnlockReady =>
      canOfferBiometricQuickUnlock && biometricQuickUnlockEnabled;

  String get baseUrl => _session.normalizedBaseUrl;
  String get primaryRole => profile?.resolvedPrimaryRole ?? 'guest';
  bool get isBuyerLike => isBuyerLikeRole(primaryRole);
  bool get isSellerLike => isSellerLikeRole(primaryRole);
  bool get isProfessionalUser => isProfessionalRole(primaryRole);
  bool isPropertySaved(String propertyId) =>
      savedProperties.any((item) => item.id == propertyId);

  bool _shouldReplaceStoredDebugBaseUrl(
    String storedBaseUrl,
    String preferred,
  ) {
    final normalizedStored = storedBaseUrl.trim();
    final normalizedPreferred = preferred.trim();
    if (normalizedPreferred.isEmpty ||
        normalizedStored == normalizedPreferred) {
      return false;
    }
    return _isLocalDebugServerBaseUrl(normalizedStored);
  }

  bool _isLocalDebugServerBaseUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'http') {
      return false;
    }
    if (uri.port != 8080) {
      return false;
    }

    final host = uri.host.trim().toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return true;
    }

    final octets = host.split('.');
    if (octets.length != 4) {
      return false;
    }

    final values = octets.map(int.tryParse).toList(growable: false);
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }

    final first = values[0]!;
    final second = values[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 192 && second == 168) ||
        (first == 172 && second >= 16 && second <= 31);
  }

  List<ConsumerPropertySummary> get visibleListings => listings
      .where((item) {
        final matchesQuery = searchQuery.trim().isEmpty
            ? true
            : item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  item.city.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  item.region.toLowerCase().contains(searchQuery.toLowerCase());
        final matchesListingType =
            listingTypeFilter == null || item.listingType == listingTypeFilter;
        final matchesPropertyType =
            propertyTypeFilter == null || item.type == propertyTypeFilter;
        return matchesQuery && matchesListingType && matchesPropertyType;
      })
      .toList(growable: false);

  Future<void> bootstrap() async {
    final storedSession = await _sessionStore.load();
    if (storedSession != null) {
      final shouldReplaceStoredDebugBaseUrl = _shouldReplaceStoredDebugBaseUrl(
        storedSession.normalizedBaseUrl,
        _defaultBaseUrl,
      );
      final resolvedStoredBaseUrl = shouldReplaceStoredDebugBaseUrl
          ? _defaultBaseUrl
          : storedSession.normalizedBaseUrl;
      _session = storedSession.copyWith(
        baseUrl: storedSession.hasServer
            ? resolvedStoredBaseUrl
            : _defaultBaseUrl,
      );
      if (shouldReplaceStoredDebugBaseUrl) {
        await _sessionStore.save(_session);
      }
      currentTab =
          ConsumerTab.values[storedSession.preferredTabIndex.clamp(
            0,
            ConsumerTab.values.length - 1,
          )];
    }

    await loadBiometricState(notify: false);
    await _primeWorkspaceFromCache();

    await Future<void>.delayed(splashDuration);

    if (_session.isAuthenticated) {
      if (hasBiometricQuickUnlockReady) {
        stage = ConsumerStage.biometricUnlock;
        _syncCatalogReconnectLoop();
        notifyListeners();
        return;
      }

      stage = ConsumerStage.marketplace;
      _syncCatalogReconnectLoop();
      notifyListeners();
      await refreshMarketplace();
      return;
    }

    stage = ConsumerStage.welcome;
    _syncCatalogReconnectLoop();
    notifyListeners();
    await loadCatalog();
  }

  void openWelcome() {
    stage = ConsumerStage.welcome;
    _syncCatalogReconnectLoop();
    notifyListeners();
  }

  void openRegister() {
    authError = null;
    stage = ConsumerStage.register;
    _syncCatalogReconnectLoop();
    notifyListeners();
  }

  void openLogin() {
    authError = null;
    stage = ConsumerStage.login;
    _syncCatalogReconnectLoop();
    notifyListeners();
  }

  Future<void> continueAsGuest() async {
    stage = ConsumerStage.marketplace;
    _syncCatalogReconnectLoop();
    notifyListeners();
    await loadCatalog();
  }

  Future<void> loadBiometricState({bool notify = true}) async {
    biometricCapability = await _biometricService.getCapability();
    biometricQuickUnlockEnabled = await _securityPreferencesStore
        .loadBiometricQuickUnlockEnabled();
    cameraPermissionStatus = await _devicePermissionService.getCameraStatus();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> refreshCameraPermissionStatus() async {
    cameraPermissionStatus = await _devicePermissionService.getCameraStatus();
    notifyListeners();
  }

  Future<bool> ensureCameraPermission() async {
    cameraPermissionStatus = await _devicePermissionService
        .requestCameraAccess();
    notifyListeners();
    return cameraPermissionStatus.isGranted;
  }

  Future<bool> openSystemPermissionSettings() async {
    final opened = await _devicePermissionService.openSystemSettings();
    if (opened) {
      await refreshCameraPermissionStatus();
    }
    return opened;
  }

  Future<bool> authenticateDeviceBiometric({
    required String reason,
    String title = 'Real Estate Secure',
    String subtitle = 'Confirm your identity to continue',
  }) async {
    isProcessingBiometric = true;
    notifyListeners();
    try {
      return await _biometricService.authenticate(
        reason: reason,
        title: title,
        subtitle: subtitle,
      );
    } finally {
      isProcessingBiometric = false;
      notifyListeners();
    }
  }

  Future<bool> unlockWithBiometric() async {
    if (!hasBiometricQuickUnlockReady) {
      return false;
    }

    final authenticated = await authenticateDeviceBiometric(
      reason:
          'Unlock your secure workspace using your biometric or secure screen lock.',
      subtitle:
          'Use your biometric or secure screen lock to open the saved session',
    );
    if (!authenticated) {
      return false;
    }

    stage = ConsumerStage.marketplace;
    _syncCatalogReconnectLoop();
    notifyListeners();
    await refreshMarketplace();
    return true;
  }

  Future<bool> enableBiometricQuickUnlock() async {
    await loadBiometricState(notify: false);
    if (!canOfferBiometricQuickUnlock) {
      notifyListeners();
      return false;
    }

    final authenticated = await authenticateDeviceBiometric(
      reason:
          'Enable quick unlock for this saved secure session on this device.',
      subtitle:
          'Confirm with your biometric or secure screen lock to enable quick unlock',
    );
    if (!authenticated) {
      return false;
    }

    await _securityPreferencesStore.saveBiometricQuickUnlockEnabled(true);
    biometricQuickUnlockEnabled = true;
    notifyListeners();
    return true;
  }

  Future<void> disableBiometricQuickUnlock() async {
    await _securityPreferencesStore.saveBiometricQuickUnlockEnabled(false);
    biometricQuickUnlockEnabled = false;
    notifyListeners();
  }

  void setTab(ConsumerTab tab) {
    currentTab = tab;
    _persistSession();
    notifyListeners();
  }

  void updateSearch(String value) {
    searchQuery = value.trim();
    notifyListeners();
  }

  void applyFilter({
    String? listingType,
    String? propertyType,
    ConsumerTab? tab,
  }) {
    listingTypeFilter = listingType;
    propertyTypeFilter = propertyType;
    if (tab != null) {
      currentTab = tab;
      _persistSession();
    }
    notifyListeners();
  }

  void clearFilters() {
    listingTypeFilter = null;
    propertyTypeFilter = null;
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String role,
  }) async {
    isSubmittingAuth = true;
    authError = null;
    notifyListeners();
    try {
      final result = await _apiClient.register(
        baseUrl: _session.normalizedBaseUrl,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        dateOfBirth: dateOfBirth,
        role: role,
      );
      await _applyAuthenticatedResult(result);
      await refreshMarketplace();
      return true;
    } on ConsumerApiFailure catch (error) {
      authError = error.message;
      return false;
    } catch (_) {
      authError =
          'We could not create your account right now. Please try again.';
      return false;
    } finally {
      isSubmittingAuth = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    isSubmittingAuth = true;
    authError = null;
    clearPendingMfaChallenge(notify: false);
    notifyListeners();
    try {
      final result = await _apiClient.login(
        baseUrl: _session.normalizedBaseUrl,
        email: email,
        password: password,
      );
      await _applyAuthenticatedResult(result);
      await refreshMarketplace();
      return true;
    } on ConsumerMfaRequired catch (error) {
      _pendingMfaToken = error.mfaToken;
      _pendingMfaExpiresAt = DateTime.now().add(
        Duration(seconds: error.expiresIn),
      );
      authError = null;
      return false;
    } on ConsumerApiFailure catch (error) {
      authError = error.message;
      clearPendingMfaChallenge(notify: false);
      return false;
    } catch (_) {
      authError = 'We could not sign you in right now. Please try again.';
      clearPendingMfaChallenge(notify: false);
      return false;
    } finally {
      isSubmittingAuth = false;
      notifyListeners();
    }
  }

  Future<bool> completeTwoFactorLogin(String code) async {
    if (!hasPendingMfaChallenge) {
      authError = 'A two-factor challenge is not active.';
      notifyListeners();
      return false;
    }

    isSubmittingMfa = true;
    authError = null;
    notifyListeners();
    try {
      final result = await _apiClient.completeTwoFactorLogin(
        baseUrl: _session.normalizedBaseUrl,
        mfaToken: _pendingMfaToken!,
        code: code,
      );
      clearPendingMfaChallenge(notify: false);
      await _applyAuthenticatedResult(result);
      await refreshMarketplace();
      return true;
    } on ConsumerApiFailure catch (error) {
      authError = error.message;
      return false;
    } finally {
      isSubmittingMfa = false;
      notifyListeners();
    }
  }

  Future<ConsumerActionPreview> requestPasswordReset(String email) {
    return _apiClient.requestPasswordReset(
      baseUrl: _session.normalizedBaseUrl,
      email: email,
    );
  }

  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) {
    return _apiClient.completePasswordReset(
      baseUrl: _session.normalizedBaseUrl,
      token: token,
      password: password,
    );
  }

  Future<ConsumerTwoFactorSetup> beginTwoFactorEnrollment({
    bool force = false,
  }) {
    return _apiClient.beginTwoFactorEnrollment(_session, force: force);
  }

  Future<void> confirmTwoFactorEnrollment(String code) async {
    await _apiClient.confirmTwoFactorEnrollment(_session, code: code);
    await loadProfileAndTasks();
  }

  void clearPendingMfaChallenge({bool notify = true}) {
    _pendingMfaToken = null;
    _pendingMfaExpiresAt = null;
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final preservedBaseUrl = _session.normalizedBaseUrl;
    await _sessionStore.clear();
    await _workspaceCacheStore.clear();
    await _securityPreferencesStore.saveBiometricQuickUnlockEnabled(false);
    _session = ConsumerSession(baseUrl: preservedBaseUrl);
    profile = null;
    tasks = const [];
    savedProperties = const [];
    notifications = const [];
    unreadNotificationCount = 0;
    biometricQuickUnlockEnabled = false;
    clearPendingMfaChallenge(notify: false);
    stage = ConsumerStage.welcome;
    _syncCatalogReconnectLoop();
    notifyListeners();
    await loadCatalog();
  }

  Future<void> refreshMarketplace() async {
    await Future.wait([
      loadCatalog(reset: true),
      if (isAuthenticated) loadProfileAndTasks(),
      if (isAuthenticated) loadNotificationCount(),
      if (isAuthenticated) loadSavedProperties(),
    ]);
  }

  Future<void> loadCatalog({bool reset = true}) async {
    if (!reset &&
        (isCatalogLoading || isLoadingMoreListings || !hasMoreListings)) {
      return;
    }

    if (reset) {
      isCatalogLoading = true;
      catalogWarning = null;
      await _primeCatalogFromCache();
    } else {
      isLoadingMoreListings = true;
      notifyListeners();
    }

    try {
      if (reset) {
        final results = await Future.wait<Object>([
          _apiClient.listProperties(
            baseUrl: _session.normalizedBaseUrl,
            featuredOnly: true,
            limit: 6,
            page: 1,
          ),
          _apiClient.listProperties(
            baseUrl: _session.normalizedBaseUrl,
            limit: _catalogPageSize,
            page: 1,
          ),
          _apiClient.listMapPoints(
            baseUrl: _session.normalizedBaseUrl,
            limit: 24,
            page: 1,
          ),
        ]);
        final featured = results[0] as List<ConsumerPropertySummary>;
        final all = results[1] as List<ConsumerPropertySummary>;
        final map = results[2] as List<ConsumerPropertyMapPoint>;
        featuredProperties = featured.isEmpty ? all.take(6).toList() : featured;
        listings = all;
        mapPoints = map;
        _catalogPage = 1;
        hasMoreListings = all.length >= _catalogPageSize;
      } else {
        final nextPage = _catalogPage + 1;
        final more = await _apiClient.listProperties(
          baseUrl: _session.normalizedBaseUrl,
          limit: _catalogPageSize,
          page: nextPage,
        );
        if (more.isNotEmpty) {
          final existingIds = listings.map((item) => item.id).toSet();
          final merged = [
            ...listings,
            ...more.where((item) => !existingIds.contains(item.id)),
          ];
          listings = merged;
          _catalogPage = nextPage;
        }
        hasMoreListings = more.length >= _catalogPageSize;
      }

      usingCachedCatalog = false;
      catalogWarning = null;
      catalogSnapshotSavedAt = DateTime.now();
      await _catalogCacheStore.save(
        ConsumerCatalogCacheSnapshot(
          featuredProperties: featuredProperties,
          listings: listings,
          mapPoints: mapPoints,
          savedAt: catalogSnapshotSavedAt!,
        ),
      );
    } catch (_) {
      if (reset) {
        final hasCurrentCatalog =
            featuredProperties.isNotEmpty ||
            listings.isNotEmpty ||
            mapPoints.isNotEmpty;
        final cachedSnapshot = await _catalogCacheStore.load();
        if (hasCurrentCatalog) {
          usingCachedCatalog = true;
          hasMoreListings = listings.length >= _catalogPageSize;
          catalogWarning = 'Offline. Showing saved listings.';
        } else if (cachedSnapshot != null &&
            (cachedSnapshot.listings.isNotEmpty ||
                cachedSnapshot.featuredProperties.isNotEmpty ||
                cachedSnapshot.mapPoints.isNotEmpty)) {
          _applyCatalogSnapshot(cachedSnapshot, fromCache: true);
          catalogWarning = 'Offline. Showing saved listings.';
        } else {
          featuredProperties = const [];
          listings = const [];
          mapPoints = const [];
          usingCachedCatalog = false;
          _catalogPage = 1;
          hasMoreListings = false;
          catalogWarning = 'We could not load listings right now.';
        }
      } else {
        catalogWarning ??= 'We could not load more listings right now.';
      }
    } finally {
      if (reset) {
        isCatalogLoading = false;
      } else {
        isLoadingMoreListings = false;
      }
      _syncCatalogReconnectLoop();
      notifyListeners();
    }
  }

  Future<void> loadMoreListings() => loadCatalog(reset: false);

  Future<void> _primeCatalogFromCache() async {
    final shouldPrimeFromCache =
        featuredProperties.isEmpty && listings.isEmpty && mapPoints.isEmpty;
    if (!shouldPrimeFromCache) {
      notifyListeners();
      return;
    }

    final cachedSnapshot = await _catalogCacheStore.load();
    if (cachedSnapshot == null) {
      notifyListeners();
      return;
    }

    _applyCatalogSnapshot(cachedSnapshot, fromCache: true);
    catalogWarning = 'Updating saved listings.';
    notifyListeners();
  }

  void _applyCatalogSnapshot(
    ConsumerCatalogCacheSnapshot snapshot, {
    required bool fromCache,
  }) {
    featuredProperties = snapshot.featuredProperties;
    listings = snapshot.listings;
    mapPoints = snapshot.mapPoints;
    usingCachedCatalog = fromCache;
    catalogSnapshotSavedAt = snapshot.savedAt;
    _catalogPage = _pageForCount(snapshot.listings.length);
    hasMoreListings = snapshot.listings.length >= _catalogPageSize;
  }

  Future<void> _primeWorkspaceFromCache() async {
    if (!_session.isAuthenticated) {
      return;
    }

    final snapshot = await _workspaceCacheStore.load();
    if (snapshot == null) {
      return;
    }

    _applyWorkspaceSnapshot(snapshot);
  }

  void _applyWorkspaceSnapshot(ConsumerWorkspaceCacheSnapshot snapshot) {
    if (snapshot.profile != null) {
      profile = snapshot.profile;
      _session = _session.copyWith(
        userUuid: snapshot.profile!.uuid,
        email: snapshot.profile!.email,
        fullName: snapshot.profile!.displayName,
      );
    }

    if (snapshot.tasks.isNotEmpty) {
      tasks = snapshot.tasks;
    }

    if (snapshot.savedProperties.isNotEmpty) {
      savedProperties = snapshot.savedProperties;
    }

    if (snapshot.unreadNotificationCount >= 0) {
      unreadNotificationCount = snapshot.unreadNotificationCount;
    }
  }

  Future<void> _persistWorkspaceSnapshot() async {
    if (!isAuthenticated || profile == null) {
      return;
    }

    await _workspaceCacheStore.save(
      ConsumerWorkspaceCacheSnapshot(
        profile: profile,
        tasks: tasks,
        savedProperties: savedProperties,
        unreadNotificationCount: unreadNotificationCount,
        savedAt: DateTime.now(),
      ),
    );
  }

  int _pageForCount(int count) {
    if (count <= 0) {
      return 1;
    }
    return ((count - 1) ~/ _catalogPageSize) + 1;
  }

  Future<void> loadProfileAndTasks() async {
    if (!isAuthenticated) {
      profile = null;
      tasks = const [];
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait<Object>([
        _apiClient.getProfile(_session),
        _apiClient.getTasks(_session),
      ]);
      final refreshedProfile = results[0] as ConsumerUserProfile;
      if (refreshedProfile.hasRestrictedMobileRole) {
        await _blockRestrictedMobileAccount();
        return;
      }
      profile = refreshedProfile;
      tasks = results[1] as List<ConsumerTask>;
      _session = _session.copyWith(
        userUuid: profile?.uuid,
        email: profile?.email,
        fullName: profile?.displayName,
      );
      await _persistSession();
      await _persistWorkspaceSnapshot();
      notifyListeners();
    } on ConsumerApiFailure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _recoverFromExpiredSession(
          authMessage:
              'Your session expired. Sign in again when you want to manage billing or secure actions.',
        );
        return;
      }
      final snapshot = await _workspaceCacheStore.load();
      if (snapshot != null) {
        _applyWorkspaceSnapshot(snapshot);
        notifyListeners();
      }
    }
  }

  Future<void> loadNotificationCount() async {
    if (!isAuthenticated) {
      unreadNotificationCount = 0;
      notifyListeners();
      return;
    }
    try {
      unreadNotificationCount = await _apiClient.unreadNotificationCount(
        _session,
      );
      await _persistWorkspaceSnapshot();
      notifyListeners();
    } on ConsumerApiFailure {
      if (unreadNotificationCount <= 0) {
        final snapshot = await _workspaceCacheStore.load();
        if (snapshot != null) {
          unreadNotificationCount = snapshot.unreadNotificationCount;
        }
      }
      notifyListeners();
    }
  }

  Future<void> loadSavedProperties() async {
    if (!isAuthenticated) {
      savedProperties = const [];
      notifyListeners();
      return;
    }

    isLoadingSavedProperties = true;
    notifyListeners();
    try {
      savedProperties = await _apiClient.listFavorites(_session);
      await _persistWorkspaceSnapshot();
    } on ConsumerApiFailure {
      if (savedProperties.isEmpty) {
        final snapshot = await _workspaceCacheStore.load();
        if (snapshot != null) {
          savedProperties = snapshot.savedProperties;
        }
      }
    } finally {
      isLoadingSavedProperties = false;
      notifyListeners();
    }
  }

  Future<void> setFavoriteStatus({
    required String propertyId,
    required bool isFavorite,
  }) async {
    if (!isAuthenticated) {
      return;
    }

    await _apiClient.setFavoriteStatus(
      _session,
      propertyId: propertyId,
      isFavorite: isFavorite,
    );
    await loadSavedProperties();
  }

  Future<List<ConsumerNotificationRecord>> loadNotifications() async {
    if (!isAuthenticated) {
      notifications = const [];
      notifyListeners();
      return notifications;
    }

    isLoadingNotifications = true;
    notifyListeners();
    try {
      notifications = await _apiClient.listNotifications(_session);
      unreadNotificationCount = notifications
          .where((item) => item.status == 'unread')
          .length;
      await _persistWorkspaceSnapshot();
      return notifications;
    } on ConsumerApiFailure {
      if (notifications.isEmpty) {
        final snapshot = await _workspaceCacheStore.load();
        if (snapshot != null) {
          unreadNotificationCount = snapshot.unreadNotificationCount;
        }
      }
      return notifications;
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (!isAuthenticated) {
      return;
    }
    await _apiClient.markNotificationRead(_session, notificationId);
    notifications = notifications
        .map(
          (item) => item.id == notificationId
              ? ConsumerNotificationRecord(
                  id: item.id,
                  title: item.title,
                  body: item.body,
                  severity: item.severity,
                  category: item.category,
                  status: 'read',
                  actionUrl: item.actionUrl,
                  actionLabel: item.actionLabel,
                  createdAt: item.createdAt,
                )
              : item,
        )
        .toList(growable: false);
    unreadNotificationCount = notifications
        .where((item) => item.status == 'unread')
        .length;
    unawaited(_persistWorkspaceSnapshot());
    notifyListeners();
  }

  Future<void> dismissNotification(String notificationId) async {
    if (!isAuthenticated) {
      return;
    }
    await _apiClient.dismissNotification(_session, notificationId);
    notifications = notifications
        .where((item) => item.id != notificationId)
        .toList(growable: false);
    unreadNotificationCount = notifications
        .where((item) => item.status == 'unread')
        .length;
    unawaited(_persistWorkspaceSnapshot());
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    if (!isAuthenticated) {
      return;
    }
    await _apiClient.markAllNotificationsRead(_session);
    notifications = notifications
        .map(
          (item) => ConsumerNotificationRecord(
            id: item.id,
            title: item.title,
            body: item.body,
            severity: item.severity,
            category: item.category,
            status: 'read',
            actionUrl: item.actionUrl,
            actionLabel: item.actionLabel,
            createdAt: item.createdAt,
          ),
        )
        .toList(growable: false);
    unreadNotificationCount = 0;
    unawaited(_persistWorkspaceSnapshot());
    notifyListeners();
  }

  Future<ConsumerPropertyDetail> loadPropertyDetail(String propertyId) async {
    return _apiClient.getPropertyDetail(
      baseUrl: _session.normalizedBaseUrl,
      propertyId: propertyId,
    );
  }

  Future<List<ConsumerPropertyDocument>> loadPropertyDocuments(
    String propertyId,
  ) async {
    try {
      return await _apiClient.getPropertyDocuments(
        baseUrl: _session.normalizedBaseUrl,
        propertyId: propertyId,
      );
    } on ConsumerApiFailure {
      return const [];
    }
  }

  Future<List<ConsumerPropertyImage>> loadPropertyImages(
    String propertyId,
  ) async {
    try {
      return await _apiClient.getPropertyImages(
        baseUrl: _session.normalizedBaseUrl,
        propertyId: propertyId,
      );
    } on ConsumerApiFailure {
      return const [];
    }
  }

  Future<ConsumerUploadedAsset> uploadAsset({
    required String category,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) {
    return _apiClient.uploadAsset(
      _session,
      category: category,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  Future<ConsumerUploadCapabilities> loadUploadCapabilities() async {
    if (!isAuthenticated) {
      return defaultConsumerUploadCapabilities;
    }
    return _apiClient.getUploadCapabilities(_session);
  }

  Future<ConsumerKycRecord> submitKyc({
    required String documentType,
    required String documentNumber,
    required String issueDate,
    String? expiryDate,
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String frontImagePath,
    String? backImagePath,
    String? portraitImagePath,
    String? livenessVideoPath,
  }) async {
    final record = await _apiClient.submitKyc(
      _session,
      documentType: documentType,
      documentNumber: documentNumber,
      issueDate: issueDate,
      expiryDate: expiryDate,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      frontImagePath: frontImagePath,
      backImagePath: backImagePath,
      portraitImagePath: portraitImagePath,
      livenessVideoPath: livenessVideoPath,
    );
    await loadProfileAndTasks();
    return record;
  }

  Future<ConsumerKycSession> createKycSession() {
    if (!isAuthenticated) {
      throw StateError('You need to sign in before starting KYC.');
    }
    return _apiClient.createKycSession(_session);
  }

  Future<ConsumerKycSession> createContactVerificationSession({
    required String channel,
  }) {
    if (!isAuthenticated) {
      throw StateError('You need to sign in before starting verification.');
    }
    return _apiClient.createContactVerificationSession(
      _session,
      channel: channel,
    );
  }

  Future<ConsumerContactVerificationResult> refreshContactVerification({
    required String channel,
    String? externalActionId,
  }) async {
    if (!isAuthenticated) {
      return ConsumerContactVerificationResult(
        channel: channel,
        verified: false,
        verificationStatus: 'pending',
        reviewStatus: 'init',
      );
    }
    final result = await _apiClient.refreshContactVerification(
      _session,
      channel: channel,
      externalActionId: externalActionId,
    );
    await loadProfileAndTasks();
    return result;
  }

  Future<ConsumerKycCaptureResult> launchPrimaryKycFlow({
    required Locale locale,
  }) async {
    if (!isAuthenticated) {
      throw StateError('You need to sign in before starting KYC.');
    }

    final currentProfile = profile;
    if (currentProfile == null) {
      throw StateError('Profile data is required before starting KYC.');
    }

    final session = await createKycSession();
    final launchResult = await _kycCaptureService.launch(
      session: session,
      locale: locale,
      email: currentProfile.email,
      phone: currentProfile.phoneNumber,
      onTokenExpiration: () async {
        final refreshedSession = await createKycSession();
        return refreshedSession.accessToken;
      },
    );

    if (launchResult.shouldRefreshStatus) {
      await refreshKycStatus();
    }

    return launchResult;
  }

  Future<ConsumerKycCaptureResult> launchContactVerificationFlow({
    required String channel,
    required Locale locale,
  }) async {
    if (!isAuthenticated) {
      throw StateError('You need to sign in before starting verification.');
    }

    final normalizedChannel = channel.trim().toLowerCase();
    if (normalizedChannel != 'email' && normalizedChannel != 'phone') {
      throw StateError('Verification channel must be email or phone.');
    }

    final currentProfile = profile;
    if (currentProfile == null) {
      throw StateError(
        'Profile data is required before starting verification.',
      );
    }

    final session = await createContactVerificationSession(
      channel: normalizedChannel,
    );
    final launchResult = await _kycCaptureService.launch(
      session: session,
      locale: locale,
      email: normalizedChannel == 'email' ? currentProfile.email : null,
      phone: normalizedChannel == 'phone' ? currentProfile.phoneNumber : null,
      onTokenExpiration: () async {
        final refreshedSession = await createContactVerificationSession(
          channel: normalizedChannel,
        );
        return refreshedSession.accessToken;
      },
    );

    if (launchResult.shouldRefreshStatus) {
      await refreshContactVerification(
        channel: normalizedChannel,
        externalActionId: session.externalActionId,
      );
    }

    return launchResult;
  }

  Future<List<ConsumerTransactionSummary>> loadTransactions() {
    if (!isAuthenticated) {
      return Future.value(const []);
    }
    return _apiClient.listTransactions(_session);
  }

  Future<ConsumerTransactionSummary> initiateTransaction({
    required String propertyId,
    required String sellerId,
    required String transactionType,
    required double propertyPrice,
  }) {
    return _apiClient.initiateTransaction(
      _session,
      propertyId: propertyId,
      sellerId: sellerId,
      transactionType: transactionType,
      propertyPrice: propertyPrice,
    );
  }

  Future<ConsumerTransactionDetail> loadTransactionDetail(
    String transactionId,
  ) {
    return _apiClient.getTransactionDetail(_session, transactionId);
  }

  Future<ConsumerTransactionCompliance> loadTransactionCompliance(
    String transactionId,
  ) {
    return _apiClient.getTransactionCompliance(_session, transactionId);
  }

  Future<List<ConsumerTimelineEvent>> loadTransactionTimeline(
    String transactionId,
  ) {
    return _apiClient.getTransactionTimeline(_session, transactionId);
  }

  Future<List<ConsumerSubscriptionPlan>> loadSubscriptionPlans() async {
    try {
      final plans = await _apiClient.listSubscriptionPlans(
        baseUrl: _session.normalizedBaseUrl,
      );
      return plans.isEmpty ? _fallbackSubscriptionPlans : plans;
    } on ConsumerApiFailure catch (error) {
      final looksAuthRelated = _looksLikeAuthRelatedSubscriptionFailure(error);
      if ((error.statusCode == 401 ||
              error.statusCode == 403 ||
              looksAuthRelated) &&
          isAuthenticated) {
        try {
          final plans = await _apiClient.listSubscriptionPlansAuthenticated(
            _session,
          );
          return plans.isEmpty ? _fallbackSubscriptionPlans : plans;
        } on ConsumerApiFailure {
          return _fallbackSubscriptionPlans;
        } catch (_) {
          return _fallbackSubscriptionPlans;
        }
      }
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          looksAuthRelated) {
        return _fallbackSubscriptionPlans;
      }
      if (error.statusCode == null || (error.statusCode ?? 0) >= 500) {
        return _fallbackSubscriptionPlans;
      }
      return _fallbackSubscriptionPlans;
    } catch (_) {
      return _fallbackSubscriptionPlans;
    }
  }

  Future<List<CameroonRegionCatalog>> loadCameroonLocationCatalog() async {
    try {
      final catalog = await _apiClient.listCameroonLocationCatalog(
        baseUrl: _session.normalizedBaseUrl,
      );
      if (catalog.isEmpty) {
        return cameroonLocationCatalog;
      }
      return mergeCameroonLocationCatalogWithBackend(catalog);
    } catch (_) {
      return cameroonLocationCatalog;
    }
  }

  List<ConsumerSubscriptionPlan> get fallbackSubscriptionPlans =>
      List<ConsumerSubscriptionPlan>.unmodifiable(_fallbackSubscriptionPlans);

  Future<ConsumerCurrentSubscription?> loadCurrentSubscription() async {
    if (!isAuthenticated) {
      return null;
    }
    try {
      return await _apiClient.getCurrentSubscription(_session);
    } on ConsumerApiFailure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  static const List<ConsumerSubscriptionPlan> _fallbackSubscriptionPlans = [
    ConsumerSubscriptionPlan(
      id: 1,
      planName: 'Free',
      planCode: 'free',
      priceMonthly: 0,
      priceYearly: null,
      currency: 'XAF',
      maxListings: 1,
      maxPhotosPerListing: 5,
      maxVideosPerListing: 0,
      featuredListingsIncluded: 0,
      prioritySupport: false,
      analyticsAccess: false,
      apiAccess: false,
      bulkListingTools: false,
      companyProfile: false,
      badgeDisplay: '',
      description: 'Starter access for individual buyers and sellers.',
      features: [
        'Basic listings',
        'Standard support',
        'Access to paid verification and promotion services',
      ],
    ),
    ConsumerSubscriptionPlan(
      id: 2,
      planName: 'Basic',
      planCode: 'basic',
      priceMonthly: 5000,
      priceYearly: 50000,
      currency: 'XAF',
      maxListings: 3,
      maxPhotosPerListing: 10,
      maxVideosPerListing: 0,
      featuredListingsIncluded: 0,
      prioritySupport: false,
      analyticsAccess: true,
      apiAccess: false,
      bulkListingTools: false,
      companyProfile: false,
      badgeDisplay: 'verified',
      description: 'For independent sellers and small property managers.',
      features: [
        'Priority verification queue',
        'Analytics dashboard',
        'Email support',
        'Discounted listing boosts',
      ],
    ),
    ConsumerSubscriptionPlan(
      id: 3,
      planName: 'Standard',
      planCode: 'standard',
      priceMonthly: 10000,
      priceYearly: 100000,
      currency: 'XAF',
      maxListings: 6,
      maxPhotosPerListing: 15,
      maxVideosPerListing: 1,
      featuredListingsIncluded: 1,
      prioritySupport: true,
      analyticsAccess: true,
      apiAccess: false,
      bulkListingTools: true,
      companyProfile: true,
      badgeDisplay: 'premium',
      description: 'Growing teams and multi-property sellers.',
      features: [
        'Featured listing credits',
        'Priority support',
        'Market insights',
        'Document vault access',
      ],
    ),
    ConsumerSubscriptionPlan(
      id: 4,
      planName: 'Professional',
      planCode: 'pro',
      priceMonthly: 20000,
      priceYearly: 200000,
      currency: 'XAF',
      maxListings: 12,
      maxPhotosPerListing: 20,
      maxVideosPerListing: 3,
      featuredListingsIncluded: 3,
      prioritySupport: true,
      analyticsAccess: true,
      apiAccess: true,
      bulkListingTools: true,
      companyProfile: true,
      badgeDisplay: 'pro',
      description: 'High-volume sellers and developers.',
      features: [
        'API access',
        'Dedicated success manager',
        'Bulk tools',
        'Developer workspace discount',
      ],
    ),
  ];

  Future<ConsumerPaymentGatewaySummary> loadPaymentGatewaySummary() {
    return _apiClient.getPaymentGatewaySummary(
      baseUrl: _session.normalizedBaseUrl,
    );
  }

  Future<ConsumerSubscriptionCheckoutSession> startSubscriptionCheckout({
    required ConsumerSubscriptionPlan plan,
    required String billingCycle,
    String? redirectUrl,
  }) {
    if (!isAuthenticated) {
      throw StateError(
        'You need to sign in before starting subscription checkout.',
      );
    }
    return _apiClient.createSubscriptionCheckout(
      _session,
      planId: plan.id,
      billingCycle: billingCycle,
      redirectUrl: redirectUrl,
    );
  }

  Future<ConsumerSubscriptionCheckoutState?> loadLatestSubscriptionCheckout({
    String? reference,
  }) async {
    if (!isAuthenticated) {
      return null;
    }
    try {
      return await _apiClient.getLatestSubscriptionCheckout(
        _session,
        reference: reference,
      );
    } on ConsumerApiFailure catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> activateSubscription({
    required ConsumerSubscriptionPlan plan,
    required String billingCycle,
    required bool alreadyActive,
  }) async {
    if (alreadyActive) {
      await _apiClient.upgradeSubscription(_session, planId: plan.id);
      return;
    }

    final now = DateTime.now();
    final endDate = billingCycle == 'yearly'
        ? DateTime(now.year + 1, now.month, now.day)
        : DateTime(now.year, now.month + 1, now.day);
    await _apiClient.createSubscription(
      _session,
      plan: plan,
      billingCycle: billingCycle,
      startDate: now,
      endDate: endDate,
    );
  }

  Future<void> cancelSubscription({String? reason}) {
    return _apiClient.cancelSubscription(_session, reason: reason);
  }

  Future<List<ConsumerServiceCatalogItem>> loadServiceCatalog() {
    return _apiClient.listServiceCatalog(baseUrl: _session.normalizedBaseUrl);
  }

  Future<String> createProperty({
    required String propertyType,
    required String listingType,
    required String title,
    required String description,
    required double price,
    required String region,
    required String department,
    required String city,
    String? district,
    String? neighborhood,
    String? streetAddress,
    String? landmark,
    required double latitude,
    required double longitude,
  }) {
    return _apiClient.createProperty(
      _session,
      propertyType: propertyType,
      listingType: listingType,
      title: title,
      description: description,
      price: price,
      region: region,
      department: department,
      city: city,
      district: district,
      neighborhood: neighborhood,
      streetAddress: streetAddress,
      landmark: landmark,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<void> addPropertyImage({
    required String propertyId,
    required ConsumerUploadedAsset asset,
    required String imageType,
    String? title,
    String? description,
  }) {
    return _apiClient.addPropertyImage(
      _session,
      propertyId: propertyId,
      asset: asset,
      imageType: imageType,
      title: title,
      description: description,
    );
  }

  Future<void> addPropertyDocument({
    required String propertyId,
    required ConsumerUploadedAsset asset,
    required String documentType,
    required String documentNumber,
    required String documentTitle,
    required String issuingAuthority,
    required String issueDate,
    String? expiryDate,
  }) {
    return _apiClient.addPropertyDocument(
      _session,
      propertyId: propertyId,
      asset: asset,
      documentType: documentType,
      documentNumber: documentNumber,
      documentTitle: documentTitle,
      issuingAuthority: issuingAuthority,
      issueDate: issueDate,
      expiryDate: expiryDate,
    );
  }

  Future<void> submitPropertyForVerification(String propertyId) {
    return _apiClient.submitPropertyForVerification(_session, propertyId);
  }

  Future<ConsumerUserProfile> saveProfile({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? preferredLanguage,
    String? bio,
    String? profileImageUrl,
  }) async {
    final updatedProfile = await _apiClient.updateProfile(
      _session,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: phoneNumber,
      preferredLanguage: preferredLanguage,
      bio: bio,
      profileImageUrl: profileImageUrl,
    );
    profile = updatedProfile;
    _session = _session.copyWith(
      userUuid: updatedProfile.uuid,
      email: updatedProfile.email,
      fullName: updatedProfile.displayName,
    );
    await _persistSession();
    notifyListeners();
    return updatedProfile;
  }

  Future<ConsumerUserPreferences> loadPreferences() async {
    if (!isAuthenticated) {
      return const ConsumerUserPreferences(
        locale: 'en',
        emailNotificationsEnabled: true,
        smsNotificationsEnabled: false,
        pushNotificationsEnabled: false,
        marketingNotificationsEnabled: false,
      );
    }
    return _apiClient.getPreferences(_session);
  }

  Future<void> savePreferences({
    String? locale,
    bool? emailNotificationsEnabled,
    bool? smsNotificationsEnabled,
    bool? pushNotificationsEnabled,
    bool? marketingNotificationsEnabled,
  }) async {
    if (!isAuthenticated) {
      return;
    }
    await _apiClient.updatePreferences(
      _session,
      locale: locale,
      emailNotificationsEnabled: emailNotificationsEnabled,
      smsNotificationsEnabled: smsNotificationsEnabled,
      pushNotificationsEnabled: pushNotificationsEnabled,
      marketingNotificationsEnabled: marketingNotificationsEnabled,
    );
  }

  Future<List<ConsumerKycRecord>> loadKycRecords() async {
    if (!isAuthenticated) {
      return const [];
    }
    return _apiClient.getKycStatus(_session);
  }

  Future<List<ConsumerKycRecord>> refreshKycStatus() async {
    if (!isAuthenticated) {
      return const [];
    }
    final records = await _apiClient.refreshKycStatus(_session);
    await loadProfileAndTasks();
    return records;
  }

  Future<ConsumerKycProviderSummary> loadKycProviderSummary() async {
    if (!isAuthenticated) {
      return defaultConsumerKycProviderSummary;
    }
    return _apiClient.getKycProviderSummary(_session);
  }

  Future<void> _attemptBackgroundCatalogRefresh() async {
    if (stage != ConsumerStage.marketplace ||
        isCatalogLoading ||
        isLoadingMoreListings) {
      return;
    }

    await loadCatalog(reset: true);
  }

  void _syncCatalogReconnectLoop() {
    final hasWarning = (catalogWarning ?? '').trim().isNotEmpty;
    final shouldReconnect =
        stage == ConsumerStage.marketplace &&
        (usingCachedCatalog || hasWarning);

    if (!shouldReconnect) {
      _catalogReconnectTimer?.cancel();
      _catalogReconnectTimer = null;
      return;
    }

    _catalogReconnectTimer ??= Timer.periodic(_catalogReconnectInterval, (_) {
      unawaited(_attemptBackgroundCatalogRefresh());
    });
  }

  Future<void> _persistSession() async {
    await _sessionStore.save(
      _session.copyWith(preferredTabIndex: currentTab.index),
    );
  }

  Future<void> _handleSessionRefresh(ConsumerSession refreshedSession) async {
    _session = refreshedSession.copyWith(preferredTabIndex: currentTab.index);
    await _persistSession();
    notifyListeners();
  }

  bool _looksLikeAuthRelatedSubscriptionFailure(ConsumerApiFailure error) {
    final normalizedMessage = error.message.trim().toLowerCase();
    return normalizedMessage.contains('auth') ||
        normalizedMessage.contains('session') ||
        normalizedMessage.contains('token') ||
        normalizedMessage.contains('sign in') ||
        normalizedMessage.contains('sign-in') ||
        normalizedMessage.contains('expired');
  }

  Future<void> _applyAuthenticatedResult(ConsumerAuthResult result) async {
    if (result.profile.hasRestrictedMobileRole) {
      await _blockRestrictedMobileAccount();
      throw const ConsumerApiFailure(
        'This account belongs to the separate administration system and cannot sign in here.',
      );
    }
    _session = result.session.copyWith(
      baseUrl: _session.normalizedBaseUrl,
      preferredTabIndex: currentTab.index,
    );
    profile = result.profile;
    clearPendingMfaChallenge(notify: false);
    stage = ConsumerStage.marketplace;
    _syncCatalogReconnectLoop();
    await _persistSession();
    await _persistWorkspaceSnapshot();
  }

  Future<void> _recoverFromExpiredSession({String? authMessage}) async {
    final preservedBaseUrl = _session.normalizedBaseUrl;
    await _sessionStore.clear();
    await _workspaceCacheStore.clear();
    await _securityPreferencesStore.saveBiometricQuickUnlockEnabled(false);
    _session = ConsumerSession(baseUrl: preservedBaseUrl);
    profile = null;
    tasks = const [];
    savedProperties = const [];
    notifications = const [];
    unreadNotificationCount = 0;
    biometricQuickUnlockEnabled = false;
    clearPendingMfaChallenge(notify: false);
    authError = authMessage;
    if (stage != ConsumerStage.marketplace) {
      stage = ConsumerStage.welcome;
    }
    _syncCatalogReconnectLoop();
    notifyListeners();
  }

  Future<void> _blockRestrictedMobileAccount() async {
    final preservedBaseUrl = _session.normalizedBaseUrl;
    await _sessionStore.clear();
    await _workspaceCacheStore.clear();
    await _securityPreferencesStore.saveBiometricQuickUnlockEnabled(false);
    _session = ConsumerSession(baseUrl: preservedBaseUrl);
    profile = null;
    tasks = const [];
    savedProperties = const [];
    notifications = const [];
    unreadNotificationCount = 0;
    biometricQuickUnlockEnabled = false;
    clearPendingMfaChallenge(notify: false);
    authError =
        'This account uses the separate administration system. Please use the dedicated internal platform.';
    stage = ConsumerStage.welcome;
    _syncCatalogReconnectLoop();
    notifyListeners();
    await loadCatalog();
  }

  @override
  void dispose() {
    _catalogReconnectTimer?.cancel();
    _catalogReconnectTimer = null;
    super.dispose();
  }
}
