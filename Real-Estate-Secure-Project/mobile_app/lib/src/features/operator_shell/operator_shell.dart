import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/assisted_lane_api.dart';
import '../../data/operator_session_store.dart';
import '../assisted_lane/assisted_lane_dashboard.dart';
import '../notifications/notification_center.dart';

enum _OperatorDestination { home, notary, admin, notifications, session }

class OperatorShellPage extends StatefulWidget {
  const OperatorShellPage({super.key, required this.sessionStore});

  final OperatorSessionStore sessionStore;

  @override
  State<OperatorShellPage> createState() => _OperatorShellPageState();
}

class _OperatorShellPageState extends State<OperatorShellPage> {
  PersistedOperatorSession? _persistedSession;
  _OperatorDestination _selectedDestination = _OperatorDestination.home;
  bool _loadingSavedSession = true;
  bool _savingSession = false;
  String? _sessionMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;
    final destinations = _buildDestinations();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForDestination(_selectedDestination)),
        actions: [
          if (_savingSession)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_persistedSession?.isComplete ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Chip(
                  avatar: const Icon(Icons.lock_clock_outlined, size: 18),
                  label: Text(
                    _persistedSession!.transactionId,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              NavigationRail(
                selectedIndex: _selectedDestination.index,
                onDestinationSelected: _selectDestination,
                labelType: NavigationRailLabelType.all,
                destinations: destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _loadingSavedSession
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          if (_sessionMessage case final message?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ShellBanner(message: message),
                            ),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: KeyedSubtree(
                                key: ValueKey(_selectedDestination),
                                child: _buildBodyForDestination(
                                  context,
                                  _selectedDestination,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _selectedDestination.index,
              onDestinationSelected: _selectDestination,
              destinations: destinations
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  List<_ShellDestination> _buildDestinations() => const [
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _ShellDestination(
      label: 'Notary Desk',
      icon: Icons.gavel_outlined,
      selectedIcon: Icons.gavel_rounded,
    ),
    _ShellDestination(
      label: 'Admin Desk',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
    ),
    _ShellDestination(
      label: 'Notifications',
      icon: Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_active_rounded,
    ),
    _ShellDestination(
      label: 'Session',
      icon: Icons.key_outlined,
      selectedIcon: Icons.key_rounded,
    ),
  ];

  Widget _buildBodyForDestination(
    BuildContext context,
    _OperatorDestination destination,
  ) {
    return switch (destination) {
      _OperatorDestination.home => _OperatorHomePage(
        session: _persistedSession,
        onOpenNotary: () => _openDesk(_OperatorDestination.notary),
        onOpenAdmin: () => _openDesk(_OperatorDestination.admin),
        onOpenSession: () =>
            _selectDestination(_OperatorDestination.session.index),
      ),
      _OperatorDestination.notary => AssistedLaneDashboardPage(
        initialDeskIndex: 1,
        showScaffold: false,
        showInternalTabs: false,
        initialSession: _persistedSession?.isComplete == true
            ? _persistedSession?.toApiSession()
            : null,
        onSessionChanged: (session) => _persistSession(
          session,
          preferredDeskIndex: _OperatorDestination.notary.index,
        ),
      ),
      _OperatorDestination.admin => AssistedLaneDashboardPage(
        initialDeskIndex: 2,
        showScaffold: false,
        showInternalTabs: false,
        initialSession: _persistedSession?.isComplete == true
            ? _persistedSession?.toApiSession()
            : null,
        onSessionChanged: (session) => _persistSession(
          session,
          preferredDeskIndex: _OperatorDestination.admin.index,
        ),
      ),
      _OperatorDestination.notifications => NotificationCenterPage(
        session: _persistedSession?.isComplete == true
            ? _persistedSession?.toApiSession()
            : null,
        onOpenSession: () =>
            _selectDestination(_OperatorDestination.session.index),
      ),
      _OperatorDestination.session => _OperatorSessionPage(
        session: _persistedSession,
        onOpenNotary: () => _openDesk(_OperatorDestination.notary),
        onOpenAdmin: () => _openDesk(_OperatorDestination.admin),
        onClearSession: _clearPersistedSession,
      ),
    };
  }

  Future<void> _restoreSession() async {
    setState(() {
      _loadingSavedSession = true;
      _sessionMessage = null;
    });

    try {
      final saved = await widget.sessionStore.load();
      if (!mounted) {
        return;
      }

      setState(() {
        _persistedSession = saved;
        _selectedDestination = _destinationFromIndex(
          saved?.preferredDeskIndex ?? 0,
        );
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage =
            'Saved operator session could not be restored on this device.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSavedSession = false;
        });
      }
    }
  }

  Future<void> _persistSession(
    ApiSession session, {
    required int preferredDeskIndex,
  }) async {
    final persisted = PersistedOperatorSession(
      baseUrl: session.baseUrl,
      bearerToken: session.bearerToken,
      transactionId: session.transactionId,
      preferredDeskIndex: preferredDeskIndex,
    );

    setState(() {
      _savingSession = true;
      _sessionMessage = null;
      _persistedSession = persisted;
    });

    try {
      await widget.sessionStore.save(persisted);
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage =
            'Operator session saved securely. The desk will reopen with this connection next time.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage =
            'The workspace loaded, but the device session could not be saved.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingSession = false;
        });
      }
    }
  }

  Future<void> _clearPersistedSession() async {
    setState(() {
      _savingSession = true;
      _sessionMessage = null;
    });

    try {
      await widget.sessionStore.clear();
      if (!mounted) {
        return;
      }
      setState(() {
        _persistedSession = null;
        _selectedDestination = _OperatorDestination.home;
        _sessionMessage =
            'Saved operator session cleared from this device. Load a workspace again to create a new secure session.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage = 'The saved operator session could not be cleared.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingSession = false;
        });
      }
    }
  }

  void _openDesk(_OperatorDestination destination) {
    setState(() {
      _selectedDestination = destination;
    });
    unawaited(_rememberPreferredDesk(destination));
  }

  void _selectDestination(int index) {
    final destination = _destinationFromIndex(index);
    setState(() {
      _selectedDestination = destination;
    });
    unawaited(_rememberPreferredDesk(destination));
  }

  Future<void> _rememberPreferredDesk(_OperatorDestination destination) async {
    final current = _persistedSession;
    if (current == null) {
      return;
    }

    final updated = current.copyWith(preferredDeskIndex: destination.index);

    setState(() {
      _persistedSession = updated;
    });

    try {
      await widget.sessionStore.save(updated);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionMessage =
            'The desk changed, but the device could not remember that preference.';
      });
    }
  }

  _OperatorDestination _destinationFromIndex(int index) => switch (index) {
    1 => _OperatorDestination.notary,
    2 => _OperatorDestination.admin,
    3 => _OperatorDestination.notifications,
    4 => _OperatorDestination.session,
    _ => _OperatorDestination.home,
  };

  String _titleForDestination(_OperatorDestination destination) =>
      switch (destination) {
        _OperatorDestination.home => 'Operator Home',
        _OperatorDestination.notary => 'Notary Desk',
        _OperatorDestination.admin => 'Admin Desk',
        _OperatorDestination.notifications => 'Notifications',
        _OperatorDestination.session => 'Operator Session',
      };
}

