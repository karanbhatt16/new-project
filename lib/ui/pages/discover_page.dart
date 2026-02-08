import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../../social/firestore_social_graph_controller.dart';
import '../../social/local_filter_preferences.dart';
import '../../social/local_swipe_store.dart';
import '../widgets/async_error_view.dart';
import '../widgets/skeleton_widgets.dart';
import 'swipe_deck.dart';
import 'match_requests_page.dart';
import 'user_profile_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.signedInUid,
    required this.signedInEmail,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final String signedInEmail;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Tab bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(4),
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Swipe'),
              Tab(text: 'Search'),
            ],
          ),
        ),
        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Swipe tab
              _SwipeDiscover(
                signedInUid: widget.signedInUid,
                auth: widget.auth,
                social: widget.social,
              ),
              // Search tab
              _SearchDiscover(
                signedInUid: widget.signedInUid,
                auth: widget.auth,
                social: widget.social,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Search and discover people tab with search bar and suggestions.
class _SearchDiscover extends StatefulWidget {
  const _SearchDiscover({
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<_SearchDiscover> createState() => _SearchDiscoverState();
}

class _SearchDiscoverState extends State<_SearchDiscover> {
  final TextEditingController _searchController = TextEditingController();
  final LocalFilterPreferences _filterPrefs = LocalFilterPreferences();
  String _searchQuery = '';
  
  // Interest filter
  final Set<String> _selectedInterests = {};
  bool _showInterestFilter = false;
  
  List<AppUser>? _allUsers;
  AppUser? _me;
  Set<String>? _friends;
  Map<String, List<String>>? _friendsOfFriends;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFilterPreferences();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Load saved filter preferences from local storage.
  Future<void> _loadFilterPreferences() async {
    final savedInterests = await _filterPrefs.loadSelectedInterests(widget.signedInUid);
    final savedVisible = await _filterPrefs.loadFilterVisible(widget.signedInUid);
    
    if (!mounted) return;
    
    setState(() {
      _selectedInterests.addAll(savedInterests);
      _showInterestFilter = savedVisible;
    });
  }

  /// Save current filter preferences to local storage.
  Future<void> _saveFilterPreferences() async {
    await _filterPrefs.saveSelectedInterests(widget.signedInUid, _selectedInterests);
    await _filterPrefs.saveFilterVisible(widget.signedInUid, _showInterestFilter);
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    try {
      if (!isRefresh) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final results = await Future.wait([
        widget.auth.publicProfileByUid(widget.signedInUid),
        widget.auth.getAllUsers(),
        widget.social.getFriends(uid: widget.signedInUid),
        widget.social.getFriendsOfFriends(uid: widget.signedInUid),
      ]);

      if (!mounted) return;

      setState(() {
        _me = results[0] as AppUser?;
        _allUsers = results[1] as List<AppUser>;
        _friends = results[2] as Set<String>;
        _friendsOfFriends = results[3] as Map<String, List<String>>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadData(isRefresh: true);
  }

  Widget _buildSearchSkeleton(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      children: [
        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Shimmer(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        // Section header skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Shimmer(
            child: Row(
              children: [
                SkeletonBox(width: 160, height: 18, borderRadius: 9),
              ],
            ),
          ),
        ),
        // User cards skeleton
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (context, index) => const UserCardSkeleton(),
          ),
        ),
      ],
    );
  }

  /// Get all unique interests from all users for the filter
  Set<String> _getAllInterests() {
    if (_allUsers == null) return {};
    
    final interests = <String>{};
    for (final user in _allUsers!) {
      for (final interest in user.interests) {
        final normalized = interest.trim();
        if (normalized.isNotEmpty) {
          interests.add(normalized);
        }
      }
    }
    return interests;
  }

  List<AppUser> _getSearchResults() {
    if (_allUsers == null) return [];
    
    final query = _searchQuery.toLowerCase().trim();
    if (query.isEmpty) return [];

    var results = _allUsers!
        .where((u) =>
            u.uid != widget.signedInUid &&
            (u.username.toLowerCase().contains(query) ||
             u.email.toLowerCase().contains(query)))
        .toList();

    // Apply interest filter if any selected
    if (_selectedInterests.isNotEmpty) {
      results = results.where((u) {
        final userInterests = u.interests
            .map((e) => e.trim().toLowerCase())
            .toSet();
        final selectedLower = _selectedInterests
            .map((e) => e.toLowerCase())
            .toSet();
        return userInterests.intersection(selectedLower).isNotEmpty;
      }).toList();
    }

    return results;
  }

  List<AppUser> _getPeopleYouMayKnow() {
    if (_allUsers == null || _friends == null || _friendsOfFriends == null || _me == null) {
      return [];
    }

    final myInterests = _me!.interests
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    // Get users who are friends of friends OR have similar interests
    final candidates = <AppUser>[];
    final addedUids = <String>{};

    for (final user in _allUsers!) {
      // Skip self and existing friends
      if (user.uid == widget.signedInUid || _friends!.contains(user.uid)) continue;
      
      final isFriendOfFriend = _friendsOfFriends!.containsKey(user.uid);
      
      // Check for similar interests
      final theirInterests = user.interests
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final mutualInterests = myInterests.intersection(theirInterests);
      final hasSimilarInterests = mutualInterests.isNotEmpty;

      // Apply interest filter if any selected
      if (_selectedInterests.isNotEmpty) {
        final selectedLower = _selectedInterests
            .map((e) => e.toLowerCase())
            .toSet();
        if (theirInterests.intersection(selectedLower).isEmpty) {
          continue;
        }
      }

      if (isFriendOfFriend || hasSimilarInterests || _selectedInterests.isNotEmpty) {
        if (!addedUids.contains(user.uid)) {
          candidates.add(user);
          addedUids.add(user.uid);
        }
      }
    }

    // Sort: friends of friends first, then by number of mutual interests
    candidates.sort((a, b) {
      final aFof = _friendsOfFriends!.containsKey(a.uid);
      final bFof = _friendsOfFriends!.containsKey(b.uid);
      
      if (aFof && !bFof) return -1;
      if (!aFof && bFof) return 1;

      // Count mutual interests
      final aInterests = a.interests.map((e) => e.trim().toLowerCase()).toSet();
      final bInterests = b.interests.map((e) => e.trim().toLowerCase()).toSet();
      final aMutual = myInterests.intersection(aInterests).length;
      final bMutual = myInterests.intersection(bInterests).length;

      return bMutual.compareTo(aMutual);
    });

    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildSearchSkeleton(theme);
    }

    if (_error != null) {
      return AsyncErrorView(error: _error!);
    }

    final searchResults = _getSearchResults();
    final peopleYouMayKnow = _getPeopleYouMayKnow();
    final showSearchResults = _searchQuery.isNotEmpty;
    final allInterests = _getAllInterests().toList()..sort();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by username or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  // Filter button
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _selectedInterests.isNotEmpty,
                      label: Text('${_selectedInterests.length}'),
                      child: Icon(
                        _showInterestFilter ? Icons.filter_list_off : Icons.filter_list,
                        color: _selectedInterests.isNotEmpty 
                            ? theme.colorScheme.primary 
                            : null,
                      ),
                    ),
                    onPressed: () {
                      setState(() => _showInterestFilter = !_showInterestFilter);
                      _saveFilterPreferences();
                    },
                    tooltip: 'Filter by interests',
                  ),
                ],
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        // Interest filter chips
        if (_showInterestFilter) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Filter by interests',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedInterests.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedInterests.clear());
                          _saveFilterPreferences();
                        },
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allInterests.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final interest = allInterests[index];
                      final isSelected = _selectedInterests.contains(interest);
                      
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedInterests.add(interest);
                            } else {
                              _selectedInterests.remove(interest);
                            }
                          });
                          _saveFilterPreferences();
                        },
                        selectedColor: theme.colorScheme.primaryContainer,
                        checkmarkColor: theme.colorScheme.onPrimaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // Results with pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: showSearchResults
                ? _buildSearchResults(searchResults, theme)
                : _buildPeopleYouMayKnow(peopleYouMayKnow, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(List<AppUser> results, ThemeData theme) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_searchQuery"',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) => _buildUserTile(results[index], theme),
    );
  }

  Widget _buildPeopleYouMayKnow(List<AppUser> people, ThemeData theme) {
    if (people.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No suggestions yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add friends to see suggestions',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: people.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'People You May Know',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }
        return _buildUserTile(people[index - 1], theme, showReason: true);
      },
    );
  }

  Widget _buildUserTile(AppUser user, ThemeData theme, {bool showReason = false}) {
    final isFriendOfFriend = _friendsOfFriends?.containsKey(user.uid) ?? false;
    final mutualFriends = _friendsOfFriends?[user.uid] ?? [];
    
    // Calculate mutual interests
    final myInterests = (_me?.interests ?? [])
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final theirInterests = user.interests
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final mutualInterests = myInterests.intersection(theirInterests);

    String? reason;
    if (showReason) {
      if (isFriendOfFriend && mutualFriends.isNotEmpty) {
        reason = '${mutualFriends.length} mutual friend${mutualFriends.length > 1 ? 's' : ''}';
      } else if (mutualInterests.isNotEmpty) {
        reason = '${mutualInterests.length} similar interest${mutualInterests.length > 1 ? 's' : ''}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserProfilePage(
                currentUserUid: widget.signedInUid,
                user: user,
                social: widget.social,
                auth: widget.auth,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundImage: user.profileImageBytes != null
                    ? MemoryImage(Uint8List.fromList(user.profileImageBytes!))
                    : null,
                child: user.profileImageBytes == null
                    ? Text(
                        user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (reason != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        user.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeDiscover extends StatefulWidget {
  const _SwipeDiscover({
    required this.signedInUid,
    required this.auth,
    required this.social,
  });

  final String signedInUid;
  final FirebaseAuthController auth;
  final FirestoreSocialGraphController social;

  @override
  State<_SwipeDiscover> createState() => _SwipeDiscoverState();
}

class _SwipeDiscoverState extends State<_SwipeDiscover> {
  final _localSwipes = LocalSwipeStore();
  final Set<String> _swipedUids = <String>{};

  @override
  void initState() {
    super.initState();
    // Load local exclusions so users don't reappear even if Firestore writes fail.
    _localSwipes.loadExcludedUids(widget.signedInUid).then((set) {
      if (!mounted) return;
      setState(() => _swipedUids.addAll(set));
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(AppUser?, List<AppUser>)>(
      future: () async {
        final me = await widget.auth.publicProfileByUid(widget.signedInUid);
        final all = await widget.auth.getAllUsers();
        return (me, all);
      }(),
      builder: (context, snap) {
        if (snap.hasError) {
          return AsyncErrorView(error: snap.error!);
        }
        if (!snap.hasData) {
          final theme = Theme.of(context);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding people for you...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }

        final me = snap.data!.$1;
        final all = snap.data!.$2;

        final myInterests = (me?.interests ?? const <String>[])
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();

        return StreamBuilder<Set<String>>(
          stream: widget.social.friendsStream(uid: widget.signedInUid),
          builder: (context, friendsSnap) {
            if (friendsSnap.hasError) {
              return AsyncErrorView(error: friendsSnap.error!);
            }
            if (!friendsSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends = friendsSnap.data!;

            bool oppositeGender(AppUser u) {
              // Enforce opposite gender only for male<->female. For other values,
              // we don't filter (since there isn't a single "opposite").
              final g = me?.gender;
              if (g == Gender.male) return u.gender == Gender.female;
              if (g == Gender.female) return u.gender == Gender.male;
              return true;
            }

            final candidates = all
                .where((u) =>
                    u.uid != widget.signedInUid &&
                    !friends.contains(u.uid) &&
                    !_swipedUids.contains(u.uid) &&
                    oppositeGender(u))
                .toList(growable: false);

            // Compute mutual interests.
            final mutualByUid = <String, List<String>>{};
            int mutualCount(AppUser u) {
              if (myInterests.isEmpty) return 0;
              final theirs = u.interests
                  .map((e) => e.trim().toLowerCase())
                  .where((e) => e.isNotEmpty)
                  .toSet();
              final mutual = myInterests.intersection(theirs).toList()..sort();

              // Keep nicer display capitalization (original strings) if possible.
              final display = <String>[];
              for (final m in mutual) {
                final original = u.interests.firstWhere(
                  (x) => x.trim().toLowerCase() == m,
                  orElse: () => m,
                );
                display.add(original);
              }
              mutualByUid[u.uid] = display;
              return mutual.length;
            }

            // Sort by mutual interest count (desc). Tie-break with randomness so the deck stays fresh.
            final rnd = Random();
            candidates.sort((a, b) {
              final am = mutualCount(a);
              final bm = mutualCount(b);
              if (am != bm) return bm.compareTo(am);
              return rnd.nextBool() ? 1 : -1;
            });

            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.surface,
                    theme.colorScheme.surfaceContainerLow,
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                    child: Row(
                      children: [
                        // Title with icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.pink, Colors.orange],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Discover',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${candidates.length} people nearby',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Match requests button
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            tooltip: 'Match requests',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MatchRequestsPage(
                                    currentUid: widget.signedInUid,
                                    auth: widget.auth,
                                    social: widget.social,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.favorite_border_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Swipe deck
                  Expanded(
                  child: SwipeDeck(
                    users: candidates,
                    mutualInterestsByUid: mutualByUid,
                    onViewProfile: (u) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(
                      currentUserUid: widget.signedInUid,
                      user: u,
                      social: widget.social,
                      auth: widget.auth,
                    ),
                  ),
                );
              },
                    onSwipe: (u, action) async {
                // Immediately mark as swiped so it doesn't re-appear on rebuild.
                if (mounted) {
                  setState(() => _swipedUids.add(u.uid));
                }

                // Fire and forget - don't block the swipe animation for network calls.
                // The card is already gone, so we just queue the request.
                if (action == SwipeAction.friend) {
                  widget.social.sendRequest(fromUid: widget.signedInUid, toUid: u.uid).catchError((e) {
                    debugPrint('Failed to send friend request: $e');
                  });
                } else if (action == SwipeAction.match) {
                  widget.social.sendMatchRequest(fromUid: widget.signedInUid, toUid: u.uid).catchError((e) {
                    debugPrint('Failed to send match request: $e');
                  });
                }

                // Persist locally (reliable) + best-effort Firestore write.
                await _localSwipes.addExcluded(widget.signedInUid, u.uid);

                // Fire and forget for swipe recording too
                widget.social.recordSwipe(
                  uid: widget.signedInUid,
                  otherUid: u.uid,
                  decision: switch (action) {
                    SwipeAction.match => SwipeDecision.match,
                    SwipeAction.friend => SwipeDecision.friend,
                    SwipeAction.skip => SwipeDecision.skip,
                  },
                ).catchError((_) {
                  // Ignore: local store already ensures it won't reappear.
                });
                    },
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
}

// Browse mode removed: app is now swipe-first (Tinder-style).
