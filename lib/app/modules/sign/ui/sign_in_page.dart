// import 'package:flutter/material.dart';
// import 'package:aco_plus/app/core/components/app_drop_down.dart';
// import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
// import 'package:aco_plus/app/core/components/app_field.dart';
// import 'package:aco_plus/app/core/components/app_scaffold.dart';
// import 'package:aco_plus/app/core/components/done_button.dart';
// import 'package:aco_plus/app/core/components/h.dart';
// import 'package:aco_plus/app/core/components/stream_out.dart';
// import 'package:aco_plus/app/core/utils/app_colors.dart';
// import 'package:aco_plus/app/core/utils/app_css.dart';
// import 'package:aco_plus/app/core/utils/global_resource.dart';
// import 'package:aco_plus/app/modules/sign/sign_controller.dart';
// import 'package:aco_plus/app/modules/sign/sign_view_model.dart';

// class SignInPage extends StatefulWidget {
//   const SignInPage({super.key});

//   @override
//   State<SignInPage> createState() => _SignInPageState();
// }

// class _SignInPageState extends State<SignInPage> {
//   @override
//   void initState() {
//     signCtrl.formStream.add(SignInCreateModel());
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AppScaffold(
//         resizeAvoid: true,
//         appBar: AppBar(
//           leading: IconButton(
//               onPressed: () => pop(context),
//               icon: Icon(
//                 Icons.arrow_back,
//                 color: AppColors.white,
//               )),
//           title: Text('Cadastre-se',
//               style: AppCss.largeBold.setColor(AppColors.white)),
//           actions: [
//             IconLoadingButton(() async => await signCtrl.onConfirm(context))
//           ],
//           backgroundColor: AppColors.primaryMain,
//         ),
//         body: StreamOut(
//             stream: signCtrl.formStream.listen,
//             child: (_, form) => body(form)));
//   }

//   Widget body(SignInCreateModel form) {
//     return ListView(
//       padding: const EdgeInsets.all(16),
//       children: [
//         AppDropDown<UsuarioRole?>(
//           label: 'Tipo',
//           item: form.role,
//           itens: const [
//             UsuarioRole.gestor,
//             UsuarioRole.analistaTransporte,
//             UsuarioRole.analistaColetas,
//             UsuarioRole.transportadora,
//             UsuarioRole.comprador,
//           ],
//           itemLabel: (e) => e!.label,
//           onSelect: (e) {
//             form.role = e;
//             signCtrl.formStream.update();
//           },
//         ),
//         const H(16),
//         AppField(
//           label: form.isTransportadora ? 'Razão Social' : 'Nome Completo',
//           controller: form.nome,
//           onChanged: (_) => signCtrl.formStream.update(),
//         ),
//         const H(16),
//         if (form.isTransportadora)
//           AppField(
//             label: 'CNPJ',
//             controller: form.cnpj,
//             onChanged: (_) => signCtrl.formStream.update(),
//           ),
//         if (form.isTransportadora) const H(16),
//         AppField(
//           label: 'E-mail',
//           controller: form.email,
//           onChanged: (_) => signCtrl.formStream.update(),
//         ),
//         const H(16),
//         AppField(
//           label: 'Telefone',
//           controller: form.telefone,
//           onChanged: (_) => signCtrl.formStream.update(),
//         ),
//         const H(16),
//         if (!form.isTransportadora)
//           AppField(
//             label: 'Cargo/Função',
//             controller: form.funcao,
//             onChanged: (_) => signCtrl.formStream.update(),
//           ),
//         if (!form.isTransportadora) const H(16),
//         AppDropDownList<CountryState>(
//           label: 'Estados',
//           itens: CountryState.values,
//           addeds: form.estados,
//           itemLabel: (e) => e.label,
//           onChanged: () {
//             signCtrl.formStream.update();
//           },
//         ),
//         const H(16),
//         AppField(
//           label: 'Senha',
//           controller: form.senha,
//           onChanged: (_) => signCtrl.formStream.update(),
//         ),
//         const H(24),
//       ],
//     );
//   }
// }
