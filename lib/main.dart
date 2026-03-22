import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:telephony/telephony.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SiriusSafeApp());
}

class SiriusSafeApp extends StatelessWidget {
  const SiriusSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SiriusSafe',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.redAccent,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- TELA DE ABERTURA (SPLASH) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const MainNavigator())
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shieldCheck, size: 80, color: Colors.blueAccent),
            SizedBox(height: 20),
            Text("SIRIUS SAFE", 
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 5)),
            Text("SEGURANÇA TOTAL", style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// --- NAVEGADOR ---
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [const HomePage(), const SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF16213E),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.zap), label: 'SOS'),
          NavigationDestination(icon: Icon(LucideIcons.users), label: 'Contatos'),
        ],
      ),
    );
  }
}

// --- PÁGINA SOS ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isSending = false;
  final Telephony telephony = Telephony.instance;

  Future<Position?> _getUniversalLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 7),
      );
    } catch (e) {
      return await Geolocator.getLastKnownPosition();
    }
  }

  Future<void> _dispararSOS({bool viaWhatsApp = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('contacts_list');
    List<dynamic> contacts = contactsJson != null ? jsonDecode(contactsJson) : [];

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Adicione um contato primeiro!")));
      return;
    }

    setState(() => _isSending = true);

    Position? pos = await _getUniversalLocation();
    String mapLink = pos != null 
        ? "https://www.google.com/maps?q=${pos.latitude},${pos.longitude}"
        : "[Localização não disponível]";

    String mensagem = "🚨 SOS SIRIUS SAFE!\nPreciso de ajuda urgente. Minha localização: $mapLink";

    try {
      if (viaWhatsApp) {
        String phone = contacts[0]['phone'];
        
        // --- CORREÇÃO DE DDD E NÚMERO ---
        // Remove tudo que não for número
        String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
        
        // Se o número tiver 10 ou 11 dígitos (DDD + Número), adiciona o 55 (Brasil)
        if (cleanPhone.length >= 10 && !cleanPhone.startsWith('55')) {
          cleanPhone = "55$cleanPhone";
        }

        final url = "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensagem)}";
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      } else {
        bool? canSend = await telephony.requestPhoneAndSmsPermissions;
        if (canSend == true) {
          for (var c in contacts) {
            await telephony.sendSms(to: c['phone'], message: mensagem);
          }
          if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const AlertSentPage()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SIRIUS SAFE"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("SISTEMA DE EMERGÊNCIA ATIVO", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 60),
            GestureDetector(
              onTap: _isSending ? null : () => _dispararSOS(),
              child: Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withOpacity(0.1),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Center(
                  child: _isSending 
                      ? const CircularProgressIndicator() 
                      : const Text("SOS", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () => _dispararSOS(viaWhatsApp: true),
              icon: const Icon(LucideIcons.messageCircle),
              label: const Text("SOS VIA WHATSAPP"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            )
          ],
        ),
      ),
    );
  }
}

// --- TELA DE CONTATOS ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<dynamic> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _contacts = jsonDecode(prefs.getString('contacts_list') ?? "[]"));
  }

  _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contacts_list', jsonEncode(_contacts));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CONTATOS")),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final n = TextEditingController();
          final p = TextEditingController();
          showDialog(context: context, builder: (c) => AlertDialog(
            title: const Text("Adicionar"),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, decoration: const InputDecoration(hintText: "Nome")),
              TextField(controller: p, decoration: const InputDecoration(hintText: "DDD + Número"), keyboardType: TextInputType.phone),
            ]),
            actions: [ElevatedButton(onPressed: () {
              if (n.text.isNotEmpty && p.text.isNotEmpty) {
                setState(() => _contacts.add({"name": n.text, "phone": p.text}));
                _save();
                Navigator.pop(context);
              }
            }, child: const Text("Salvar"))],
          ));
        },
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (c, i) => ListTile(
          title: Text(_contacts[i]['name']),
          subtitle: Text(_contacts[i]['phone']),
          trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () {
            setState(() => _contacts.removeAt(i));
            _save();
          }),
        ),
      ),
    );
  }
}

// --- TELA SUCESSO ---
class AlertSentPage extends StatelessWidget {
  const AlertSentPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const Text("ALERTA ENVIADO!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("VOLTAR")),
          ],
        ),
      ),
    );
  }
}