import 'package:flutter/material.dart';
import 'package:my_flutter_app/constants.dart'; // Add this import for kBackgroundColor

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
      content: "This brief instruction manual goes through the different features of the app and how to navigate our UI.",
      icon: Icons.waving_hand,
    ),
    TutorialStep(
      title: "Searching for a Ride Right Now",
      content: "1. Click the \"Go Online\" toggle\n2. Enter pick up address\n3. Enter drop-off address\n4. Click \"Find Ride Now\"\n5. Press \"Ready Now\" when ready",
      icon: Icons.search,
    ),
    TutorialStep(
      title: "Scheduling a ride in advance",
      content: "1. Press \"Schedule In Advance\"\n2. Enter desired date and time\n3. Enter pick up and drop off locations\n4. Click Schedule Ride",
      icon: Icons.calendar_today,
    ),
    TutorialStep(
      title: "Joining a Ride from the Marketplace",
      content: "1. Open the drop down menu\n2. Click \"Ride Marketplace\"\n3. Browse upcoming rides\n4. Join a ride by clicking \"Join Ride\"\n5. Use filters for refined search",
      icon: Icons.store,
    ),
    TutorialStep(
      title: "User Search and Adding Friends",
      content: "1. Open the drop down menu\n2. Click \"Search Users\"\n3. Enter username to search\n4. Click on a user to view profile\n5. Add friend, block, or report from profile",
      icon: Icons.person_add,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tutorial',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentPage > 0 ? () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ) : null,
                  child: const Text('Previous', style: TextStyle(color: Colors.black)),
                ),
                Text('${_currentPage + 1}/${_steps.length}', style: const TextStyle(color: Colors.black)),
                TextButton(
                  onPressed: _currentPage < _steps.length - 1 ? () => _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ) : null,
                  child: const Text('Next', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(TutorialStep step) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(step.icon, size: 80, color: Colors.black),
          const SizedBox(height: 24),
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            step.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String content;
  final IconData icon;

  TutorialStep({required this.title, required this.content, required this.icon});
}