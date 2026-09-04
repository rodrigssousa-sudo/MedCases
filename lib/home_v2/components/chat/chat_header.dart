// ============================================================================
// MEDCASES PRO
// HOME V2
// CHAT HEADER
// ============================================================================

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';

class ChatHeader extends StatelessWidget {
  final VoidCallback? onHistory;

  final VoidCallback? onNewChat;

  final VoidCallback? onOpenFull;

  const ChatHeader({
    super.key,
    this.onHistory,
    this.onNewChat,
    this.onOpenFull,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xffE8E8E8),
          ),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onOpenFull,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xffF3F4F6),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/home_v2/ic_ia.svg',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MEDCASES IA",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Auxílio clínico",
                      style: TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onHistory,
            icon: const Icon(Icons.history),
          ),
          IconButton(
            onPressed: onNewChat,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
