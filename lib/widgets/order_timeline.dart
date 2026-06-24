import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key});

  static const steps = [
    _TimelineStep(
      title: 'Đã nhận đơn',
      subtitle: 'Cửa hàng đã xác nhận và chuẩn bị',
      time: '11:30',
    ),
    _TimelineStep(
      title: 'Đang pha chế',
      subtitle: 'Barista đang chuẩn bị thức uống của bạn',
      time: '11:35',
    ),
    _TimelineStep(
      title: 'Đang giao hàng',
      subtitle: 'Rider đang giao đơn đến địa chỉ của bạn',
      time: '11:45',
    ),
    _TimelineStep(
      title: 'Hoàn thành',
      subtitle: 'Thưởng thức ly cà phê thơm ngon tuyệt hảo',
      time: 'Dự kiến 12:05',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isDone = index < 3; // Step 0, 1, 2 are done
        final isActive = index == 2; // Step 2 is the active one
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gold-threaded line & Custom Checkmark State Nodes
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    // State Node
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone
                            ? (isActive ? AppColors.orange : AppColors.coffee)
                            : AppColors.background,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? AppColors.caramel : AppColors.border,
                          width: 2.0,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.orange.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          isDone
                              ? Icons.check_rounded
                              : Icons.radio_button_off_rounded,
                          color: isDone
                              ? Colors.white
                              : AppColors.textMuted.withValues(alpha: 0.5),
                          size: 14,
                        ),
                      ),
                    ),
                    // Connector Line (Gold-threaded)
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDone ? AppColors.caramel : AppColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Step text detail
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              color: isDone
                                  ? AppColors.textDark
                                  : AppColors.textMuted,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            step.time,
                            style: TextStyle(
                              color: isActive
                                  ? AppColors.orange
                                  : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          color: isDone
                              ? AppColors.textDark.withValues(alpha: 0.7)
                              : AppColors.textMuted.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final String title;
  final String subtitle;
  final String time;
}
