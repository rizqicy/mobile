import 'package:auto_size_text/auto_size_text.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_preferences.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_providers.dart';
import 'package:lichess_mobile/src/model/broadcast/broadcast_round_controller.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_boards_tab.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_overview_tab.dart';
import 'package:lichess_mobile/src/view/broadcast/broadcast_players_tab.dart';
import 'package:lichess_mobile/src/widgets/adaptive_bottom_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/filter.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

enum BroadcastRoundTab { overview, boards, players }

enum _BroadcastGameFilter {
  all,
  ongoing;

  String l10n(AppLocalizations l10n) {
    switch (this) {
      case all:
        return l10n.mobileAllGames;
      case ongoing:
        // TODO: translate
        return 'Ongoing games';
    }
  }
}

class BroadcastRoundScreen extends ConsumerStatefulWidget {
  final Broadcast broadcast;
  final BroadcastRoundTab? initialTab;

  const BroadcastRoundScreen({required this.broadcast, this.initialTab});

  static Route<dynamic> buildRoute(
    BuildContext context,
    Broadcast broadcast, {
    BroadcastRoundTab? initialTab,
  }) {
    return buildScreenRoute(
      context,
      screen: BroadcastRoundScreen(broadcast: broadcast, initialTab: initialTab),
      title: broadcast.title,
    );
  }

  @override
  _BroadcastRoundScreenState createState() => _BroadcastRoundScreenState();
}

