import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/sign/sign_controller.dart';
import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final TextController email = TextController();
  final TextController senha = TextController();

  @override
  Widget build(BuildContext context) {
    return body();
  }

  Widget body() {
    return AppScaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const H(20),
              Image.asset('assets/images/logo.png', width: 100),
              const H(20),
              Text('AÇO+', style: AppCss.largeBold.setSize(16)),
              const H(20),
              AppField(
                controller: email,
                label: 'E-mail',
                type: TextInputType.emailAddress,
              ),
              const H(20),
              AppField(
                controller: senha,
                label: 'Senha',
                obscure: true,
                maxLines: 1,
                minLines: 1,
              ),
              const H(20),
              AppTextButton(
                label: 'Entrar',
                onPressed: () => signCtrl.onClickLogin(email.text, senha.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
