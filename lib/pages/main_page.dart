import 'package:fast_flow/pages/countdown_page.dart';
import 'package:fast_flow/pages/infaq.dart';
import 'package:fast_flow/pages/location_page.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    LocationPage(),
    CountdownPage(),
    InfaqPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.secondary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(255, 3, 62, 17).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color.fromARGB(0, 201, 196, 196),
          elevation: 0,
          selectedItemColor: colors.primary,
          unselectedItemColor: const Color.fromARGB(255, 246, 225, 181),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_sharp),
              label: 'Location',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timelapse_rounded),
              label: 'Countdown',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_rounded),
              label: 'Infaq',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
