import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:itonatalaga/pages/home_page.dart';

class Activity1Page extends StatefulWidget {
  const Activity1Page({super.key});

  @override
  State<Activity1Page> createState() => _Activity1PageState();
}

class _Activity1PageState extends State<Activity1Page> {
  late final AudioPlayer _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;

  bool _showList = false; // hide playlist by default

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlaylist();

    // Keep rebuilds snappy as playback changes
    _posSub = _player.positionStream.listen((_) => setState(() {}));
    _durSub = _player.durationStream.listen((_) => setState(() {}));
  }

  Future<void> _initPlaylist() async {
    final sources =
        _tracks.map((t) => AudioSource.asset(t.audioAsset, tag: t)).toList();
    await _player.setAudioSource(ConcatenatingAudioSource(children: sources));
    // Ensure there's a current index so the closed view has content
    if (_player.currentIndex == null) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _ensureStarted() async {
    if (_player.currentIndex == null) {
      await _player.seek(Duration.zero, index: 0);
    }
  }

  Future<void> _play() async {
    await _ensureStarted();
    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Prevent overly large text metrics from breaking layout
    final textScale = mq.textScaleFactor.clamp(1.0, 1.2);

    // Adaptive paddings
    final edgePad = mq.size.width < 420 ? 10.0 : 16.0;

    return MediaQuery(
      data: mq.copyWith(textScaleFactor: textScale),
      child: Scaffold(
        body: Container(
          // Very darkened background image
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/activity1.gif'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.30),
                BlendMode.darken,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onBack: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  },
                  onToggleList: () => setState(() => _showList = !_showList),
                  showList: _showList,
                  horizontalPad: edgePad,
                ),

                // Content with animated transition between CLOSED and OPEN views
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale:
                            Tween<double>(begin: 0.985, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _showList
                        ? _buildWithList(context, key: const ValueKey('open'))
                        : _buildSingleNowPlaying(context,
                            key: const ValueKey('closed')),
                  ),
                ),

                // Bottom controls: ONLY when playlist is OPEN
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _showList
                      ? _BottomPlayerBar(player: _player)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// CLOSED STATE: Show exactly ONE song (current), with its cover + title/artist + controls
  Widget _buildSingleNowPlaying(BuildContext context, {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        // Clamp max width so it looks good on phones & tablets
        final maxWidth = constraints.maxWidth.clamp(320, 640).toDouble();
        final sidePad = constraints.maxWidth < 420 ? 12.0 : 16.0;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(sidePad),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: StreamBuilder<SequenceState?>(
                stream: _player.sequenceStateStream,
                builder: (context, snap) {
                  final seq = snap.data;
                  final currentTag = (seq?.currentSource?.tag) as TrackMeta?;
                  final title = currentTag?.title ?? _tracks.first.title;
                  final artist = currentTag?.artist ?? _tracks.first.artist;
                  final cover =
                      currentTag?.coverAsset ?? _tracks.first.coverAsset;

                  // Larger tap targets on small screens
                  final isCompact = constraints.maxWidth < 420;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Now Playing (appears only when playing)
                      _NowPlayingBadge(player: _player),
                      const SizedBox(height: 10),

                      // Animated cover – fades/scales when track changes
                      AnimatedSwitcher(
  duration: const Duration(milliseconds: 220),
  switchInCurve: Curves.easeOutCubic,
  switchOutCurve: Curves.easeInCubic,
  transitionBuilder: (child, anim) => FadeTransition(
    opacity: anim,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
      child: child,
    ),
  ),
  child: _HoverScale(
    key: ValueKey(cover), // important: change key per track
    scale: 1.02,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        cover,
        fit: BoxFit.cover,
        width: MediaQuery.of(context).size.width < 500 ? 220 : 280,
        height: MediaQuery.of(context).size.width < 500 ? 220 : 280,
      ),
    ),
  ),
),
                      const SizedBox(height: 14),

                      // Animated title/artist
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Column(
                          key: ValueKey('$title-$artist'),
                          children: [
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              artist,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // >>> SLIM PROGRESS BAR (centered, not full width) <<<
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 360), // slim
                            child: _SlimProgressBar(player: _player),
                          ),
                        ),
                      ),

                      // Controls: Shuffle, Previous, Play/Pause, Next, Open List (icon only)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Shuffle
                          StreamBuilder<bool>(
                            stream: _player.shuffleModeEnabledStream,
                            builder: (context, snap) {
                              final on = snap.data ?? false;
                              return _HoverScale(
                                child: InkResponse(
                                  radius: isCompact ? 28 : 24,
                                  onTap: () =>
                                      _player.setShuffleModeEnabled(!on),
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  child: Icon(
                                    on ? Icons.shuffle_on : Icons.shuffle,
                                    color: Colors.white,
                                    size: isCompact ? 28 : 24,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Previous
                          _HoverScale(
                            child: IconButton(
                              tooltip: 'Previous',
                              icon: const Icon(Icons.skip_previous,
                                  color: Colors.white),
                              iconSize: isCompact ? 28 : 24,
                              onPressed: () async {
                                await _ensureStarted();
                                await _player.seekToPrevious();
                                await _player.play();
                              },
                            ),
                          ),
                          // Play / Pause
                          StreamBuilder<PlayerState>(
                            stream: _player.playerStateStream,
                            builder: (context, state) {
                              final playing = state.data?.playing ?? false;
                              return _HoverScale(
                                scale: 1.08,
                                child: IconButton(
                                  tooltip: playing ? 'Pause' : 'Play',
                                  iconSize: isCompact ? 56 : 48,
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      playing ? _player.pause() : _play(),
                                ),
                              );
                            },
                          ),
                          // Next
                          _HoverScale(
                            child: IconButton(
                              tooltip: 'Next',
                              icon: const Icon(Icons.skip_next,
                                  color: Colors.white),
                              iconSize: isCompact ? 28 : 24,
                              onPressed: () async {
                                await _ensureStarted();
                                await _player.seekToNext();
                                await _player.play();
                              },
                            ),
                          ),
                          // Open Playlist (icon only)
                          _HoverScale(
                            child: IconButton(
                              tooltip: 'Open Playlist',
                              icon: const Icon(Icons.queue_music,
                                  color: Colors.white),
                              iconSize: isCompact ? 28 : 24,
                              onPressed: () =>
                                  setState(() => _showList = true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// OPEN STATE: Full layout with left pane + detailed track list, Now Playing badge above list
  Widget _buildWithList(BuildContext context, {Key? key}) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final leftPaneWidth = isWide
            ? (constraints.maxWidth * 0.42).clamp(420, 560).toDouble()
            : constraints.maxWidth;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftPaneWidth,
                child: _LeftPane(player: _player),
              ),
              const VerticalDivider(color: Colors.white12, width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Now Playing badge above the list on wide screens
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: _NowPlayingBadgeStatic(),
                    ),
                    Expanded(
                      child: _TrackList(
                        player: _player,
                        currentIndexStream: _player.currentIndexStream,
                        onTap: (i) async {
                          await _player.seek(Duration.zero, index: i);
                          await _player.play();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeftPane(player: _player),
                const Divider(color: Colors.white12, height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: _NowPlayingBadgeStatic(),
                ),
                _TrackList(
                  player: _player,
                  currentIndexStream: _player.currentIndexStream,
                  shrinkForScroll: true,
                  onTap: (i) async {
                    await _player.seek(Duration.zero, index: i);
                    await _player.play();
                  },
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onToggleList;
  final bool showList;
  final double horizontalPad;
  const _TopBar({
    required this.onBack,
    required this.onToggleList,
    required this.showList,
    this.horizontalPad = 12,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompact = mq.size.width < 420;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPad, vertical: 6),
      child: Row(
        children: [
          _HoverScale(
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: 'Back to Home',
              iconSize: isCompact ? 24 : 28,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Back to Home   baka music player to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HoverScale(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 12,
                  vertical: isCompact ? 6 : 8,
                ),
              ),
              onPressed: onToggleList,
              icon: Icon(
                showList ? Icons.expand_less : Icons.queue_music,
                color: Colors.white,
                size: isCompact ? 18 : 22,
              ),
              label: Text(
                showList ? 'Hide Playlist' : 'Open Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeftPane extends StatelessWidget {
  final AudioPlayer player;
  const _LeftPane({required this.player});

  @override
  Widget build(BuildContext context) {
    // Visible only in OPEN state
    final mq = MediaQuery.of(context);
    final pad = mq.size.width < 420 ? 12.0 : 16.0;

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _CoverCollage(),
          SizedBox(height: 16),
          Text(
            'kalahati lng ng mga to yung napanood ko na skl',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CoverCollage extends StatelessWidget {
  const _CoverCollage();
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Stack(
        children: [
          GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: const [
              _CoverTile('assets/album-cover/28-days-later.jpg'),
              _CoverTile('assets/album-cover/fright-night.jpeg'),
              _CoverTile('assets/album-cover/return.jpg'),
              _CoverTile('assets/album-cover/shining.jpg'),
            ],
          ),
          const Positioned(
            left: 16,
            bottom: 16,
            child: Text(
              'matakot\nkayo please',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                height: 0.98,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  final String asset;
  const _CoverTile(this.asset);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
      child: Image.asset(asset, fit: BoxFit.cover),
    );
  }
}

class _TrackList extends StatelessWidget {
  final AudioPlayer player;
  final Stream<int?> currentIndexStream;
  final void Function(int) onTap;
  final bool shrinkForScroll;
  const _TrackList({
    required this.player,
    required this.currentIndexStream,
    required this.onTap,
    this.shrinkForScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompact = mq.size.width < 420;

    return StreamBuilder<int?>(
      stream: currentIndexStream,
      builder: (context, idxSnap) {
        final currentIndex = idxSnap.data ?? -1;

        final list = ListView.separated(
          shrinkWrap: shrinkForScroll,
          physics: shrinkForScroll ? const NeverScrollableScrollPhysics() : null,
          itemCount: _tracks.length,
          separatorBuilder: (_, __) =>
              const Divider(color: Colors.white12, height: 10),
          padding: EdgeInsets.symmetric(
              vertical: 8, horizontal: isCompact ? 6 : 8),
          itemBuilder: (context, index) {
            final t = _tracks[index];
            final selected = index == currentIndex;

            return _HoverListItem(
              selected: selected,
              onTap: () => onTap(index),
              builder: (hovering) => Row(
                children: [
                  // Album cover with hover scale
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedScale(
                      scale: hovering ? 1.04 : 1.0,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOut,
                      child: Image.asset(
                        t.coverAsset,
                        height: isCompact ? 46 : 52,
                        width: isCompact ? 46 : 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title / Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: hovering
                                ? (isCompact ? 18 : 19)
                                : (isCompact ? 17 : 18),
                            fontWeight: FontWeight.w700,
                            letterSpacing: hovering ? 0.2 : 0.0,
                          ),
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t.artist} • ${t.duration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );

        return list;
      },
    );
  }
}

class _HoverListItem extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget Function(bool hovering) builder;

  const _HoverListItem({
    Key? key,
    required this.selected,
    required this.onTap,
    required this.builder,
  }) : super(key: key);

  @override
  State<_HoverListItem> createState() => _HoverListItemState();
}

class _HoverListItemState extends State<_HoverListItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.selected
        ? Colors.white10
        : (_hover ? Colors.white.withOpacity(0.06) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent, // we handle hover bg ourselves
        splashColor: Colors.white10,
        highlightColor: Colors.white10.withOpacity(0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            offset: _hover ? const Offset(0, -0.01) : Offset.zero, // subtle lift
            child: widget.builder(_hover),
          ),
        ),
      ),
    );
  }
}

class _BottomPlayerBar extends StatelessWidget {
  final AudioPlayer player;
  const _BottomPlayerBar({required this.player});

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:${m.padLeft(2, '0')}:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isCompact = mq.size.width < 420;

    return Material(
      color: Colors.black.withOpacity(0.4), // slightly translucent over bg
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Music/progress bar
              StreamBuilder<Duration?>(
                stream: player.durationStream,
                builder: (context, durSnap) {
                  final duration = durSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, posSnap) {
                      final position = posSnap.data ?? Duration.zero;
                      final pos = position.inMilliseconds.clamp(
                        0,
                        duration.inMilliseconds == 0
                            ? 1
                            : duration.inMilliseconds,
                      );
                      return Row(
                        children: [
                          Text(
                            _mmss(Duration(milliseconds: pos)),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: isCompact ? 2.5 : 3.0,
                                thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius:
                                        isCompact ? 6 : 7.5),
                              ),
                              child: Slider(
                                value: duration.inMilliseconds == 0
                                    ? 0
                                    : pos / duration.inMilliseconds,
                                onChanged: (v) {
                                  final ms =
                                      (duration.inMilliseconds * v).toInt();
                                  player.seek(Duration(milliseconds: ms));
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.white24,
                              ),
                            ),
                          ),
                          Text(
                            _mmss(duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              // Now Playing + Title + Artist (centered), below the music bar
              const SizedBox(height: 6),
              _NowPlayingBadge(player: player),
              const SizedBox(height: 6),
              StreamBuilder<SequenceState?>(
                stream: player.sequenceStateStream,
                builder: (context, snap) {
                  final meta = (snap.data?.currentSource?.tag) as TrackMeta?;
                  final title = meta?.title ?? '';
                  final artist = meta?.artist ?? '';
                  if (title.isEmpty && artist.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),

              // Centered control buttons
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 0,
                children: [
                  _HoverScale(
                    child: StreamBuilder<bool>(
                      stream: player.shuffleModeEnabledStream,
                      builder: (context, snap) {
                        final on = snap.data ?? false;
                        return IconButton(
                          icon: Icon(
                            on ? Icons.shuffle_on : Icons.shuffle,
                            color: Colors.white70,
                            size: isCompact ? 22 : 24,
                          ),
                          onPressed: () => player.setShuffleModeEnabled(!on),
                          tooltip: 'Shuffle',
                        );
                      },
                    ),
                  ),
                  _HoverScale(
                    child: IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      iconSize: isCompact ? 22 : 24,
                      onPressed: () => player.seekToPrevious(),
                      tooltip: 'Previous',
                    ),
                  ),
                  _HoverScale(
                    child: IconButton(
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      iconSize: isCompact ? 22 : 24,
                      onPressed: () async {
                        final pos = await player.positionStream.first;
                        final target = pos - const Duration(seconds: 10);
                        player.seek(target.isNegative ? Duration.zero : target);
                      },
                      tooltip: 'Replay 10s',
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, state) {
                      final playing = state.data?.playing ?? false;
                      return _HoverScale(
                        scale: 1.08,
                        child: IconButton(
                          iconSize: isCompact ? 34 : 38,
                          icon: Icon(
                            playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                          ),
                          onPressed: () =>
                              playing ? player.pause() : player.play(),
                          tooltip: playing ? 'Pause' : 'Play',
                        ),
                      );
                    },
                  ),
                  _HoverScale(
                    child: IconButton(
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      iconSize: isCompact ? 22 : 24,
                      onPressed: () async {
                        final pos = await player.positionStream.first;
                        final dur = player.duration ?? Duration.zero;
                        final target = pos + const Duration(seconds: 10);
                        player.seek(target > dur ? dur : target);
                      },
                      tooltip: 'Forward 10s',
                    ),
                  ),
                  _HoverScale(
                    child: IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      iconSize: isCompact ? 22 : 24,
                      onPressed: () => player.seekToNext(),
                      tooltip: 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim, centered progress bar used in CLOSED view (above controls)
class _SlimProgressBar extends StatelessWidget {
  final AudioPlayer player;
  const _SlimProgressBar({required this.player});

  String _mmss(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      builder: (context, durSnap) {
        final duration = durSnap.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, posSnap) {
            final position = posSnap.data ?? Duration.zero;
            final posMs = position.inMilliseconds.clamp(
              0,
              duration.inMilliseconds == 0 ? 1 : duration.inMilliseconds,
            );
            final value = duration.inMilliseconds == 0
                ? 0.0
                : posMs / duration.inMilliseconds;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _mmss(Duration(milliseconds: posMs)),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                SizedBox(
                  width: 200, // slim fixed width
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2.0,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 5,
                      ),
                    ),
                    child: Slider(
                      value: value,
                      onChanged: (v) {
                        final ms = (duration.inMilliseconds * v).toInt();
                        player.seek(Duration(milliseconds: ms));
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ),
                Text(
                  _mmss(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Tiny pill that appears when a track is playing. No functionality; purely visual.
class _NowPlayingBadge extends StatelessWidget {
  final AudioPlayer player;
  const _NowPlayingBadge({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: playing
              ? const _NowPlayingBadgeStatic(key: ValueKey('np-on'))
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Static version so we can reuse badge in the list header (no stream needed there)
class _NowPlayingBadgeStatic extends StatelessWidget {
  const _NowPlayingBadgeStatic({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.graphic_eq, size: 16, color: Colors.white70),
          SizedBox(width: 6),
          Text(
            'Now Playing',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable hover scale wrapper for web/desktop polish.
class _HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const _HoverScale({required this.child, this.scale = 1.06, Key? key})
      : super(key: key);

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class TrackMeta {
  final String title;
  final String artist;
  final String duration;
  final String coverAsset;
  final String audioAsset;
  const TrackMeta(
      this.title, this.artist, this.duration, this.coverAsset, this.audioAsset);
}

final List<TrackMeta> _tracks = [
  TrackMeta(
      '28 Days Later Theme',
      'John Murphy',
      '3:06',
      'assets/album-cover/28-days-later.jpg',
      'assets/music/28-days-later-theme.mp3'),
  TrackMeta(
      'Cannibal Holocaust Theme',
      'Riz Ortolani',
      '2:51',
      'assets/album-cover/cannibal-holocaust.jpg',
      'assets/music/cannibal-holocaust-theme.mp3'),
  TrackMeta(
      'Fright Night Theme',
      'J. Geoffreys',
      '4:02',
      'assets/album-cover/fright-night.jpeg',
      'assets/music/fright-night-theme.mp3'),
  TrackMeta(
      'Halloween (Original Theme)',
      'John Carpenter',
      '4:12',
      'assets/album-cover/halloween.jpg',
      'assets/music/halloween-original-theme.mp3'),
  TrackMeta('Phantasm Theme', 'Fred Myrow', '2:58',
      'assets/album-cover/phantasm.jpg', 'assets/music/phantasm-theme.mp3'),
  TrackMeta(
      'Return of the Living Dead',
      'The Cramps',
      '3:46',
      'assets/album-cover/return.jpg',
      'assets/music/return-of-the-living-dead-theme.mp3'),
  TrackMeta(
      'Serbian Film Soundtrack',
      'Sky Wikluh',
      '3:37',
      'assets/album-cover/serbian.jpg',
      'assets/music/serbian-film-soundtrack.mp3'),
  TrackMeta(
      'The Exorcist (Tubular Bells)',
      'Mike Oldfield',
      '3:30',
      'assets/album-cover/exorcist.jpeg',
      'assets/music/the-exorcist-soundtrack.mp3'),
  TrackMeta(
      'The Shining Theme',
      'Wendy Carlos',
      '3:33',
      'assets/album-cover/shining.jpg',
      'assets/music/the-shining-theme.mp3'),
  TrackMeta(
      'The Thing Theme',
      'Ennio Morricone',
      '3:25',
      'assets/album-cover/thing.jpg',
      'assets/music/the-thing-theme.mp3'),
];