class _BroadcastRoundScreenState extends ConsumerState<BroadcastRoundScreen>
    with SingleTickerProviderStateMixin {
  BroadcastRoundTab selectedTab = BroadcastRoundTab.overview;
  late final TabController _tabController;
  late BroadcastTournamentId _selectedTournamentId;
  BroadcastRoundId? _selectedRoundId;

  bool roundLoaded = false;

  _BroadcastGameFilter filter = _BroadcastGameFilter.all;

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab ?? BroadcastRoundTab.overview;
    _tabController = TabController(
      initialIndex: widget.initialTab?.index ?? 0,
      length: 3,
      vsync: this,
    );
    _selectedTournamentId = widget.broadcast.tour.id;
    _selectedRoundId = widget.broadcast.roundToLinkId;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void setCupertinoTab(BroadcastRoundTab mode) {
    setState(() {
      selectedTab = mode;
    });
  }

  void setTournamentId(BroadcastTournamentId tournamentId) {
    setState(() {
      _selectedTournamentId = tournamentId;
      _selectedRoundId = null;
    });
  }

  void setRoundId(BroadcastRoundId roundId) {
    setState(() {
      roundLoaded = false;
      _selectedRoundId = roundId;
    });
  }

  Widget _filterButtonBuilder(BuildContext context) => AppBarIconButton(
    icon: const Icon(Icons.filter_list),
    semanticsLabel: context.l10n.filterGames,
    onPressed:
        () => showAdaptiveBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height * 0.4),
          builder:
              (_) => StatefulBuilder(
                builder: (context, setLocalState) {
                  return BottomSheetScrollableContainer(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      const SizedBox(height: 16.0),
                      Filter<_BroadcastGameFilter>(
                        filterType: FilterType.singleChoice,
                        choices: _BroadcastGameFilter.values,
                        choiceSelected: (choice) => filter == choice,
                        choiceLabel: (category) => Text(category.l10n(context.l10n)),
                        onSelected: (value, selected) {
                          setLocalState(() => filter = value);
                          setState(() => filter = value);
                        },
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  );
                },
              ),
        ),
  );

  Widget _iosBuilder(
    BuildContext context,
    AsyncValue<BroadcastTournament> asyncTournament,
    AsyncValue<BroadcastRoundState> asyncRound,
  ) {
    final tabSwitcher = CupertinoSlidingSegmentedControl<BroadcastRoundTab>(
      groupValue: selectedTab,
      children: {
        BroadcastRoundTab.overview: Text(context.l10n.broadcastOverview),
        BroadcastRoundTab.boards: Text(context.l10n.broadcastBoards),
        BroadcastRoundTab.players: Text(context.l10n.players),
      },
      onValueChanged: (BroadcastRoundTab? view) {
        if (view != null) {
          setCupertinoTab(view);
        }
      },
    );
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: AutoSizeText(
          widget.broadcast.title,
          minFontSize: 14.0,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_filterButtonBuilder(context), const _BroadcastSettingsButton()],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: switch (asyncRound) {
              AsyncData(value: final _) => switch (selectedTab) {
                BroadcastRoundTab.overview => _TabView(
                  cupertinoTabSwitcher: tabSwitcher,
                  sliver: BroadcastOverviewTab(
                    broadcast: widget.broadcast,
                    tournamentId: _selectedTournamentId,
                  ),
                ),
                BroadcastRoundTab.boards => _TabView(
                  cupertinoTabSwitcher: tabSwitcher,
                  sliver: switch (asyncTournament) {
                    AsyncData(:final value) => BroadcastBoardsTab(
                      tournamentId: _selectedTournamentId,
                      roundId: _selectedRoundId ?? value.defaultRoundId,
                      tournamentSlug: widget.broadcast.tour.slug,
                      showOnlyOngoingGames: filter == _BroadcastGameFilter.ongoing,
                    ),
                    _ => const SliverFillRemaining(child: SizedBox.shrink()),
                  },
                ),
                BroadcastRoundTab.players => _TabView(
                  cupertinoTabSwitcher: tabSwitcher,
                  sliver: BroadcastPlayersTab(tournamentId: _selectedTournamentId),
                ),
              },
              _ => const Center(child: CircularProgressIndicator.adaptive()),
            },
          ),
          switch (asyncTournament) {
            AsyncData(:final value) => _BottomBar(
              tournament: value,
              roundId: _selectedRoundId ?? value.defaultRoundId,
              setTournamentId: setTournamentId,
              setRoundId: setRoundId,
            ),
            _ => const PlatformBottomBar.empty(transparentBackground: false),
          },
        ],
      ),
    );
  }

  Widget _androidBuilder(
    BuildContext context,
    AsyncValue<BroadcastTournament> asyncTournament,
    AsyncValue<BroadcastRoundState> asyncRound,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: AutoSizeText(
          widget.broadcast.title,
          minFontSize: 14.0,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(text: context.l10n.broadcastOverview),
            Tab(text: context.l10n.broadcastBoards),
            Tab(text: context.l10n.players),
          ],
        ),
        actions: [_filterButtonBuilder(context), const _BroadcastSettingsButton()],
      ),
      body: switch (asyncRound) {
        AsyncData(value: final _) => TabBarView(
          controller: _tabController,
          children: <Widget>[
            _TabView(
              sliver: BroadcastOverviewTab(
                broadcast: widget.broadcast,
                tournamentId: _selectedTournamentId,
              ),
            ),
            _TabView(
              sliver: switch (asyncTournament) {
                AsyncData(:final value) => BroadcastBoardsTab(
                  tournamentId: _selectedTournamentId,
                  roundId: _selectedRoundId ?? value.defaultRoundId,
                  tournamentSlug: widget.broadcast.tour.slug,
                  showOnlyOngoingGames: filter == _BroadcastGameFilter.ongoing,
                ),
                _ => const SliverFillRemaining(child: SizedBox.shrink()),
              },
            ),
            _TabView(sliver: BroadcastPlayersTab(tournamentId: _selectedTournamentId)),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: switch (asyncTournament) {
        AsyncData(:final value) => _BottomBar(
          tournament: value,
          roundId: _selectedRoundId ?? value.defaultRoundId,
          setTournamentId: setTournamentId,
          setRoundId: setRoundId,
        ),
        _ => const PlatformBottomBar.empty(transparentBackground: false),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncTour = ref.watch(broadcastTournamentProvider(_selectedTournamentId));

    const loadingRound = AsyncValue<BroadcastRoundState>.loading();

    switch (asyncTour) {
      case AsyncData(value: final tournament):
        // Eagerly initalize the round controller so it stays alive when switching tabs
        // and to know if the round has games to show
        final roundState = ref.watch(
          broadcastRoundControllerProvider(_selectedRoundId ?? tournament.defaultRoundId),
        );

        ref.listen(
          broadcastRoundControllerProvider(_selectedRoundId ?? tournament.defaultRoundId),
          (_, round) {
            if (widget.initialTab == null && round.hasValue && !roundLoaded) {
              roundLoaded = true;
              if (round.value!.games.isNotEmpty) {
                _tabController.index = 1;

                if (Theme.of(context).platform == TargetPlatform.iOS) {
                  setCupertinoTab(BroadcastRoundTab.boards);
                }
              }
            }
          },
        );

        return PlatformWidget(
          androidBuilder: (context) => _androidBuilder(context, asyncTour, roundState),
          iosBuilder: (context) => _iosBuilder(context, asyncTour, roundState),
        );

      case _:
        return PlatformWidget(
          androidBuilder: (context) => _androidBuilder(context, asyncTour, loadingRound),
          iosBuilder: (context) => _iosBuilder(context, asyncTour, loadingRound),
        );
    }
  }
}

class _TabView extends StatelessWidget {
  const _TabView({required this.sliver, this.cupertinoTabSwitcher});

  final Widget sliver;
  final Widget? cupertinoTabSwitcher;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (cupertinoTabSwitcher != null)
          SliverPadding(
            padding: Styles.bodyPadding + EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
            sliver: SliverToBoxAdapter(child: cupertinoTabSwitcher),
          ),
        sliver,
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.tournament,
    required this.roundId,
    required this.setTournamentId,
    required this.setRoundId,
  });

  final BroadcastTournament tournament;
  final BroadcastRoundId roundId;
  final void Function(BroadcastTournamentId) setTournamentId;
  final void Function(BroadcastRoundId) setRoundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlatformBottomBar(
      transparentBackground: false,
      children: [
        if (tournament.group != null)
          AdaptiveTextButton(
            onPressed:
                () => showAdaptiveBottomSheet<void>(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  isDismissible: true,
                  builder:
                      (_) => DraggableScrollableSheet(
                        initialChildSize: 0.4,
                        maxChildSize: 0.4,
                        minChildSize: 0.1,
                        snap: true,
                        expand: false,
                        builder: (context, scrollController) {
                          return _TournamentSelectorMenu(
                            tournament: tournament,
                            group: tournament.group!,
                            scrollController: scrollController,
                            setTournamentId: setTournamentId,
                          );
                        },
                      ),
                ),
            child: Text(
              tournament.group!.firstWhere((g) => g.id == tournament.data.id).name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        AdaptiveTextButton(
          onPressed:
              () => showAdaptiveBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                isDismissible: true,
                builder:
                    (_) => DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      maxChildSize: 0.6,
                      snap: true,
                      expand: false,
                      builder: (context, scrollController) {
                        return _RoundSelectorMenu(
                          selectedRoundId: roundId,
                          rounds: tournament.rounds,
                          scrollController: scrollController,
                          setRoundId: setRoundId,
                        );
                      },
                    ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  tournament.rounds.firstWhere((round) => round.id == roundId).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5.0),
              switch (tournament.rounds.firstWhere((round) => round.id == roundId).status) {
                RoundStatus.finished => Icon(Icons.check, color: context.lichessColors.good),
                RoundStatus.live => Icon(Icons.circle, color: context.lichessColors.error),
                RoundStatus.upcoming => const Icon(Icons.calendar_month, color: Colors.grey),
              },
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundSelectorMenu extends ConsumerStatefulWidget {
  const _RoundSelectorMenu({
    required this.selectedRoundId,
    required this.rounds,
    required this.scrollController,
    required this.setRoundId,
  });

  final BroadcastRoundId selectedRoundId;
  final IList<BroadcastRound> rounds;
  final ScrollController scrollController;
  final void Function(BroadcastRoundId) setRoundId;

  @override
  ConsumerState<_RoundSelectorMenu> createState() => _RoundSelectorState();
}

final _dateFormatMonth = DateFormat.MMMd().add_jm();
final _dateFormatYearMonth = DateFormat.yMMMd().add_jm();

class _RoundSelectorState extends ConsumerState<_RoundSelectorMenu> {
  final currentRoundKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Scroll to the current round
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentRoundKey.currentContext != null) {
        Scrollable.ensureVisible(currentRoundKey.currentContext!, alignment: 0.5);
      }
    });

    return BottomSheetScrollableContainer(
      scrollController: widget.scrollController,
      children: [
        for (final (index, round) in widget.rounds.indexed)
          PlatformListTile(
            key: round.id == widget.selectedRoundId ? currentRoundKey : null,
            selected: round.id == widget.selectedRoundId,
            title: Text(round.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (round.startsAt != null || round.startsAfterPrevious) ...[
                  Text(
                    round.startsAt != null
                        ? round.startsAt!.difference(DateTime.now()).inDays.abs() < 30
                            ? _dateFormatMonth.format(round.startsAt!)
                            : _dateFormatYearMonth.format(round.startsAt!)
                        : context.l10n.broadcastStartsAfter(widget.rounds[index - 1].name),
                  ),
                  const SizedBox(width: 5.0),
                ],
                switch (round.status) {
                  RoundStatus.finished => Icon(Icons.check, color: context.lichessColors.good),
                  RoundStatus.live => Icon(Icons.circle, color: context.lichessColors.error),
                  RoundStatus.upcoming => const Icon(Icons.calendar_month, color: Colors.grey),
                },
              ],
            ),
            onTap: () {
              widget.setRoundId(round.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _TournamentSelectorMenu extends ConsumerStatefulWidget {
  const _TournamentSelectorMenu({
    required this.tournament,
    required this.group,
    required this.scrollController,
    required this.setTournamentId,
  });

  final BroadcastTournament tournament;
  final IList<BroadcastTournamentGroup> group;
  final ScrollController scrollController;
  final void Function(BroadcastTournamentId) setTournamentId;

  @override
  ConsumerState<_TournamentSelectorMenu> createState() => _TournamentSelectorState();
}

class _TournamentSelectorState extends ConsumerState<_TournamentSelectorMenu> {
  final currentTournamentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Scroll to the current tournament
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentTournamentKey.currentContext != null) {
        Scrollable.ensureVisible(currentTournamentKey.currentContext!, alignment: 0.5);
      }
    });

    return BottomSheetScrollableContainer(
      scrollController: widget.scrollController,
      children: [
        for (final tournament in widget.group)
          PlatformListTile(
            key: tournament.id == widget.tournament.data.id ? currentTournamentKey : null,
            selected: tournament.id == widget.tournament.data.id,
            title: Text(tournament.name),
            onTap: () {
              widget.setTournamentId(tournament.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }
}

class _BroadcastSettingsButton extends StatelessWidget {
  const _BroadcastSettingsButton();

  @override
  Widget build(BuildContext context) => AppBarIconButton(
    icon: const Icon(Icons.settings),
    onPressed:
        () => showAdaptiveBottomSheet<void>(
          context: context,
          isDismissible: true,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => const _BroadcastSettingsBottomSheet(),
        ),
    semanticsLabel: context.l10n.settingsSettings,
  );
}

class _BroadcastSettingsBottomSheet extends ConsumerWidget {
  const _BroadcastSettingsBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcastPreferences = ref.watch(broadcastPreferencesProvider);

    return DraggableScrollableSheet(
      initialChildSize: .6,
      expand: false,
      builder:
          (context, scrollController) => ListView(
            controller: scrollController,
            children: [
              SwitchSettingTile(
                title: Text(context.l10n.evaluationGauge),
                value: broadcastPreferences.showEvaluationBar,
                onChanged: (value) {
                  ref.read(broadcastPreferencesProvider.notifier).toggleEvaluationBar();
                },
              ),
            ],
          ),
    );
  }
}
