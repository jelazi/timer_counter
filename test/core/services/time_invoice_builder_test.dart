import 'package:flutter_test/flutter_test.dart';
import 'package:timer_counter/core/services/time_invoice_builder.dart';

void main() {
  const artemis = ProjectBillingLine(projectId: 'p2', projectName: '2. Artemis', hours: 52.5, hourlyRate: 550, description: 'Vývoj aplikace Artemis');
  const ostatni = ProjectBillingLine(projectId: 'p1', projectName: '1. Ostatní', hours: 6.2, hourlyRate: 550);

  test('per project: one line per project, its description or else its name', () {
    final lines = TimeInvoiceBuilder.build([artemis, ostatni], InvoiceLineMode.perProject);

    expect(lines.map((l) => l.description), ['Vývoj aplikace Artemis', '1. Ostatní']);
    expect(lines.map((l) => l.quantity), [52.5, 6.2]);
    expect(lines.every((l) => l.unit == 'hod' && l.unitPrice == 550), isTrue);
  });

  test('single line with one shared rate is total hours × rate and equals the per-project sum', () {
    final single = TimeInvoiceBuilder.build([artemis, ostatni], InvoiceLineMode.single);
    final perProject = TimeInvoiceBuilder.build([artemis, ostatni], InvoiceLineMode.perProject);

    expect(single, hasLength(1));
    expect(single.first.description, 'Vývoj aplikace Artemis, 1. Ostatní');
    expect(single.first.quantity, 58.7);
    expect(single.first.unitPrice, 550);
    expect(single.first.total, closeTo(perProject.fold<double>(0, (s, l) => s + l.total), 0.001));
  });

  test('single line with different rates keeps the exact amount and names the hours', () {
    const cheaper = ProjectBillingLine(projectId: 'p3', projectName: 'Podpora', hours: 2.5, hourlyRate: 400);

    final lines = TimeInvoiceBuilder.build([artemis, cheaper], InvoiceLineMode.single);

    expect(lines, hasLength(1));
    expect(lines.first.quantity, 1);
    expect(lines.first.unit, 'ks');
    expect(lines.first.unitPrice, 52.5 * 550 + 2.5 * 400);
    expect(lines.first.description, 'Vývoj aplikace Artemis, Podpora (55,0 hod)');
  });

  test('projects without hours are left out, and nothing billed gives no lines', () {
    const idle = ProjectBillingLine(projectId: 'p4', projectName: 'testovací projekt', hours: 0, hourlyRate: 550);

    expect(TimeInvoiceBuilder.build([artemis, idle], InvoiceLineMode.perProject).map((l) => l.description), ['Vývoj aplikace Artemis']);
    expect(TimeInvoiceBuilder.build([idle], InvoiceLineMode.single), isEmpty);
  });

  test('the same description is not repeated in a single line', () {
    const second = ProjectBillingLine(projectId: 'p5', projectName: 'Artemis 2', hours: 1, hourlyRate: 550, description: 'Vývoj aplikace Artemis');

    expect(TimeInvoiceBuilder.build([artemis, second], InvoiceLineMode.single).first.description, 'Vývoj aplikace Artemis');
  });
}
