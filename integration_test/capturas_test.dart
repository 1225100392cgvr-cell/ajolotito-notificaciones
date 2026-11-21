import 'package:ajolotito/dominio/almacen.dart';
import 'package:ajolotito/dominio/gestor_permiso.dart';
import 'package:ajolotito/dominio/reloj.dart';
import 'package:ajolotito/dominio/servicio.dart';
import 'package:ajolotito/main.dart' as app;
import 'package:ajolotito/presentacion/ajolote_vm.dart';
import 'package:ajolotito/presentacion/dibujo_ajolote.dart';
import 'package:ajolotito/presentacion/pantalla_ajolote.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/falsos.dart';

/// Recorre Ajolotito en el emulador y toma una captura de cada estado.
/// Se corre con: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/capturas_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var convertida = false;

  Future<void> foto(WidgetTester tester, String nombre) async {
    if (!convertida) {
      await binding.convertFlutterSurfaceToImage();
      convertida = true;
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await binding.takeScreenshot(nombre);
  }

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('la app real: pantalla, panza llena, explicación del permiso y ajustes', (tester) async {
    convertida = false; // cada prueba vuelve a convertir la superficie (el binding la revierte al terminar)
    app.main();
    for (var i = 0; i < 40 && find.text('Dar de comer').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await foto(tester, '01_ajolote_en_la_app');

    await tocar(tester, find.text('Dar de comer'));
    await foto(tester, '02_dar_de_comer');

    final avisar = find.textContaining('Avísame cuando tenga hambre');
    if (avisar.evaluate().isNotEmpty) {
      await tocar(tester, avisar);
      await foto(tester, '03_explicacion_antes_del_permiso');
      await tocar(tester, find.text('Ahora no'));
    }

    await tocar(tester, find.byIcon(Icons.tune));
    await foto(tester, '04_ajustes_de_avisos');
  });

  testWidgets('estados del ajolote con reloj simulado y avisos programados', (tester) async {
    convertida = false;
    final puerto = PuertoFalso()..activas = true;
    final reloj = RelojFalso(DateTime(2026, 11, 12, 10));
    final almacen = AlmacenMemoria();
    final vm = AjoloteViewModel(
      servicio: ServicioAjolote(puerto: puerto, almacen: almacen, reloj: reloj),
      gestor: GestorPermiso(puerto: puerto, almacen: almacen),
      reloj: reloj,
    );
    await vm.iniciar(conReloj: false);
    await vm.alCambiarCicloDeVida(AppLifecycleState.paused);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFFE56B8F), useMaterial3: true),
      home: PantallaAjolote(vm: vm),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(find.textContaining('Próximos programados'));
    await foto(tester, '05_avisos_programados');

    reloj.avanzar(const Duration(hours: 6, minutes: 30));
    await vm.alTocarNotificacion('v1:alimentar');
    await tester.ensureVisible(find.byType(DibujoAjolote));
    await foto(tester, '06_tiene_hambre_toque_en_aviso');

    reloj.avanzar(const Duration(hours: 3));
    await vm.alTocarNotificacion(null);
    await foto(tester, '07_famelico');

    await vm.alimentar();
    await foto(tester, '08_despues_de_comer');
  });
}
