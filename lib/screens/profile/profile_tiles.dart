import 'package:flutter/material.dart';
import '../../services/app_animations.dart';
import '../../services/app_ui_tokens.dart';

class ProfileSettingsCard extends StatelessWidget {
  const ProfileSettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        border: Border.all(color: AppUiTokens.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppUiTokens.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUiTokens.radiusLg),
        child: Column(children: children),
      ),
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vertical = compact ? AppUiTokens.space2 : AppUiTokens.space4;
    final iconSize = compact ? 22.0 : 30.0;
    return PressableScale(
      borderRadius: BorderRadius.circular(12),
      pressedScale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: vertical),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: compact ? 13 : 16, color: color),
            ),
            SizedBox(width: compact ? 8 : 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? AppUiTokens.textSm : AppUiTokens.textMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (!compact) const SizedBox(height: 1),
                  if (!compact)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppUiTokens.textXs,
                        color: AppUiTokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: compact ? 13 : 16, color: AppUiTokens.textHint),
          ],
        ),
      ),
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.compact,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 6 : 8),
      child: Row(
        children: [
          Container(
            width: compact ? 28 : 30,
            height: compact ? 28 : 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: compact ? 15 : 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: AppUiTokens.textSm, fontWeight: FontWeight.w700),
                ),
                if (!compact) const SizedBox(height: 1),
                if (!compact)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppUiTokens.textXs,
                      color: AppUiTokens.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSwitchTile extends StatelessWidget {
  const ProfileSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.compact,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity(horizontal: -2, vertical: compact ? -4 : -3),
      leading: Container(
        width: compact ? 28 : 30,
        height: compact ? 28 : 30,
        decoration: BoxDecoration(
          color: AppUiTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: compact ? 15 : 16, color: AppUiTokens.textDarkMuted),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: AppUiTokens.textSm, fontWeight: FontWeight.w700),
      ),
      subtitle: compact
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: AppUiTokens.textXs),
            ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppUiTokens.brandBlue,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? -1 : 0),
    );
  }
}

class ProfileDivider extends StatelessWidget {
  const ProfileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.8,
      color: AppUiTokens.borderUltraSoft,
      indent: 54,
      endIndent: 12,
    );
  }
}

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel({
    super.key,
    required this.label,
    this.caption,
    this.compact = false,
  });

  final String label;
  final String? caption;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(10, compact ? 6 : 11, 10, compact ? 4 : 8),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppUiTokens.textTertiary,
            ),
          ),
          if (caption != null && caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              style: TextStyle(
                fontSize: compact ? 9 : 10.5,
                fontWeight: FontWeight.w500,
                color: AppUiTokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ProfileSectionFooter extends StatelessWidget {
  const ProfileSectionFooter({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: child,
    );
  }
}

class ProfileAccentChip extends StatelessWidget {
  const ProfileAccentChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
