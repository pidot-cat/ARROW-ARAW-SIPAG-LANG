import 'package:flutter/material.dart';
import '../utils/constants.dart';

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  final bool showLogo;
  final bool showBackButton;

  const BackgroundWrapper({
    super.key,
    required this.child,
    this.showLogo = false,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(AppConstants.background),
          fit: BoxFit.cover,
          opacity: 0.3,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            child,
            if (showBackButton)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.02,
                left: MediaQuery.of(context).size.width * 0.04,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width * 0.02),
                    decoration: const BoxDecoration(
                      color: Colors.transparent, // Removed black background
                    ),
                    // ✅ FIXED: Replaced missing Image.asset with built-in Icon
                    child: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.06,
                    ),
                  ),
                ),
              ),
            if (showLogo)
              Positioned(
                top: MediaQuery.of(context).size.height * 0.025,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(AppConstants.logoWithBg,
                      height: MediaQuery.of(context).size.height * 0.1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
