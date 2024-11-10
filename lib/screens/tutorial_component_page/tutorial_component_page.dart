import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart';

class TutorialComponent extends StatefulWidget {
  const TutorialComponent({Key? key}) : super(key: key);

  @override
  _TutorialComponentState createState() => _TutorialComponentState();
}

class _TutorialComponentState extends State<TutorialComponent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: "Welcome to Shuffl!",
      content: [
        "Discover and join rides with people from your club or organization.",
        "This guide will help you navigate our main features.",
      ],
      icon: CupertinoIcons.car_detailed,
    ),
    TutorialStep(
      title: "Profile Setup",
      content: [
        "Sign up and connect with your club or organization.",
        "Set your ride preferences to match with preferred riders.",
      ],
      icon: CupertinoIcons.person_crop_circle,
    ),
    TutorialStep(
      title: "Visibility Options",
      content: [
        "Choose who can see you online:",
        "• Everyone",
        "• Friends",
        "• Tags (Organizations)",
        "• Offline",
        "• Tags and Friends",
      ],
      icon: CupertinoIcons.eye,
    ),
    TutorialStep(
      title: "Finding a Ride",
      content: [
        "Schedule a ride in advance or find one instantly based on your preferences.",
        "Simply enter your pickup and drop-off locations to match with others heading in the same direction.",
      ],
      icon: CupertinoIcons.search,
    ),
    TutorialStep(
      title: "Ride Marketplace",
      content: [
        "Browse the marketplace to find and join rides.",
        "Use filters to refine your search and join a ride that suits you.",
      ],
      icon: CupertinoIcons.bag_fill,
    ),
    TutorialStep(
      title: "Riding with Friends",
      content: [
        "Connect with friends to ride together.",
        "Add friends and set your visibility to 'Friends' to appear online to them.",
        "You can also invite your friends from your contacts to ride together and earn special rewards! (Coming soon)",
      ],
      icon: CupertinoIcons.group_solid,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 350, // Increased width for better content fit
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBackgroundColor, // Set dialog background color
          borderRadius: BorderRadius.circular(20), // Rounded corners for a smooth look
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Makes the dialog compact
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            SizedBox(
              height: 300, // Adjusted height to prevent empty space
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: _steps.map((step) => _buildStepContent(step)).toList(),
              ),
            ),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Tutorial',
          style: CupertinoTheme.of(context)
              .textTheme
              .navTitleTextStyle
              ?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Set title text color to black
                decoration: TextDecoration.none, // Remove underline
              ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.clear_circled,
            color: CupertinoColors.systemGrey,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _currentPage > 0
              ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
              : null,
          child: Text(
            'Previous',
            style: TextStyle(
              color: _currentPage > 0
                  ? CupertinoTheme.of(context).primaryColor
                  : CupertinoColors.inactiveGray,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none, // Remove underline
            ),
          ),
        ),
        Row(
          children: List.generate(
            _steps.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? CupertinoTheme.of(context).primaryColor
                    : CupertinoColors.systemGrey,
              ),
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _currentPage < _steps.length - 1
              ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  )
              : () => Navigator.of(context).pop(),
          child: Text(
            _currentPage < _steps.length - 1 ? 'Next' : 'Finish',
            style: TextStyle(
              color: CupertinoTheme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none, // Remove underline
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(TutorialStep step) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Icon(
            step.icon,
            size: 60,
            color: CupertinoTheme.of(context).primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            step.title,
            style: CupertinoTheme.of(context)
                .textTheme
                .navTitleTextStyle
                ?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // Set title text color to black
                  decoration: TextDecoration.none, // Remove underline
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ...step.content.map(
            (point) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                point,
                style: TextStyle(
                  color: Colors.black, // Set content text color to black
                  fontSize: 16, // Ensures text is readable
                  decoration: TextDecoration.none, // Remove underline
                ),
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final List<String> content;
  final IconData icon;

  TutorialStep({
    required this.title,
    required this.content,
    required this.icon,
  });
}