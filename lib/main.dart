import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'login_page.dart';

void main() {
  // Inteligência de troca de URL:
  // kReleaseMode é true quando o app é compilado para produção (flutter build)
  // kDebugMode é true durante o desenvolvimento (flutter run)
  
  String baseUrl;
  
  if (kReleaseMode) {
    // URL de Produção (Rede)
    baseUrl = 'http://192.168.1.217';
  } else {
    // URL de Desenvolvimento (Local)
    // Forçando 127.0.0.1 e porta 80 para garantir compatibilidade
    baseUrl = 'http://127.0.0.1:80';
    
    // Dica para emulador Android se necessário:
    // baseUrl = 'http://10.0.2.2:80';
  }
  
  final authApi = AuthApi(baseUrl: baseUrl);

  runApp(MyApp(authApi: authApi));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authApi});

  final AuthApi authApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sys_Medicao',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: LoginPage(authApi: authApi),
    );
  }
}
