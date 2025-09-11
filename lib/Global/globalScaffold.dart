// import 'package:flutter/material.dart';

// class GlobalScaffold extends StatefulWidget {
//   const GlobalScaffold({Key? key}) : super(key: key);

//   @override
//   State<GlobalScaffold> createState() => _GlobalScaffoldState();
// }

// class _GlobalScaffoldState extends State<GlobalScaffold> {
//   int _selectedIndex = 0;
//   bool _isSidebarExpanded = true;
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

//   @override
//   Widget build(BuildContext context) {
//     final size = MediaQuery.of(context).size;
//     final isMobile = size.width < 600;
//     final isTablet = size.width < 900 && size.width >= 600;

//     return Scaffold(
//       key: _scaffoldKey,
//       // AppBar with beautiful design
//       appBar: AppBar(
//         title: const Text('Beautiful Scaffold'),
//         centerTitle: true,
//         elevation: 0,
//         leading: isMobile
//             ? IconButton(
//                 icon: const Icon(Icons.menu),
//                 onPressed: () => _scaffoldKey.currentState?.openDrawer(),
//               )
//             : IconButton(
//                 icon: Icon(_isSidebarExpanded ? Icons.menu_open : Icons.menu),
//                 onPressed: () {
//                   setState(() {
//                     _isSidebarExpanded = !_isSidebarExpanded;
//                   });
//                 },
//               ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.search),
//             onPressed: () {},
//           ),
//           IconButton(
//             icon: const Icon(Icons.notifications_outlined),
//             onPressed: () {},
//           ),
//           const SizedBox(width: 10),
//           const CircleAvatar(
//             radius: 16,
//             backgroundImage: NetworkImage('https://via.placeholder.com/150'),
//           ),
//           const SizedBox(width: 16),
//         ],
//       ),

//       // Responsive drawer for mobile
//       drawer: isMobile ? _buildSidebar(true) : null,

//       // Body with responsive layout
//       body: Row(
//         children: [
//           // Show sidebar for tablet and desktop
//           if (!isMobile) _buildSidebar(_isSidebarExpanded),

//           // Main content area
//           Expanded(
//             child: Container(
//               margin: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildPageTitle(),
//                   const SizedBox(height: 16),
//                   _buildContent(),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),

//       // Floating action button with extended animation
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {},
//         label: const Text('New Item'),
//         icon: const Icon(Icons.add),
//         elevation: 2,
//       ),

//       // Bottom navigation for mobile and tablet
//       bottomNavigationBar: isMobile || isTablet
//           ? BottomNavigationBar(
//               currentIndex: _selectedIndex,
//               onTap: (index) {
//                 setState(() {
//                   _selectedIndex = index;
//                 });
//               },
//               selectedItemColor: Theme.of(context).colorScheme.primary,
//               unselectedItemColor: Colors.grey,
//               type: BottomNavigationBarType.fixed,
//               items: const [
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.dashboard_outlined),
//                   activeIcon: Icon(Icons.dashboard),
//                   label: 'Dashboard',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.analytics_outlined),
//                   activeIcon: Icon(Icons.analytics),
//                   label: 'Analytics',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.message_outlined),
//                   activeIcon: Icon(Icons.message),
//                   label: 'Messages',
//                 ),
//                 BottomNavigationBarItem(
//                   icon: Icon(Icons.settings_outlined),
//                   activeIcon: Icon(Icons.settings),
//                   label: 'Settings',
//                 ),
//               ],
//             )
//           : null,
//     );
//   }

