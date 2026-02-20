import 'package:flutter/material.dart';
import '../../core/theme/juice_theme.dart';
import '../../core/utils/juice_engine.dart';
import '../../widgets/juice_button.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final List<QuizAnswer> _answers = [];

  final List<Map<String, dynamic>> _questions = [
    {
      'category': 'family',
      'question': 'Weekend plans: Family dinner or solo Netflix?',
      'options': [
        {'text': 'Family Dinner', 'score': 1.0},
        {'text': 'Solo Netflix', 'score': 0.0},
      ]
    },
    {
      'category': 'career',
      'question': '5yr goal: CEO track or work-life balance?',
      'options': [
        {'text': 'CEO Track', 'score': 1.0},
        {'text': 'Work-Life Balance', 'score': 0.0},
      ]
    },
    {
      'category': 'lifestyle',
      'question': 'Vacation: Adventure trip or beach resort?',
      'options': [
        {'text': 'Adventure Trip', 'score': 1.0},
        {'text': 'Beach Resort', 'score': 0.0},
      ]
    },
    {
      'category': 'ethics',
      'question': 'Dating: Exclusive immediately or see multiple?',
      'options': [
        {'text': 'Exclusive ASAP', 'score': 1.0},
        {'text': 'See Multiple', 'score': 0.0},
      ]
    },
    {
      'category': 'fun',
      'question': 'Date night: Dancing or deep conversations?',
      'options': [
        {'text': 'Dancing', 'score': 1.0},
        {'text': 'Deep Conversations', 'score': 0.0},
      ]
    },
    // Adding more to reach 12
    {
      'category': 'family',
      'question': 'Kids in the future: Absolutely or Not for me?',
      'options': [
        {'text': 'Absolutely', 'score': 1.0},
        {'text': 'Not for me', 'score': 0.0},
      ]
    },
    {
      'category': 'career',
      'question': 'Ambition: The most important thing or just a job?',
      'options': [
        {'text': 'Very Important', 'score': 1.0},
        {'text': 'Just a Job', 'score': 0.0},
      ]
    },
    {
      'category': 'lifestyle',
      'question': 'Morning person or night owl?',
      'options': [
        {'text': 'Morning Person', 'score': 1.0},
        {'text': 'Night Owl', 'score': 0.0},
      ]
    },
    {
      'category': 'ethics',
      'question': 'Honesty: Always or to avoid hurting?',
      'options': [
        {'text': 'Always', 'score': 1.0},
        {'text': 'Avoid Hurting', 'score': 0.0},
      ]
    },
    {
      'category': 'fun',
      'question': 'Cooking at home or ordering in?',
      'options': [
        {'text': 'Cooking', 'score': 1.0},
        {'text': 'Ordering In', 'score': 0.0},
      ]
    },
    {
      'category': 'lifestyle',
      'question': 'City life or Countryside?',
      'options': [
        {'text': 'City Life', 'score': 1.0},
        {'text': 'Countryside', 'score': 0.0},
      ]
    },
    {
      'category': 'family',
      'question': 'Living near parents: Yes or No?',
      'options': [
        {'text': 'Yes', 'score': 1.0},
        {'text': 'No', 'score': 0.0},
      ]
    },
  ];

  void _handleAnswer(double score) {
    _answers.add(QuizAnswer(
      category: _questions[_currentStep]['category'],
      score: score,
    ));

    if (_currentStep < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      // Completed - Navigate to Juice Summary
      Navigator.pushReplacementNamed(context, '/summary');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Juice Quiz (${_currentStep + 1}/${_questions.length})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _questions.length,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation(JuiceTheme.primaryTangerine),
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final q = _questions[index];
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  q['question'],
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ...q['options'].map<Widget>((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: JuiceButton(
                      onPressed: () => _handleAnswer(opt['score']),
                      text: opt['text'],
                      isGradient: false,
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