class _OperatorHomePage extends StatelessWidget {
  const _OperatorHomePage({
    required this.session,
    required this.onOpenNotary,
    required this.onOpenAdmin,
    required this.onOpenSession,
  });

  final PersistedOperatorSession? session;
  final VoidCallback onOpenNotary;
  final VoidCallback onOpenAdmin;
  final VoidCallback onOpenSession;

  @override
  Widget build(BuildContext context) {
    final hasSession = session?.isComplete ?? false;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _ShellHeroCard(
          title: 'Operator Shell',
          subtitle:
              'Move between the notary and admin desks from one secure shell. A successfully loaded workspace is remembered on-device so the next operator session starts with context instead of re-entry.',
          actions: [
            FilledButton.icon(
              onPressed: onOpenNotary,
              icon: const Icon(Icons.gavel_outlined),
              label: const Text('Open Notary Desk'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenAdmin,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Open Admin Desk'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final cardWidth = wide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SummaryCard(
                  width: cardWidth,
                  title: 'Saved Connection',
                  lines: [
                    _summaryLine('API', session?.baseUrl ?? 'Not saved'),
                    _summaryLine(
                      'Transaction',
                      session?.transactionId ?? 'Not saved',
                    ),
                    _summaryLine(
                      'Token',
                      hasSession
                          ? _maskToken(session!.bearerToken)
                          : 'Not saved',
                    ),
                  ],
                  footer: hasSession
                      ? 'This device can reopen the last assisted-lane workspace without asking the operator to paste credentials again.'
                      : 'Load a workspace from the notary or admin desk and the connection will be stored securely for reuse.',
                ),
                _SummaryCard(
                  width: cardWidth,
                  title: 'Quick Actions',
                  lines: const [
                    'Notary desk: manage physical and office-based filing steps.',
                    'Admin desk: manage legal cases, freeze conditions, and oversight.',
                    'Notifications: review in-app delivery, unread items, and operator alerts.',
                    'Session view: review or clear the secure device session.',
                  ],
                  footer:
                      'The shell remembers the last desk used so teams can resume from the right workspace on relaunch.',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Get Started',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF163328),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  hasSession
                      ? 'Your secure device session is ready. Jump into either desk directly or review the saved session details.'
                      : 'No secure operator session is stored yet. Open a desk, load a workspace once, and the shell will remember it.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5C635B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: onOpenNotary,
                      icon: const Icon(Icons.assignment_outlined),
                      label: Text(
                        hasSession ? 'Resume Notary Desk' : 'Setup Notary Desk',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: onOpenAdmin,
                      icon: const Icon(Icons.policy_outlined),
                      label: Text(
                        hasSession ? 'Resume Admin Desk' : 'Setup Admin Desk',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenSession,
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('Review Session'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OperatorSessionPage extends StatelessWidget {
  const _OperatorSessionPage({
    required this.session,
    required this.onOpenNotary,
    required this.onOpenAdmin,
    required this.onClearSession,
  });

  final PersistedOperatorSession? session;
  final VoidCallback onOpenNotary;
  final VoidCallback onOpenAdmin;
  final VoidCallback onClearSession;

  @override
  Widget build(BuildContext context) {
    final hasSession = session?.isComplete ?? false;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Device Session',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF163328),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The base URL, bearer token, transaction ID, and preferred desk are stored on-device after a successful workspace load. Clearing this session removes that saved context.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF5C635B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _SessionRow(label: 'API base URL', value: session?.baseUrl),
                _SessionRow(
                  label: 'Transaction ID',
                  value: session?.transactionId,
                ),
                _SessionRow(
                  label: 'Bearer token',
                  value: hasSession ? _maskToken(session!.bearerToken) : null,
                ),
                _SessionRow(
                  label: 'Preferred desk',
                  value: switch (session?.preferredDeskIndex) {
                    1 => 'Notary Desk',
                    2 => 'Admin Desk',
                    3 => 'Notifications',
                    4 => 'Session',
                    _ => 'Home',
                  },
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: hasSession ? onOpenNotary : null,
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('Open Notary Desk'),
                    ),
                    OutlinedButton.icon(
                      onPressed: hasSession ? onOpenAdmin : null,
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: const Text('Open Admin Desk'),
                    ),
                    TextButton.icon(
                      onPressed: hasSession ? onClearSession : null,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear Saved Session'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _ShellHeroCard extends StatelessWidget {
  const _ShellHeroCard({
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF163328), Color(0xFF1E5A43), Color(0xFFB68A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 12, children: actions),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.title,
    required this.lines,
    required this.footer,
  });

  final double width;
  final String title;
  final List<String> lines;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF163328),
                ),
              ),
              const SizedBox(height: 14),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    line,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.35),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                footer,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5C635B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: const Color(0xFF5C635B)),
          ),
          const SizedBox(height: 4),
          Text(
            value?.trim().isNotEmpty == true ? value! : 'Not saved',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ShellBanner extends StatelessWidget {
  const _ShellBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFE7F0EA),
        border: Border.all(color: const Color(0xFFC9DCCF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF1E5A43)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: const Color(0xFF163328),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _summaryLine(String label, String value) => '$label: $value';

String _maskToken(String raw) {
  final trimmed = raw.trim();
  if (trimmed.length <= 10) {
    return 'Stored securely';
  }
  return '${trimmed.substring(0, 6)}...${trimmed.substring(trimmed.length - 4)}';
}
