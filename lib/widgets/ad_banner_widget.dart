import 'package:flutter/cupertino.dart';
import '../models/ad.dart';
import '../services/ad_service.dart';

class AdBannerWidget extends StatelessWidget {
  final Ad ad;
  final VoidCallback? onDismiss;
  final AdService _adService = AdService();

  AdBannerWidget({
    super.key,
    required this.ad,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Record impression when displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adService.recordImpression(ad.id);
    });

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          await _adService.recordClick(ad.id);
          if (ad.targetUrl != null) {
            // Handle navigation to merchant detail
            _showAdDetail(context);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Ad icon/logo
              if (ad.logoUrl != null)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ad.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(CupertinoIcons.building_2_fill),
                    ),
                  ),
                )
              else
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                  ),
                  child: const Icon(
                    CupertinoIcons.building_2_fill,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              const SizedBox(width: 12),
              // Ad content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5
                                .resolveFrom(context),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ad',
                            style: TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemGrey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ad.merchantName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ad.content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Dismiss button
              if (onDismiss != null)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: onDismiss,
                  child: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdDetail(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(ad.merchantName),
        message: Column(
          children: [
            if (ad.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ad.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            Text(ad.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),
            Text(ad.content),
            if (ad.merchantAddress != null) ...[
              const SizedBox(height: 8),
              Text('📍 ${ad.merchantAddress}'),
            ],
            if (ad.merchantPhone != null) ...[
              const SizedBox(height: 4),
              Text('📞 ${ad.merchantPhone}'),
            ],
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to location on map
            },
            child: const Text('View on Map'),
          ),
          if (ad.merchantPhone != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Call merchant
              },
              child: const Text('Call'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }
}





