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
      description: "Never miss a dose with smart reminders and personalized notifications",
      icon: Icons.medication,
    ),
    OnboardingPage(
      title: "Monitor Your Health",
      description: "Keep track of your medication schedule and health progress over time",
      icon: Icons.health_and_safety,
    ),
    OnboardingPage(
      title: "Get Started",
      description: "Let's set up your account and begin your health journey",
      icon: Icons.rocket_launch,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button - better positioned
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skipOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                  child: Text(
                    "Skip",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            
            // Page view with better spacing
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),
            
            // Page indicators - moved above buttons for better hierarchy
            Container(
              margin: EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == index 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ),
            ),
            
            // Bottom navigation - better spacing and alignment
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Back button with consistent sizing
                  SizedBox(
                    width: 80,
                    child: _currentPage > 0
                        ? TextButton(
                            onPressed: _previousPage,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[600],
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              "Back",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        : SizedBox(), // Empty space when back button is not shown
                  ),
                  
                  // Spacer to center the next/get started button
                  Expanded(child: SizedBox()),
                  
                  // Next/Get Started button - more prominent
                  ElevatedButton(
                    onPressed: _currentPage == _pages.length - 1 
                        ? _completeOnboarding 
                        : _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1 ? "Get Started" : "Next",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  
                  // Right spacer for balance
                  SizedBox(width: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with subtle background
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon, 
              size: 80, 
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 32),
          
          // Title with better typography
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          
          // Description with improved readability
          Container(
            constraints: BoxConstraints(maxWidth: 280),
            child: Text(
              page.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() => _pageController.nextPage(
    duration: Duration(milliseconds: 300), 
    curve: Curves.easeInOut,
  );
  
  void _previousPage() => _pageController.previousPage(
    duration: Duration(milliseconds: 300), 
    curve: Curves.easeInOut,
  );
  
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