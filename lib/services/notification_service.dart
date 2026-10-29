import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_database.dart';

import 'package:flutter/material.dart';

import '../pages/notificacion_actividad_page.dart';

import 'dart:ui' show DartPluginRegistrant;
import 'dart:io' show Platform;

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inicializado = false;

  static const String _categoriaIos = 'acciones_cumplimiento_v1';
  static const String _accionAbrirActividad = 'abrir_actividad';
  static const String _accionOmitida = 'cumplimiento_omitido';

  static const NotificationDetails _detalles = NotificationDetails(
    iOS: DarwinNotificationDetails(
      categoryIdentifier: _categoriaIos,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    android: AndroidNotificationDetails(
      'recordatorios_rutinas',
      'Recordatorios de rutinas',
      channelDescription: 'Notificaciones para las actividades programadas',
      importance: Importance.max,
      priority: Priority.high,
      dismissIsolate: NotificationDismissedIsolate.background,
    ),
  );

  Future<void> inicializar() async {
    if (_inicializado) return;

    // Configurar la zona horaria del dispositivo.
    tz.initializeTimeZones();

    final zona = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zona.identifier));

    // Inicialización multiplataforma sin pedir permisos al arrancar.
    final configuracion = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: <DarwinNotificationCategory>[
          DarwinNotificationCategory(
            _categoriaIos,
            actions: <DarwinNotificationAction>[
              DarwinNotificationAction.plain(
                _accionAbrirActividad,
                'Abrir actividad',
                options: <DarwinNotificationActionOption>{
                  DarwinNotificationActionOption.foreground,
                },
              ),
              DarwinNotificationAction.plain(_accionOmitida, 'Omitir'),
            ],
          ),
        ],
      ),
    );

    await _plugin.initialize(
      settings: configuracion,
      onDidReceiveNotificationResponse: (respuesta) async {
        if (respuesta.notificationResponseType ==
            NotificationResponseType.notificationDismissed) {
          return;
        }
        // Abrir la pantalla de actividad para confirmar el cumplimiento
        // y permitir registrar métricas. No marcar automáticamente.
        if (respuesta.actionId == _accionAbrirActividad) {
          _abrirDesdePayload(respuesta.payload);
          return;
        }
        if (respuesta.actionId == _accionOmitida) {
          await procesarAccionCumplimiento(respuesta);
          return;
        }
        _abrirDesdePayload(respuesta.payload);
      },
      onDidReceiveBackgroundNotificationResponse:
          procesarNotificacionEnSegundoPlano,
    );

    _inicializado = true;
  }

  Future<bool> solicitarPermisoNotificaciones() async {
    await inicializar();

    if (Platform.isIOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.requestNotificationsPermission() ?? false;
  }

  Future<void> mostrarPrueba() async {
    await inicializar();

    await _plugin.show(
      id: 1000001,
      title: 'Prueba de notificación',
      body: 'Las notificaciones de seguimiento de rutinas funcionan.',
      notificationDetails: _detalles,
    );
  }

  Future<bool> programarPrueba() async {
    await inicializar();

    if (Platform.isIOS) {
      final permisos = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      if (permisos?.isEnabled != true) return false;
    } else {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      // Solo Android necesita autorización de alarmas exactas.
      final autorizado = await android?.requestExactAlarmsPermission() ?? false;
      if (!autorizado) return false;
    }

    final fechaProgramada = tz.TZDateTime.now(tz.local)
        .add(const Duration(minutes: 1));

    await _plugin.zonedSchedule(
      id: 1000002,
      title: 'Recordatorio programado',
      body: 'Esta notificación se programó hace un minuto.',
      scheduledDate: fechaProgramada,
      notificationDetails: _detalles,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    return true;
  }

  // Reservamos IDs distintos de los usados
  // por las notificaciones de prueba.
  static const int _baseIdRecordatorios = 10000000;

  int _idNotificacion(int recordatorioId) {
    return _baseIdRecordatorios + recordatorioId;
  }

  // Comprueba los permisos sin mostrar ventanas.
  Future<bool> permisosProgramacionActivos() async {
    await inicializar();

    if (Platform.isIOS) {
      final permisos = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return permisos?.isEnabled ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final notificaciones = await android?.areNotificationsEnabled() ?? false;

    final alarmasExactas =
        await android?.canScheduleExactNotifications() ?? false;

    return notificaciones && alarmasExactas;
  }

  // Se llama al guardar un horario.
  Future<bool> solicitarPermisosProgramacion() async {
    final notificaciones = await solicitarPermisoNotificaciones();

    if (!notificaciones) return false;

    if (Platform.isIOS) return true;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.requestExactAlarmsPermission() ?? false;
  }

  // Calcula la siguiente fecha correspondiente
  // al día y la hora seleccionados.
  tz.TZDateTime _siguienteFechaSemanal({
    required int diaSemana,
    required String hora,
  }) {
    if (diaSemana < 1 || diaSemana > 7) {
      throw ArgumentError('Día de semana inválido');
    }

    final partes = hora.split(':');

    if (partes.length != 2) {
      throw FormatException('Hora inválida: $hora');
    }

    final horas = int.parse(partes[0]);
    final minutos = int.parse(partes[1]);

    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) {
      throw FormatException('Hora fuera de rango');
    }

    final ahora = tz.TZDateTime.now(tz.local);

    var fecha = tz.TZDateTime(
      tz.local,
      ahora.year,
      ahora.month,
      ahora.day,
      horas,
      minutos,
    );

    // Si el horario ya pasó hoy, avanzamos
    // hasta el siguiente día correspondiente.
    while (fecha.weekday != diaSemana || !fecha.isAfter(ahora)) {
      fecha = tz.TZDateTime(
        tz.local,
        fecha.year,
        fecha.month,
        fecha.day + 1,
        horas,
        minutos,
      );
    }

    return fecha;
  }

  // Programa una notificación semanal.
  Future<void> programarRecordatorioSemanal({
    required int recordatorioId,
    required int actividadId,
    required String actividadNombre,
    required int diaSemana,
    required String hora,
  }) async {
    await inicializar();

    final fecha = _siguienteFechaSemanal(diaSemana: diaSemana, hora: hora);

    final id = _idNotificacion(recordatorioId);

    // Evita conservar la programación anterior
    // cuando se edita el día o la hora.
    await _plugin.cancel(id: id);

    await _plugin.zonedSchedule(
      id: id,
      title: 'Recordatorio de actividad',
      body: 'Es momento de: $actividadNombre',
      scheduledDate: fecha,
      notificationDetails: _detalles,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'recordatorio:$recordatorioId:actividad:$actividadId',
    );
  }

  // Cancela una notificación individual.
  Future<void> cancelarRecordatorio(int recordatorioId) async {
    await inicializar();

    await _plugin.cancel(id: _idNotificacion(recordatorioId));
  }

  // Hace coincidir la programación local
  // con los recordatorios guardados en SQLite.
  Future<void> sincronizarRecordatorios() async {
    await inicializar();

    final recordatorios = await AppDatabase.instance
        .obtenerRecordatoriosProgramables();

    final idsVigentes = recordatorios
        .map((r) => _idNotificacion(r['id'] as int))
        .toSet();

    final pendientes = await _plugin.pendingNotificationRequests();

    // Cancela recordatorios que ya no existen
    // o que dejaron de estar activos.
    for (final pendiente in pendientes) {
      final esRecordatorio =
          pendiente.payload?.startsWith('recordatorio:') ?? false;

      if (esRecordatorio && !idsVigentes.contains(pendiente.id)) {
        await _plugin.cancel(id: pendiente.id);
      }
    }

    // No intentamos programar alarmas exactas
    // mientras falten permisos.
    if (!await permisosProgramacionActivos()) {
      return;
    }

    // Registra o actualiza cada horario vigente.
    for (final r in recordatorios) {
      await programarRecordatorioSemanal(
        recordatorioId: r['id'] as int,
        actividadId: r['actividad_id'] as int,
        actividadNombre: r['actividad_nombre'] as String,
        diaSemana: r['dia_semana'] as int,
        hora: r['hora'] as String,
      );
    }
  }

  void _abrirDesdePayload(String? payload) {
    if (payload == null) return;

    // Ejemplo:
    // recordatorio:15:actividad:4
    final patron = RegExp(r'^recordatorio:(\d+):actividad:(\d+)$');

    final coincidencia = patron.firstMatch(payload);

    if (coincidencia == null) {
      return;
    }

    final recordatorioId = int.parse(coincidencia.group(1)!);

    void abrirPantalla() {
      final navegador = navigatorKey.currentState;

      if (navegador == null) return;

      navegador.push(
        MaterialPageRoute(
          builder: (_) =>
              NotificacionActividadPage(recordatorioId: recordatorioId),
        ),
      );
    }

    // Si Flutter todavía está construyendo la
    // interfaz, esperamos al primer fotograma.
    if (navigatorKey.currentState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => abrirPantalla());
    } else {
      abrirPantalla();
    }
  }

  Future<void> abrirNotificacionInicial() async {
    await inicializar();

    final detalles = await _plugin.getNotificationAppLaunchDetails();

    if (detalles?.didNotificationLaunchApp != true) {
      return;
    }

    _abrirDesdePayload(detalles?.notificationResponse?.payload);
  }
}

