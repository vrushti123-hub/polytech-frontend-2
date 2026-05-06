import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../utils/catalog_image_resolver.dart';

// ── Status Badge ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  const StatusBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = getStatusColor(label);
    final bg = getStatusBg(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Stock Indicator Dot ───────────────────────────────────────
class StockDot extends StatelessWidget {
  final bool available;
  const StockDot({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: available ? AppTheme.successGreen : AppTheme.dangerRed,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          available ? 'In Stock' : 'Produce',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: available ? AppTheme.successGreen : AppTheme.dangerRed,
          ),
        ),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Stat Card ─────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Order Card ────────────────────────────────────────────────
class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;
  final bool showActions;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel =
        order.status.name.substring(0, 1).toUpperCase() +
        order.status.name.substring(1);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.distributorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${order.distributorCity} • ${order.id}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: statusLabel),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  ...order.items.take(3).map(_itemThumb),
                  if (order.items.isNotEmpty) const SizedBox(width: 10),
                  _pill(Icons.inventory_2_outlined, '${order.totalPieces} pcs'),
                  const SizedBox(width: 10),
                  _pill(Icons.layers_outlined, '${order.items.length} items'),
                  const Spacer(),
                  if (order.hasStockShortage)
                    _pill(
                      Icons.warning_amber_rounded,
                      'Shortage',
                      isWarn: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemThumb(OrderItem item) {
    final imagePath = CatalogImageResolver.forOrderItem(item);
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? const Icon(
              Icons.inventory_2_outlined,
              size: 18,
              color: AppTheme.primaryBlue,
            )
          : Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: AppTheme.primaryBlue,
              ),
            ),
    );
  }

  Widget _pill(IconData icon, String label, {bool isWarn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWarn ? AppTheme.lightAmber : AppTheme.chipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
            color: isWarn ? AppTheme.warningAmber : AppTheme.primaryBlue,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isWarn ? AppTheme.warningAmber : AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Raw Material Row ──────────────────────────────────────────
class RawMaterialRow extends StatelessWidget {
  final RawMaterial material;
  const RawMaterialRow({super.key, required this.material});

  @override
  Widget build(BuildContext context) {
    final isLow = material.stockStatus != StockStatus.available;
    final isCritical = material.stockStatus == StockStatus.critical;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCritical
            ? AppTheme.lightRed
            : isLow
            ? AppTheme.lightAmber
            : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCritical
              ? AppTheme.dangerRed.withOpacity(0.3)
              : isLow
              ? AppTheme.warningAmber.withOpacity(0.3)
              : AppTheme.borderGrey,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      material.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (isLow)
                      Icon(
                        isCritical
                            ? Icons.error_rounded
                            : Icons.warning_rounded,
                        size: 14,
                        color: isCritical
                            ? AppTheme.dangerRed
                            : AppTheme.warningAmber,
                      ),
                  ],
                ),
                Text(
                  material.supplier,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${material.currentStockKg.toStringAsFixed(0)} kg',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isCritical
                      ? AppTheme.dangerRed
                      : isLow
                      ? AppTheme.warningAmber
                      : AppTheme.successGreen,
                ),
              ),
              Text(
                'Min: ${material.minimumStockKg.toStringAsFixed(0)} kg',
                style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 36,
              color: AppTheme.primaryBlue.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── App Dropdown ──────────────────────────────────────────────
class AppDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? label;

  const AppDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        DropdownButtonFormField<String>(
          initialValue: value,
          hint: Text(hint),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppTheme.primaryBlue,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppTheme.textSecondary,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}

// ── Form Field Wrapper ─────────────────────────────────────────
class FormFieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;

  const FormFieldWrapper({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── Notification Badge AppBar Action ─────────────────────────
class NotificationButton extends StatelessWidget {
  final int count;
  const NotificationButton({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
            size: 26,
          ),
          if (count > 0)
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppTheme.dangerRed,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
