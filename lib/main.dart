import 'package:flutter/material.dart';

import 'pages/rutinas_page.dart';
import 'services/notification_service.dart';
import 'pages/historial_page.dart';
import 'pages/metricas_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La interfaz se muestra incluso si falla alguna operación de notificaciones.
  try {
    await NotificationService.instance.inicializar();
    await NotificationService.instance.sincronizarRecordatorios();
  } catch (e) {
    debugPrint('No se pudieron iniciar las notificaciones: $e');
  }

  runApp(const SeguimientoRutinasApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.instance.abrirNotificacionInicial().catchError((e) {
      debugPrint('No se pudo abrir la notificación inicial: $e');
    });
  });
}

class SeguimientoRutinasApp extends StatelessWidget {
  const SeguimientoRutinasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seguimiento de Rutinas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF52796F)),
        scaffoldBackgroundColor: const Color(0xFFF7F8F6),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFFF7F8F6),
        ),
      ),
      home: const AppShell(),
      navigatorKey: NotificationService.instance.navigatorKey,
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  int actualizacionHistorial = 0;

  void navigateTo(int index) {
    setState(() {
      selectedIndex = index;

      if (index == 3) {
        actualizacionHistorial++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onNavigate: navigateTo),
      const RutinasPage(),
      const MetricasPage(),
      HistorialPage(actualizacion: actualizacionHistorial),
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: navigateTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Rutinas',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            selectedIcon: Icon(Icons.show_chart),
            label: 'Métricas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'SEGUIMIENTO PERSONAL',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: Color(0xFF52796F),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Organiza tu día.',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Administra tus rutinas y lleva un registro de tu progreso.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 28),

            // Tarjeta principal
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.track_changes,
                    size: 34,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu rutina, a tu manera',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define las actividades que deseas realizar, '
                    'registra su cumplimiento y observa tus métricas.',
                    style: TextStyle(
                      height: 1.5,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => onNavigate(1),
                    icon: const Icon(Icons.add),
                    label: const Text('Explorar mis rutinas'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text(
              'Tu seguimiento',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    icon: Icons.event_available,
                    title: 'Rutinas',
                    subtitle: 'Por configurar',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    icon: Icons.check_circle_outline,
                    title: 'Actividades',
                    subtitle: 'Por registrar',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            Text(
              'Accesos rápidos',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            QuickAction(
              icon: Icons.calendar_month_outlined,
              title: 'Mis rutinas',
              description: 'Organiza tus actividades y horarios.',
              onTap: () => onNavigate(1),
            ),
            QuickAction(
              icon: Icons.show_chart,
              title: 'Mis métricas',
              description: 'Registra valores personalizados.',
              onTap: () => onNavigate(2),
            ),
            QuickAction(
              icon: Icons.history,
              title: 'Historial',
              description: 'Consulta tus registros anteriores.',
              onTap: () => onNavigate(3),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 28),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colors.secondaryContainer,
          child: Icon(icon, color: colors.onSecondaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.primary),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
