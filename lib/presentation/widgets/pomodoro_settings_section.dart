import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/platform_utils.dart';
import '../../data/models/pomodoro_settings.dart';
import '../blocs/pomodoro/pomodoro_bloc.dart';
import '../blocs/pomodoro/pomodoro_event.dart';
import '../blocs/pomodoro/pomodoro_state.dart';
import 'app_switch_tile.dart';

class PomodoroSettingsSection extends StatelessWidget {
  const PomodoroSettingsSection({super.key});

  static const _workOptions = [15, 20, 25, 30, 35, 40, 45, 50, 60, 75, 90];
  static const _shortBreakOptions = [3, 5, 7, 10, 15];
  static const _longBreakOptions = [10, 15, 20, 25, 30, 45];
  static const _roundOptions = [2, 3, 4, 5, 6, 8];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PomodoroBloc, PomodoroState>(
      builder: (context, state) {
        final s = state.settings;
        final bloc = context.read<PomodoroBloc>();
        void update(PomodoroSettings next) => bloc.add(UpdatePomodoroSettings(next));
        final minutes = tr('settings.minutes_short');

        final settingsCard = Card(
          child: Column(
            children: [
              AppSwitchTile(
                secondary: const Text('🍅', style: TextStyle(fontSize: 20)),
                title: Text(tr('pomodoro.settings_show')),
                subtitle: Text(tr('pomodoro.settings_show_desc')),
                value: state.showOnTimeTracking,
                onChanged: (v) => bloc.add(TogglePomodoroVisibility(v)),
              ),
              if (PlatformUtils.isMobile && state.showOnTimeTracking) ...[
                const Divider(height: 1),
                AppSwitchTile(
                  secondary: const Icon(Icons.timelapse_outlined),
                  title: Text(tr('pomodoro.settings_mobile_tab')),
                  subtitle: Text(tr('pomodoro.settings_mobile_tab_desc')),
                  value: state.mobileTab,
                  onChanged: (v) => bloc.add(TogglePomodoroMobileTab(v)),
                ),
              ],
              const Divider(height: 1),
              _DropdownTile(
                icon: Icons.work_outline,
                title: tr('pomodoro.settings_work'),
                value: s.workMinutes,
                options: _workOptions,
                label: (v) => '$v $minutes',
                onChanged: (v) => update(s.copyWith(workMinutes: v)),
              ),
              const Divider(height: 1),
              _DropdownTile(
                icon: Icons.coffee_outlined,
                title: tr('pomodoro.settings_short_break'),
                value: s.shortBreakMinutes,
                options: _shortBreakOptions,
                label: (v) => '$v $minutes',
                onChanged: (v) => update(s.copyWith(shortBreakMinutes: v)),
              ),
              const Divider(height: 1),
              _DropdownTile(
                icon: Icons.weekend_outlined,
                title: tr('pomodoro.settings_long_break'),
                value: s.longBreakMinutes,
                options: _longBreakOptions,
                label: (v) => '$v $minutes',
                onChanged: (v) => update(s.copyWith(longBreakMinutes: v)),
              ),
              const Divider(height: 1),
              _DropdownTile(
                icon: Icons.repeat,
                title: tr('pomodoro.settings_rounds'),
                value: s.roundsBeforeLongBreak,
                options: _roundOptions,
                label: (v) => '$v',
                onChanged: (v) => update(s.copyWith(roundsBeforeLongBreak: v)),
              ),
              const Divider(height: 1),
              AppSwitchTile(
                secondary: const Icon(Icons.fast_forward_outlined),
                title: Text(tr('pomodoro.settings_auto_break')),
                value: s.autoStartBreak,
                onChanged: (v) => update(s.copyWith(autoStartBreak: v)),
              ),
              const Divider(height: 1),
              AppSwitchTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: Text(tr('pomodoro.settings_auto_work')),
                value: s.autoStartWork,
                onChanged: (v) => update(s.copyWith(autoStartWork: v)),
              ),
              const Divider(height: 1),
              AppSwitchTile(
                secondary: const Icon(Icons.timer_off_outlined),
                title: Text(tr('pomodoro.settings_warn_no_timer')),
                subtitle: Text(tr('pomodoro.settings_warn_no_timer_desc')),
                value: s.warnWhenNoTimer,
                onChanged: (v) => update(s.copyWith(warnWhenNoTimer: v)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('pomodoro.settings_next_phase_note'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            settingsCard,
            const SizedBox(height: 12),
            _SoundsCard(state: state),
          ],
        );
      },
    );
  }
}

class _SoundsCard extends StatelessWidget {
  final PomodoroState state;

  const _SoundsCard({required this.state});

  static const _warningOptions = [0, 1, 2, 3, 5];

  static String soundLabel(String id) => tr('pomodoro.sound_$id');

  @override
  Widget build(BuildContext context) {
    final s = state.settings;
    final bloc = context.read<PomodoroBloc>();
    void update(PomodoroSettings next) => bloc.add(UpdatePomodoroSettings(next));
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!state.notificationsPermitted && PlatformUtils.isMobile) ...[
            ListTile(
              leading: Icon(Icons.notifications_off_outlined, color: Theme.of(context).colorScheme.error),
              title: Text(tr('pomodoro.permission_denied')),
              subtitle: Text(tr('pomodoro.permission_denied_desc')),
              trailing: TextButton(
                onPressed: () {
                  if (Platform.isIOS) {
                    launchUrl(Uri.parse('app-settings:'));
                  } else {
                    bloc.add(const RequestPomodoroPermission());
                  }
                },
                child: Text(tr(Platform.isIOS ? 'pomodoro.permission_open_settings' : 'pomodoro.permission_allow')),
              ),
            ),
            const Divider(height: 1),
          ],
          AppSwitchTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(tr('pomodoro.settings_sounds_device')),
            subtitle: Text(tr('pomodoro.settings_device_only')),
            value: state.soundsOnDevice,
            onChanged: (v) => bloc.add(TogglePomodoroDeviceSounds(v)),
          ),
          const Divider(height: 1),
          AppSwitchTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(tr('pomodoro.settings_notifications_device')),
            subtitle: Text(tr('pomodoro.settings_device_only')),
            value: state.notificationsOnDevice,
            onChanged: (v) => bloc.add(TogglePomodoroDeviceNotifications(v)),
          ),
          const Divider(height: 1),
          _DropdownTile(
            icon: Icons.hourglass_bottom,
            title: tr('pomodoro.settings_warning'),
            value: s.warningMinutes,
            options: _warningOptions,
            label: (v) => v == 0 ? tr('pomodoro.settings_off') : '$v ${tr('settings.minutes_short')}',
            onChanged: (v) => update(s.copyWith(warningMinutes: v)),
          ),
          for (final event in PomodoroSoundEvent.values) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.music_note_outlined),
              title: Text(tr('pomodoro.sound_event_${event.name}')),
              subtitle: Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: s.soundFor(event),
                      underline: const SizedBox(),
                      items: [PomodoroSounds.none, ...PomodoroSounds.selectable].map((id) => DropdownMenuItem(value: id, child: Text(soundLabel(id)))).toList(),
                      onChanged: (id) {
                        if (id != null && id != s.soundFor(event)) update(s.withSound(event, id));
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: tr('pomodoro.sound_preview'),
                    onPressed: s.soundFor(event) == PomodoroSounds.none ? null : () => bloc.add(PreviewPomodoroSound(s.soundFor(event))),
                    icon: const Icon(Icons.play_arrow),
                  ),
                ],
              ),
            ),
          ],
          if (PlatformUtils.isDesktop) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.volume_down_outlined),
              title: Text(tr('pomodoro.settings_volume')),
              subtitle: Slider(
                value: s.volume,
                divisions: 10,
                label: '${(s.volume * 100).round()} %',
                onChanged: (v) => update(s.copyWith(volume: v)),
              ),
            ),
            const Divider(height: 1),
            AppSwitchTile(
              secondary: const Icon(Icons.av_timer),
              title: Text(tr('pomodoro.settings_ticking')),
              value: s.ticking,
              onChanged: (v) => update(s.copyWith(ticking: v)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              tr(PlatformUtils.isMobile ? 'pomodoro.settings_sounds_note_mobile' : 'pomodoro.settings_sounds_note'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int value;
  final List<int> options;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  const _DropdownTile({required this.icon, required this.title, required this.value, required this.options, required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final values = {...options, value}.toList()..sort();
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        items: values.map((v) => DropdownMenuItem(value: v, child: Text(label(v)))).toList(),
        onChanged: (v) {
          if (v != null && v != value) onChanged(v);
        },
      ),
    );
  }
}
