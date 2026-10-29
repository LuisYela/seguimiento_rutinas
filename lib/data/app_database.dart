import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = p.join(databaseDirectory, 'seguimiento_rutinas.db');

    return openDatabase(
      databasePath,
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
            CREATE TABLE rutinas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              nombre TEXT NOT NULL,
              descripcion TEXT NOT NULL DEFAULT '',
              fecha_creacion TEXT NOT NULL,
              activa INTEGER NOT NULL DEFAULT 1
                CHECK (activa IN (0, 1))
            )
          ''');

        await db.execute('''
            CREATE TABLE actividades (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              rutina_id INTEGER NOT NULL,
              nombre TEXT NOT NULL,
              descripcion TEXT NOT NULL DEFAULT '',
              activa INTEGER NOT NULL DEFAULT 1
                CHECK (activa IN (0, 1)),
              FOREIGN KEY (rutina_id)
                REFERENCES rutinas(id)
                ON DELETE CASCADE
            )
          ''');

        await db.execute('''
            CREATE TABLE recordatorios (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              actividad_id INTEGER NOT NULL,
              dia_semana INTEGER NOT NULL
                CHECK (dia_semana BETWEEN 1 AND 7),
              hora TEXT NOT NULL,
              activo INTEGER NOT NULL DEFAULT 1
                CHECK (activo IN (0, 1)),
              FOREIGN KEY (actividad_id)
                REFERENCES actividades(id)
                ON DELETE CASCADE,
              UNIQUE (actividad_id, dia_semana, hora)
            )
          ''');

        await db.execute('''
            CREATE TABLE registros_cumplimiento (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              recordatorio_id INTEGER,
              actividad_id INTEGER,
              fecha TEXT NOT NULL,
              estado TEXT NOT NULL
                CHECK (estado IN ('realizado', 'omitido')),
              motivo TEXT NOT NULL DEFAULT '',
              rutina_nombre TEXT NOT NULL,
              actividad_nombre TEXT NOT NULL,
              hora_programada TEXT NOT NULL,
              FOREIGN KEY (recordatorio_id)
                REFERENCES recordatorios(id)
                ON DELETE SET NULL,
              UNIQUE (recordatorio_id, fecha)
            )
          ''');
        await db.execute('''
            CREATE TABLE metricas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              actividad_id INTEGER,
              rutina_nombre TEXT NOT NULL,
              actividad_nombre TEXT NOT NULL,
              nombre TEXT NOT NULL,
              unidad TEXT NOT NULL DEFAULT '',
              valor_minimo REAL,
              valor_maximo REAL,
              activa INTEGER NOT NULL DEFAULT 1
                CHECK (activa IN (0, 1)),
              FOREIGN KEY (actividad_id)
                REFERENCES actividades(id)
                ON DELETE SET NULL,
              CHECK (
                valor_minimo IS NULL OR
                valor_maximo IS NULL OR
                valor_minimo <= valor_maximo
              )
            )
          ''');

        await db.execute('''
            CREATE TABLE registros_metricas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              metrica_id INTEGER NOT NULL,
              fecha TEXT NOT NULL,
              valor REAL NOT NULL,
              descripcion TEXT NOT NULL DEFAULT '',
              fuera_programacion INTEGER
                CHECK (fuera_programacion IN (0, 1)),
              FOREIGN KEY (metrica_id)
                REFERENCES metricas(id)
                ON DELETE RESTRICT,
              UNIQUE (metrica_id, fecha)
            )
          ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE actividades (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              rutina_id INTEGER NOT NULL,
              nombre TEXT NOT NULL,
              descripcion TEXT NOT NULL DEFAULT '',
              activa INTEGER NOT NULL DEFAULT 1
                CHECK (activa IN (0, 1)),
              FOREIGN KEY (rutina_id)
                REFERENCES rutinas(id)
                ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE recordatorios (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              actividad_id INTEGER NOT NULL,
              dia_semana INTEGER NOT NULL
                CHECK (dia_semana BETWEEN 1 AND 7),
              hora TEXT NOT NULL,
              activo INTEGER NOT NULL DEFAULT 1
                CHECK (activo IN (0, 1)),
              FOREIGN KEY (actividad_id)
                REFERENCES actividades(id)
                ON DELETE CASCADE,
              UNIQUE (actividad_id, dia_semana, hora)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE registros_cumplimiento (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              recordatorio_id INTEGER,
              fecha TEXT NOT NULL,
              estado TEXT NOT NULL
                CHECK (estado IN ('realizado', 'omitido')),
              motivo TEXT NOT NULL DEFAULT '',
              rutina_nombre TEXT NOT NULL,
              actividad_nombre TEXT NOT NULL,
              hora_programada TEXT NOT NULL,
              FOREIGN KEY (recordatorio_id)
                REFERENCES recordatorios(id)
                ON DELETE SET NULL,
              UNIQUE (recordatorio_id, fecha)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE metricas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              actividad_id INTEGER,
              rutina_nombre TEXT NOT NULL,
              actividad_nombre TEXT NOT NULL,
              nombre TEXT NOT NULL,
              unidad TEXT NOT NULL DEFAULT '',
              valor_minimo REAL,
              valor_maximo REAL,
              activa INTEGER NOT NULL DEFAULT 1
                CHECK (activa IN (0, 1)),
              FOREIGN KEY (actividad_id)
                REFERENCES actividades(id)
                ON DELETE SET NULL,
              CHECK (
                valor_minimo IS NULL OR
                valor_maximo IS NULL OR
                valor_minimo <= valor_maximo
              )
            )
          ''');

          await db.execute('''
            CREATE TABLE registros_metricas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              metrica_id INTEGER NOT NULL,
              fecha TEXT NOT NULL,
              valor REAL NOT NULL,
              FOREIGN KEY (metrica_id)
                REFERENCES metricas(id)
                ON DELETE RESTRICT,
              UNIQUE (metrica_id, fecha)
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            ALTER TABLE registros_metricas
            ADD COLUMN fuera_programacion INTEGER
              CHECK (fuera_programacion IN (0, 1))
          ''');
        }
        if (oldVersion < 7) {
          await db.execute('''
            ALTER TABLE registros_metricas
            ADD COLUMN descripcion TEXT NOT NULL DEFAULT ''
          ''');
        }
        if (oldVersion < 8) {
          await db.execute('''
            ALTER TABLE registros_cumplimiento
            ADD COLUMN actividad_id INTEGER
          ''');

          // Recuperar la actividad de los registros
          // antiguos cuyo recordatorio aún existe.
          await db.execute('''
            UPDATE registros_cumplimiento
            SET actividad_id = (
              SELECT rec.actividad_id
              FROM recordatorios AS rec
              WHERE rec.id =
                registros_cumplimiento.recordatorio_id
            )
            WHERE recordatorio_id IS NOT NULL
          ''');
        }
      },
    );
  }

  Future<List<Map<String, Object?>>> obtenerRutinas() async {
    final db = await database;

    return db.query('rutinas', orderBy: 'id DESC');
  }

  Future<int> insertarRutina({
    required String nombre,
    required String descripcion,
  }) async {
    final db = await database;

    return db.insert('rutinas', {
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  Future<int> actualizarRutina({
    required int id,
    required String nombre,
    required String descripcion,
  }) async {
    final db = await database;

    return db.update(
      'rutinas',
      {'nombre': nombre, 'descripcion': descripcion},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> eliminarRutina(int id) async {
    final db = await database;

    return db.delete('rutinas', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> obtenerActividades(int rutinaId) async {
    final db = await database;

    return db.query(
      'actividades',
      where: 'rutina_id = ?',
      whereArgs: [rutinaId],
      orderBy: 'id DESC',
    );
  }

  Future<int> insertarActividad({
    required int rutinaId,
    required String nombre,
    required String descripcion,
  }) async {
    final db = await database;

    return db.insert('actividades', {
      'rutina_id': rutinaId,
      'nombre': nombre,
      'descripcion': descripcion,
    });
  }

  Future<int> actualizarActividad({
    required int id,
    required int rutinaId,
    required String nombre,
    required String descripcion,
  }) async {
    final db = await database;

    return db.update(
      'actividades',
      {'nombre': nombre, 'descripcion': descripcion},
      where: 'id = ? AND rutina_id = ?',
      whereArgs: [id, rutinaId],
    );
  }

  Future<int> eliminarActividad({
    required int id,
    required int rutinaId,
  }) async {
    final db = await database;

    return db.delete(
      'actividades',
      where: 'id = ? AND rutina_id = ?',
      whereArgs: [id, rutinaId],
    );
  }

  Future<List<Map<String, Object?>>> obtenerRecordatorios(
    int actividadId,
  ) async {
    final db = await database;

    return db.query(
      'recordatorios',
      where: 'actividad_id = ?',
      whereArgs: [actividadId],
      orderBy: 'dia_semana ASC, hora ASC',
    );
  }

  Future<int> insertarRecordatorio({
    required int actividadId,
    required int diaSemana,
    required String hora,
  }) async {
    final db = await database;

    return db.insert('recordatorios', {
      'actividad_id': actividadId,
      'dia_semana': diaSemana,
      'hora': hora,
    });
  }

  Future<int> actualizarRecordatorio({
    required int id,
    required int actividadId,
    required int diaSemana,
    required String hora,
  }) async {
    final db = await database;

    return db.update(
      'recordatorios',
      {'dia_semana': diaSemana, 'hora': hora},
      where: 'id = ? AND actividad_id = ?',
      whereArgs: [id, actividadId],
    );
  }

  Future<int> eliminarRecordatorio({
    required int id,
    required int actividadId,
  }) async {
    final db = await database;

    return db.delete(
      'recordatorios',
      where: 'id = ? AND actividad_id = ?',
      whereArgs: [id, actividadId],
    );
  }

  Future<List<Map<String, Object?>>> obtenerRecordatoriosProgramables() async {
    final db = await database;
    return db.rawQuery('''
        SELECT
          rec.id,
          rec.actividad_id,
          rec.dia_semana,
          rec.hora,
          act.nombre AS actividad_nombre
        FROM recordatorios AS rec
        INNER JOIN actividades AS act
          ON rec.actividad_id = act.id
        INNER JOIN rutinas AS rut
          ON act.rutina_id = rut.id
        WHERE rec.activo = 1
          AND act.activa = 1
          AND rut.activa = 1
        ORDER BY rec.dia_semana, rec.hora
      ''');
  }

  Future<List<Map<String, Object?>>> obtenerActividadesDelDia(
    DateTime fecha,
  ) async {
    final db = await database;

    final fechaTexto =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
    return db.rawQuery(
      '''
          SELECT
            rec.id AS recordatorio_id,
            rec.dia_semana,
            rec.hora,
            act.nombre AS actividad_nombre,
            rut.nombre AS rutina_nombre,
            reg.estado,
            reg.motivo
          FROM recordatorios AS rec
          INNER JOIN actividades AS act
            ON rec.actividad_id = act.id
          INNER JOIN rutinas AS rut
            ON act.rutina_id = rut.id
          LEFT JOIN registros_cumplimiento AS reg
            ON reg.recordatorio_id = rec.id
            AND reg.fecha = ?
          WHERE rec.dia_semana = ?
            AND rec.activo = 1
            AND act.activa = 1
            AND rut.activa = 1
          ORDER BY rec.hora ASC, act.nombre ASC
        ''',
      [fechaTexto, fecha.weekday],
    );
  }

  Future<void> guardarCumplimiento({
    required int recordatorioId,
    required DateTime fecha,
    required String estado,
    String motivo = '',
  }) async {
    if (estado != 'realizado' && estado != 'omitido') {
      throw ArgumentError('Estado de cumplimiento inválido');
    }

    final db = await database;

    final fechaTexto =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';

    await db.transaction((txn) async {
      final datos = await txn.rawQuery(
        '''
      SELECT
        rec.dia_semana,
        rec.hora,
        act.id AS actividad_id,
        act.nombre AS actividad_nombre,
        rut.nombre AS rutina_nombre
      FROM recordatorios AS rec
      INNER JOIN actividades AS act
        ON rec.actividad_id = act.id
      INNER JOIN rutinas AS rut
        ON act.rutina_id = rut.id
      WHERE rec.id = ?
        AND rec.activo = 1
        AND act.activa = 1
        AND rut.activa = 1
    ''',
        [recordatorioId],
      );

      if (datos.isEmpty) {
        throw StateError('Recordatorio no encontrado');
      }

      final recordatorio = datos.first;

      if (recordatorio['dia_semana'] != fecha.weekday) {
        throw ArgumentError(
          'El recordatorio no corresponde al día seleccionado',
        );
      }

      final valores = <String, Object?>{
        'estado': estado,
        'motivo': estado == 'omitido' ? motivo.trim() : '',
        'rutina_nombre': recordatorio['rutina_nombre'],
        'actividad_nombre': recordatorio['actividad_nombre'],
        'hora_programada': recordatorio['hora'],
        'actividad_id': recordatorio['actividad_id'],
      };

      final existentes = await txn.query(
        'registros_cumplimiento',
        columns: ['id'],
        where: 'recordatorio_id = ? AND fecha = ?',
        whereArgs: [recordatorioId, fechaTexto],
        limit: 1,
      );

      if (existentes.isEmpty) {
        await txn.insert('registros_cumplimiento', {
          'recordatorio_id': recordatorioId,
          'fecha': fechaTexto,
          ...valores,
        });
      } else {
        await txn.update(
          'registros_cumplimiento',
          valores,
          where: 'id = ?',
          whereArgs: [existentes.first['id']],
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> obtenerHistorialCumplimiento() async {
    final db = await database;

    return db.query(
      'registros_cumplimiento',
      orderBy: 'fecha DESC, hora_programada DESC',
    );
  }

  Future<List<Map<String, Object?>>> obtenerHistorialActividad(
    int actividadId,
  ) async {
    final db = await database;

    return db.query(
      'registros_cumplimiento',
      where: 'actividad_id = ?',
      whereArgs: [actividadId],
      orderBy: 'fecha DESC, hora_programada DESC',
    );
  }

  Future<int> insertarMetrica({
    required int actividadId,
    required String nombre,
    String unidad = '',
    double? valorMinimo,
    double? valorMaximo,
  }) async {
    if (nombre.trim().isEmpty) {
      throw ArgumentError('El nombre es obligatorio');
    }

    if (valorMinimo != null && !valorMinimo.isFinite ||
        valorMaximo != null && !valorMaximo.isFinite) {
      throw ArgumentError('Los límites deben ser finitos');
    }

    if (valorMinimo != null &&
        valorMaximo != null &&
        valorMinimo > valorMaximo) {
      throw ArgumentError('El valor mínimo no puede superar al máximo');
    }

    final db = await database;

    return db.transaction((txn) async {
      final datos = await txn.rawQuery(
        '''
      SELECT
        act.nombre AS actividad_nombre,
        rut.nombre AS rutina_nombre
      FROM actividades AS act
      INNER JOIN rutinas AS rut
        ON act.rutina_id = rut.id
      WHERE act.id = ?
        AND act.activa = 1
        AND rut.activa = 1
    ''',
        [actividadId],
      );

      if (datos.isEmpty) {
        throw StateError('Actividad no encontrada');
      }

      return txn.insert('metricas', {
        'actividad_id': actividadId,
        'actividad_nombre': datos.first['actividad_nombre'],
        'rutina_nombre': datos.first['rutina_nombre'],
        'nombre': nombre.trim(),
        'unidad': unidad.trim(),
        'valor_minimo': valorMinimo,
        'valor_maximo': valorMaximo,
      });
    });
  }

  Future<List<Map<String, Object?>>> obtenerMetricas({
    int? actividadId,
    bool soloDesactivadas = false,
  }) async {
    final db = await database;
    final estado = soloDesactivadas ? 0 : 1;

    return db.query(
      'metricas',
      where: actividadId == null
          ? 'activa = ?'
          : 'activa = ? AND actividad_id = ?',
      whereArgs: actividadId == null ? [estado] : [estado, actividadId],
      orderBy: 'rutina_nombre, actividad_nombre, nombre',
    );
  }

  Future<void> guardarValorMetrica({
    required int metricaId,
    required DateTime fecha,
    required double valor,
    String? descripcion,
  }) async {
    if (!valor.isFinite) {
      throw ArgumentError('El valor debe ser un número válido');
    }
    if (descripcion != null && descripcion.trim().length > 250) {
      throw ArgumentError('La descripción no puede superar los 250 caracteres');
    }

    final db = await database;

    final fechaTexto =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';

    await db.transaction((txn) async {
      final metricas = await txn.query(
        'metricas',
        where: 'id = ? AND activa = 1',
        whereArgs: [metricaId],
        limit: 1,
      );

      if (metricas.isEmpty) {
        throw StateError('Métrica no encontrada');
      }

      final metrica = metricas.first;

      final minimo = (metrica['valor_minimo'] as num?)?.toDouble();
      final maximo = (metrica['valor_maximo'] as num?)?.toDouble();

      if (minimo != null && valor < minimo) {
        throw ArgumentError('El valor no puede ser menor que $minimo');
      }

      if (maximo != null && valor > maximo) {
        throw ArgumentError('El valor no puede ser mayor que $maximo');
      }

      final existentes = await txn.query(
        'registros_metricas',
        columns: ['id'],
        where: 'metrica_id = ? AND fecha = ?',
        whereArgs: [metricaId, fechaTexto],
        limit: 1,
      );

      if (existentes.isNotEmpty) {
        // Si corregimos un valor existente,
        // conservamos su clasificación original.
        await txn.update(
          'registros_metricas',
          {
            'valor': valor,
            if (descripcion != null) 'descripcion': descripcion.trim(),
          },
          where: 'id = ?',
          whereArgs: [existentes.first['id']],
        );
        return;
      }

      // Clasificamos solamente los registros nuevos.
      int? fueraProgramacion;

      final actividadId = metrica['actividad_id'] as int?;

      if (actividadId != null) {
        // Comprobar si la actividad tiene
        // algún horario semanal configurado.
        final horarios = await txn.query(
          'recordatorios',
          columns: ['id'],
          where: 'actividad_id = ? AND activo = 1',
          whereArgs: [actividadId],
        );

        if (horarios.isNotEmpty) {
          // Buscar si hay un horario para
          // el día de la fecha seleccionada.
          final horariosDelDia = await txn.query(
            'recordatorios',
            columns: ['id'],
            where: '''
            actividad_id = ?
            AND dia_semana = ?
            AND activo = 1
          ''',
            whereArgs: [actividadId, fecha.weekday],
            limit: 1,
          );

          fueraProgramacion = horariosDelDia.isEmpty ? 1 : 0;
        }
      }

      await txn.insert('registros_metricas', {
        'metrica_id': metricaId,
        'fecha': fechaTexto,
        'valor': valor,
        'descripcion': descripcion?.trim() ?? '',
        'fuera_programacion': fueraProgramacion,
      });
    });
  }

  Future<List<Map<String, Object?>>> obtenerValoresMetrica(
    int metricaId,
  ) async {
    final db = await database;

    return db.query(
      'registros_metricas',
      where: 'metrica_id = ?',
      whereArgs: [metricaId],
      orderBy: 'fecha ASC',
    );
  }

  Future<int> desactivarMetrica(int metricaId) async {
    final db = await database;

    return db.update(
      'metricas',
      {'activa': 0},
      where: 'id = ?',
      whereArgs: [metricaId],
    );
  }

  Future<List<Map<String, Object?>>> obtenerMetricasPorRutina(
    int rutinaId, {
    bool soloDesactivadas = false,
  }) async {
    final db = await database;
    final estado = soloDesactivadas ? 0 : 1;

    return db.rawQuery(
      '''
    SELECT m.*
    FROM metricas AS m
    INNER JOIN actividades AS a
      ON m.actividad_id = a.id
    WHERE a.rutina_id = ?
      AND m.activa = ?
    ORDER BY a.nombre ASC, m.nombre ASC
  ''',
      [rutinaId, estado],
    );
  }

  Future<void> actualizarMetrica({
    required int id,
    required String nombre,
    required String unidad,
    double? valorMinimo,
    double? valorMaximo,
  }) async {
    if (nombre.trim().isEmpty) {
      throw ArgumentError('El nombre es obligatorio');
    }

    if ((valorMinimo != null && !valorMinimo.isFinite) ||
        (valorMaximo != null && !valorMaximo.isFinite)) {
      throw ArgumentError('Los límites deben ser números válidos');
    }

    if (valorMinimo != null &&
        valorMaximo != null &&
        valorMinimo > valorMaximo) {
      throw ArgumentError('El mínimo no puede ser mayor que el máximo');
    }

    final db = await database;

    await db.transaction((txn) async {
      final metricas = await txn.query(
        'metricas',
        columns: ['id'],
        where: 'id = ? AND activa = 1',
        whereArgs: [id],
        limit: 1,
      );

      if (metricas.isEmpty) {
        throw StateError('Métrica no encontrada');
      }

      // Revisar los valores registrados anteriormente.
      final resumen = await txn.rawQuery(
        '''
      SELECT
        MIN(valor) AS menor,
        MAX(valor) AS mayor
      FROM registros_metricas
      WHERE metrica_id = ?
    ''',
        [id],
      );

      final menor = (resumen.first['menor'] as num?)?.toDouble();
      final mayor = (resumen.first['mayor'] as num?)?.toDouble();

      if (valorMinimo != null && menor != null && menor < valorMinimo) {
        throw ArgumentError(
          'No se puede establecer ese mínimo. '
          'Ya existe un valor registrado de $menor.',
        );
      }

      if (valorMaximo != null && mayor != null && mayor > valorMaximo) {
        throw ArgumentError(
          'No se puede establecer ese máximo. '
          'Ya existe un valor registrado de $mayor.',
        );
      }

      // Solo actualizamos la definición.
      // Los registros históricos permanecen intactos.
      await txn.update(
        'metricas',
        {
          'nombre': nombre.trim(),
          'unidad': unidad.trim(),
          'valor_minimo': valorMinimo,
          'valor_maximo': valorMaximo,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> cambiarEstadoRutina({
    required int id,
    required bool activa,
  }) async {
    final db = await database;

    return db.update(
      'rutinas',
      {'activa': activa ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> cambiarEstadoActividad({
    required int id,
    required int rutinaId,
    required bool activa,
  }) async {
    final db = await database;

    return db.update(
      'actividades',
      {'activa': activa ? 1 : 0},
      where: 'id = ? AND rutina_id = ?',
      whereArgs: [id, rutinaId],
    );
  }

  Future<int> reactivarMetrica(int metricaId) async {
    final db = await database;

    return db.update(
      'metricas',
      {'activa': 1},
      where: 'id = ? AND activa = 0',
      whereArgs: [metricaId],
    );
  }

  Future<Map<String, Object?>?> obtenerDetalleRecordatorio(
    int recordatorioId,
  ) async {
    final db = await database;

    final datos = await db.rawQuery(
      '''
    SELECT
      rec.id AS recordatorio_id,
      rec.dia_semana,
      rec.hora,
      rec.activo AS recordatorio_activo,
      act.id AS actividad_id,
      act.nombre AS actividad_nombre,
      act.activa AS actividad_activa,
      rut.id AS rutina_id,
      rut.nombre AS rutina_nombre,
      rut.activa AS rutina_activa
    FROM recordatorios AS rec
    INNER JOIN actividades AS act
      ON rec.actividad_id = act.id
    INNER JOIN rutinas AS rut
      ON act.rutina_id = rut.id
    WHERE rec.id = ?
    LIMIT 1
  ''',
      [recordatorioId],
    );

    return datos.isEmpty ? null : datos.first;
  }

  Future<Map<String, Object?>?> obtenerCumplimientoRecordatorio({
    required int recordatorioId,
    required DateTime fecha,
  }) async {
    final db = await database;

    final fechaTexto =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';

    final datos = await db.query(
      'registros_cumplimiento',
      where: 'recordatorio_id = ? AND fecha = ?',
      whereArgs: [recordatorioId, fechaTexto],
      limit: 1,
    );

    return datos.isEmpty ? null : datos.first;
  }

  Future<void> registrarNotificacionDescartada(int recordatorioId) async {
    final db = await database;
    final ahora = DateTime.now();

    final fecha =
        '${ahora.year.toString().padLeft(4, '0')}-'
        '${ahora.month.toString().padLeft(2, '0')}-'
        '${ahora.day.toString().padLeft(2, '0')}';

    await db.transaction((txn) async {
      final datos = await txn.rawQuery(
        '''
      SELECT
        act.id AS actividad_id,
        rec.dia_semana,
        rec.hora,
        act.nombre AS actividad_nombre,
        rut.nombre AS rutina_nombre
      FROM recordatorios AS rec
      INNER JOIN actividades AS act
        ON rec.actividad_id = act.id
      INNER JOIN rutinas AS rut
        ON act.rutina_id = rut.id
      WHERE rec.id = ?
        AND rec.activo = 1
        AND act.activa = 1
        AND rut.activa = 1
      LIMIT 1
    ''',
        [recordatorioId],
      );

      if (datos.isEmpty) return;

      final recordatorio = datos.first;
      final dia = recordatorio['dia_semana'] as int;
      final hora = recordatorio['hora'] as String;

      // Por seguridad, solamente registramos
      // descartes correspondientes al día actual.
      if (ahora.weekday != dia) return;

      final partesHora = hora.split(':');

      final programada = DateTime(
        ahora.year,
        ahora.month,
        ahora.day,
        int.parse(partesHora[0]),
        int.parse(partesHora[1]),
      );

      if (ahora.isBefore(programada)) return;

      // Evitar reemplazar un cumplimiento existente.
      final existentes = await txn.query(
        'registros_cumplimiento',
        columns: ['id'],
        where: 'recordatorio_id = ? AND fecha = ?',
        whereArgs: [recordatorioId, fecha],
        limit: 1,
      );

      if (existentes.isNotEmpty) return;

      await txn.insert('registros_cumplimiento', {
        'actividad_id': recordatorio['actividad_id'],
        'recordatorio_id': recordatorioId,
        'fecha': fecha,
        'estado': 'omitido',
        'motivo': 'descartada',
        'rutina_nombre': recordatorio['rutina_nombre'],
        'actividad_nombre': recordatorio['actividad_nombre'],
        'hora_programada': hora,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }
}