@pragma('vm:entry-point')
Future<void> procesarNotificacionEnSegundoPlano(
  NotificationResponse respuesta,
) async {
  final esDescarteAndroid =
      respuesta.notificationResponseType ==
      NotificationResponseType.notificationDismissed;
  final esAccionIosOmitir =
      respuesta.actionId == NotificationService._accionOmitida;
  if (!esDescarteAndroid && !esAccionIosOmitir) return;

  final payload = respuesta.payload ?? '';

  final coincidencia = RegExp(r'^recordatorio:(\d+):actividad:(\d+)$')
      .firstMatch(payload);

  if (coincidencia == null) return;

  final recordatorioId = int.parse(coincidencia.group(1)!);

  try {
    DartPluginRegistrant.ensureInitialized();

    await AppDatabase.instance.registrarNotificacionDescartada(recordatorioId);
  } catch (e) {
    debugPrint('Error al registrar acción de notificación: $e');
  }
}

// Permite procesar las acciones también si la app está abierta.
Future<void> procesarAccionCumplimiento(NotificationResponse respuesta) async {
  final match = RegExp(r'^recordatorio:(\d+):actividad:(\d+)$')
      .firstMatch(respuesta.payload ?? '');
  if (match == null) return;
  final id = int.parse(match.group(1)!);
  try {
    if (respuesta.actionId == NotificationService._accionOmitida) {
      await AppDatabase.instance.registrarNotificacionDescartada(id);
    }
  } catch (e) {
    debugPrint('Error al registrar cumplimiento desde aviso: $e');
  }
}
