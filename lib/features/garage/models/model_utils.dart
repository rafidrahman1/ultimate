DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
