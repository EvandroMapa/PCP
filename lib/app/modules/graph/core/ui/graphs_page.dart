// import 'package:flutter/material.dart';

// class GraphsPage extends StatefulWidget {
//   const GraphsPage({super.key});

//   @override
//   State<GraphsPage> createState() => _GraphsPageState();
// }

// class _GraphsPageState extends State<GraphsPage> {
//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//         resizeAvoid: true,
//         drawer: const AppDrawer(),
//         appBar: AppBar(
//           title: Text('Gráficos',
//               style: AppCss.largeBold.setColor(AppColors.white)),
//           backgroundColor: AppColors.primaryMain,
//         ),
//         body: body());
//   }

//   Widget body() {
//     return ListView(
//       children: [
//         ListTile(
//           leading: const Icon(Icons.pie_chart),
//           title: const Text('Musicos por tipo de instrumento'),
//           trailing: Icon(
//             Icons.arrow_forward_ios,
//             size: 16,
//             color: AppColors.neutralLight,
//           ),
//           onTap: () => push(context, const GraphMusicosTipoPage()),
//         ),
//         ListTile(
//           leading: const Icon(Icons.pie_chart),
//           title: const Text('Presença de músicos por tipo de ensaio'),
//           trailing: Icon(
//             Icons.arrow_forward_ios,
//             size: 16,
//             color: AppColors.neutralLight,
//           ),
//           onTap: () => push(context, const GraphMusicosEnsaioPage()),
//         ),
//       ],
//     );
//   }
// }
