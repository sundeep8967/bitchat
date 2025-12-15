import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'viewmodels/onboarding_viewmodel.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/chat_viewmodel.dart';
import 'viewmodels/room_viewmodel.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const BitChatApp());
}

class BitChatApp extends StatelessWidget {
  const BitChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OnboardingViewModel()),
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
        ChangeNotifierProvider(create: (_) => ChatViewModel()),
        ChangeNotifierProvider(create: (_) => RoomViewModel()),
      ],
      child: MaterialApp(
        title: 'BitChat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
      ),
    );
  }
}