//   // Sidebar with beautiful animation and design
//   Widget _buildSidebar(bool isExpanded) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 200),
//       width: isExpanded ? 250 : 70,
//       color: Theme.of(context).colorScheme.surface,
//       padding: const EdgeInsets.symmetric(vertical: 16),
//       child: Column(
//         children: [
//           // Logo and brand
//           if (isExpanded)
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 children: [
//                   Icon(
//                     Icons.bubble_chart,
//                     size: 32,
//                     color: Theme.of(context).colorScheme.primary,
//                   ),
//                   const SizedBox(width: 16),
//                   Text(
//                     'Awesome UI',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Theme.of(context).colorScheme.primary,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Icon(
//                 Icons.bubble_chart,
//                 size: 32,
//                 color: Theme.of(context).colorScheme.primary,
//               ),
//             ),

//           const SizedBox(height: 24),

//           // Navigation items
//           _buildNavItem(Icons.dashboard_outlined, 'Dashboard', 0, isExpanded),
//           _buildNavItem(Icons.analytics_outlined, 'Analytics', 1, isExpanded),
//           _buildNavItem(Icons.message_outlined, 'Messages', 2, isExpanded),
//           _buildNavItem(Icons.people_outlined, 'Users', 3, isExpanded),

//           const Divider(height: 32),

//           _buildNavItem(Icons.settings_outlined, 'Settings', 4, isExpanded),
//           _buildNavItem(Icons.help_outline, 'Help', 5, isExpanded),

//           const Spacer(),

//           // User profile at bottom
//           Container(
//             margin: const EdgeInsets.all(16),
//             padding: const EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Theme.of(context)
//                   .colorScheme
//                   .primaryContainer
//                   .withOpacity(0.3),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: isExpanded
//                 ? Row(
//                     children: [
//                       const CircleAvatar(
//                         radius: 16,
//                         backgroundImage:
//                             NetworkImage('https://via.placeholder.com/150'),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               'User Name',
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Theme.of(context).colorScheme.onSurface,
//                               ),
//                             ),
//                             Text(
//                               'Admin',
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: Theme.of(context)
//                                     .colorScheme
//                                     .onSurface
//                                     .withOpacity(0.7),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Icon(
//                         Icons.logout,
//                         size: 18,
//                         color: Theme.of(context).colorScheme.onSurface,
//                       ),
//                     ],
//                   )
//                 : const CircleAvatar(
//                     radius: 16,
//                     backgroundImage:
//                         NetworkImage('https://via.placeholder.com/150'),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Beautiful navigation item with animation
//   Widget _buildNavItem(
//       IconData icon, String title, int index, bool isExpanded) {
//     final isSelected = _selectedIndex == index;

//     return InkWell(
//       onTap: () {
//         setState(() {
//           _selectedIndex = index;
//         });
//       },
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 200),
//         margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//         decoration: BoxDecoration(
//           color: isSelected
//               ? Theme.of(context).colorScheme.primaryContainer
//               : Colors.transparent,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Row(
//           children: [
//             Icon(
//               icon,
//               color: isSelected
//                   ? Theme.of(context).colorScheme.primary
//                   : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
//               size: 22,
//             ),
//             if (isExpanded) const SizedBox(width: 16),
//             if (isExpanded)
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: isSelected
//                       ? Theme.of(context).colorScheme.primary
//                       : Theme.of(context)
//                           .colorScheme
//                           .onSurface
//                           .withOpacity(0.7),
//                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Page title with animated breadcrumb
//   Widget _buildPageTitle() {
//     final titles = [
//       'Dashboard',
//       'Analytics',
//       'Messages',
//       'Users',
//       'Settings',
//       'Help'
//     ];

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Text(
//               'Home / ',
//               style: TextStyle(
//                 color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
//                 fontSize: 14,
//               ),
//             ),
//             Text(
//               titles[_selectedIndex],
//               style: const TextStyle(
//                 color: Colors.grey,
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           titles[_selectedIndex],
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: Theme.of(context).colorScheme.onSurface,
//           ),
//         ),
//       ],
//     );
//   }

//   // Sample content for the main area
//   Widget _buildContent() {
//     return Expanded(
//       child: Card(
//         elevation: 0,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Welcome to your beautiful scaffold',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Theme.of(context).colorScheme.onSurface,
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 'This is a responsive scaffold template that works beautifully on all devices.',
//                 style: TextStyle(
//                   color:
//                       Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
//                 ),
//               ),
//               const SizedBox(height: 24),
//               Expanded(
//                 child: GridView.builder(
//                   gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                     crossAxisCount: 2,
//                     childAspectRatio: 1.5,
//                     crossAxisSpacing: 16,
//                     mainAxisSpacing: 16,
//                   ),
//                   itemCount: 4,
//                   itemBuilder: (context, index) {
//                     final colors = [
//                       Colors.blue,
//                       Colors.purple,
//                       Colors.green,
//                       Colors.orange,
//                     ];
//                     final icons = [
//                       Icons.bar_chart,
//                       Icons.pie_chart,
//                       Icons.people,
//                       Icons.attach_money,
//                     ];
//                     final titles = [
//                       'Total Views',
//                       'Conversion',
//                       'Users',
//                       'Revenue',
//                     ];
//                     final values = [
//                       '14.5K',
//                       '8.2%',
//                       '1.2K',
//                       '\$24.5K',
//                     ];

//                     return Card(
//                       elevation: 0,
//                       color: colors[index].withOpacity(0.1),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.all(20),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(
//                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                               children: [
//                                 Text(
//                                   titles[index],
//                                   style: TextStyle(
//                                     color: Theme.of(context)
//                                         .colorScheme
//                                         .onSurface
//                                         .withOpacity(0.7),
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                                 Icon(
//                                   icons[index],
//                                   color: colors[index],
//                                   size: 24,
//                                 ),
//                               ],
//                             ),
//                             const Spacer(),
//                             Text(
//                               values[index],
//                               style: TextStyle(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.bold,
//                                 color: Theme.of(context).colorScheme.onSurface,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Row(
//                               children: [
//                                 Icon(
//                                   Icons.arrow_upward,
//                                   color: Colors.green,
//                                   size: 16,
//                                 ),
//                                 const SizedBox(width: 4),
//                                 Text(
//                                   '${index + 5}.2% from last month',
//                                   style: const TextStyle(
//                                     color: Colors.green,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
