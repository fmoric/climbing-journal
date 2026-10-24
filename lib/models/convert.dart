import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads an enum by its stored name; unknown or missing names fall back,
/// so older app versions keep working when a new value is added.
T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.asNameMap()[name] ?? fallback;

DateTime? dateFrom(Object? value) =>
    value is Timestamp ? value.toDate() : null;

Timestamp? timestampFrom(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);
