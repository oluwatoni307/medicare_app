import 'package:flutter/material.dart';

import '../app_state_manager.dart';

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: "Track Your Medications",
      description: "Never miss a dose with smart reminders",
      icon: Icons.medication,
    ),
    OnboardingPage(
      title: "Monitor Your Health",
      description: "Keep track of your medication schedule",
      icon: Icons.health_and_safety,
    ),
    OnboardingPage(
      title: "Get Started",
      description: "Let's set up your account",
      icon: Icons.rocket_launch,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skipOnboarding,
                child: Text("Skip"),
              ),
            ),
            
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            
            // Bottom navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  child: Text("Back"),
                ),
                
                // Page indicators
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                ),
                
                ElevatedButton(
                  onPressed: _currentPage == _pages.length - 1 ? _completeOnboarding : _nextPage,
                  child: Text(_currentPage == _pages.length - 1 ? "Get Started" : "Next"),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(page.icon, size: 120, color: Colors.blue),
          SizedBox(height: 40),
          Text(page.title, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Text(page.description, textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  void _nextPage() => _pageController.nextPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
  void _previousPage() => _pageController.previousPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
  
  void _skipOnboarding() => _completeOnboarding();
  
  void _completeOnboarding() async {
    await AppStateManager.markOnboardingComplete();
    Navigator.pushReplacementNamed(context, '/auth');
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  
  OnboardingPage({required this.title, required this.description, required this.icon});
}