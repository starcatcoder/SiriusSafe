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

// --- TELA DE ENTRADA (SPLASH SCREEN) ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _opacity = 1.0);
    });

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const MainNavigator(),
            transitionsBuilder: (context, anim, secAnim, child) => 
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(seconds: 1),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(seconds: 2),
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10)
                  ],
                  border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(LucideIcons.shieldCheck,
                    size: 90, color: Colors.blueAccent),
              ),
              const SizedBox(height: 30),
              const Text(
                "SIRIUS SAFE",
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 10,
                    color: Colors.white),
              ),
              const SizedBox(height: 10),
              Container(height: 2, width: 50, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                "PROTEÇÃO INTELIGENTE",
                style: TextStyle(
                    color: Colors.white38, letterSpacing: 3, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NAVEGADOR PRINCIPAL ---
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
        indicatorColor: Colors.redAccent.withOpacity(0.2),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.zap), label: 'Emergência'),
          NavigationDestination(icon: Icon(LucideIcons.users), label: 'Contatos'),
        ],
      ),
    );
  }
}

// --- PÁGINA DO BOTÃO SOS ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  bool _isSending = false;
  late AnimationController _controller;
  final Telephony telephony = Telephony.instance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dispararSOS() async {
    final prefs = await SharedPreferences.getInstance();
    final String? contactsJson = prefs.getString('contacts_list');

    if (contactsJson == null || jsonDecode(contactsJson).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Adicione contatos primeiro!")));
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() => _isSending = true);

    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String mapUrl = "https://www.google.com/maps?q=${pos.latitude},${pos.longitude}";

      List<dynamic> contacts = jsonDecode(contactsJson);
      for (var contact in contacts) {
        await telephony.sendSms(
          to: contact['phone'],
          message: "🚨 SOS SIRIUS SAFE!\nPreciso de ajuda urgente. Minha localização: $mapUrl",
        );
      }

      if (mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const AlertSentPage()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao enviar alertas de segurança.")));
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)])),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text("SIRIUS SAFE",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            centerTitle: true),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("EM CASO DE PERIGO, TOQUE ABAIXO",
                  style: TextStyle(color: Colors.white38, letterSpacing: 1.2)),
              const SizedBox(height: 50),
              GestureDetector(
                onTap: _isSending ? null : _dispararSOS,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.redAccent.withOpacity(0.2 * _controller.value),
                              blurRadius: 40,
                              spreadRadius: 25 * _controller.value)
                        ],
                        gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
                      ),
                      child: Center(
                        child: _isSending
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SOS",
                                style: TextStyle(
                                    fontSize: 55,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 60),
              const Icon(LucideIcons.radio, color: Colors.redAccent, size: 20),
              const SizedBox(height: 8),
              const Text("MONITORAMENTO ATIVO",
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- PÁGINA DE CONTATOS ---
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<Map<String, String>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('contacts_list');
    if (data != null) {
      setState(() => _contacts = List<Map<String, String>>.from(
          jsonDecode(data).map((item) => Map<String, String>.from(item))));
    }
  }

  void _addContact() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Novo Contato"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Nome")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefone"), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                setState(() => _contacts.add({'name': nameCtrl.text, 'phone': phoneCtrl.text}));
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('contacts_list', jsonEncode(_contacts));
                Navigator.pop(context);
              }
            },
            child: const Text("Salvar")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)])),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, title: const Text("CONTATOS")),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _addContact,
            backgroundColor: Colors.blueAccent,
            icon: const Icon(Icons.person_add),
            label: const Text("ADICIONAR")),
        body: _contacts.isEmpty
            ? const Center(child: Text("Sua rede de apoio está vazia.", style: TextStyle(color: Colors.white38)))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _contacts.length,
                itemBuilder: (context, index) => Card(
                  color: Colors.white.withOpacity(0.05),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(_contacts[index]['name']!),
                    subtitle: Text(_contacts[index]['phone']!),
                    trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          setState(() => _contacts.removeAt(index));
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('contacts_list', jsonEncode(_contacts));
                        }),
                  ),
                ),
              ),
      ),
    );
  }
}

// --- PÁGINA DE ALERTA ENVIADO ---
class AlertSentPage extends StatelessWidget {
  const AlertSentPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.greenAccent, size: 100),
            const SizedBox(height: 30),
            const Text("SISTEMA ACIONADO!",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse("tel:190")),
              icon: const Icon(Icons.phone),
              label: const Text("LIGAR 190"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
            const SizedBox(height: 20),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLTAR")),
          ],
        ),
      ),
    );
  }
}