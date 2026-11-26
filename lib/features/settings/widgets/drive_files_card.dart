import 'package:flutter/material.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/auth/google_drive_client.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Every file the app reads from or saves to Google Drive, by folder.
class DriveFilesCard extends StatelessWidget {
  const DriveFilesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      tier: AppCardTier.flat,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Folder(DriveFolders.app),
          _DriveFileRow(
            icon: Icons.route_outlined,
            name: DriveFiles.timeline,
            access: 'read & saved',
            body:
                'Your timeline. Read on refresh, and saved back with what '
                'the phone recorded and your corrections.',
          ),
          _DriveFileRow(
            icon: Icons.sports_esports_outlined,
            name: '${DriveFiles.gameActivityPrefix}*.csv',
            access: 'read',
            body: 'Gaming sessions. The newest one is read.',
          ),
          _DriveFileRow(
            icon: Icons.backup_outlined,
            name: DriveFiles.backup,
            access: 'saved & restored',
            body: 'Settings and AI API keys (in plain text), from Back up now.',
          ),
          _DriveFileRow(
            icon: Icons.description_outlined,
            name: '${DriveFiles.dataExportPrefix}*.md',
            access: 'saved',
            body: 'One file per data export.',
          ),
          SizedBox(height: AppSpacing.md),
          _Folder(DriveFolders.cashew),
          _DriveFileRow(
            icon: Icons.account_balance_wallet_outlined,
            name: DriveFiles.cashewOutbox,
            access: 'read',
            body: 'Spending, synced there by the Cashew app.',
          ),
        ],
      ),
    );
  }
}

class _Folder extends StatelessWidget {
  const _Folder(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.folder_outlined, size: 18, color: context.palette.accent),
          const SizedBox(width: AppSpacing.sm),
          Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _DriveFileRow extends StatelessWidget {
  const _DriveFileRow({
    required this.icon,
    required this.name,
    required this.access,
    required this.body,
  });

  final IconData icon;
  final String name;
  final String body;

  /// Whether the app reads this file, saves it, or both.
  final String access;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · $access',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textMuted,
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
