import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'auth_api.dart';
import 'login_page.dart';

void main() {
  // Inteligência de troca de URL:
  // kReleaseMode é true quando o app é compilado para produção (flutter build)
  // kDebugMode é true durante o desenvolvimento (flutter run)
  
  // IPs de conexão:
  const String urlInterna = 'http://192.168.1.217';
  const String urlExterna = 'https://sys.rohden.com.br';
  
  // A estratégia inteligente: 
  // Se estiver em modo release (APK final), usa a URL externa por padrão.
  // Se estiver em debug, tenta facilitar a vida do desenvolvedor.
  String baseUrl = urlExterna;
  
  if (kDebugMode) {
    if (kIsWeb) {
      baseUrl = 'http://localhost';
    } else {
      // No Android físico/emulador em debug, o IP interno costuma ser melhor
      baseUrl = urlInterna;
    }
  }
  
  // DICA: Em uma versão futura, podemos salvar a preferência de IP no SharedPreferences
  // para que o usuário não precise mudar toda vez.
  
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
