// // GENERATED CODE - DO NOT MODIFY BY HAND

// part of 'pending_print.dart';

// // **************************************************************************
// // TypeAdapterGenerator
// // **************************************************************************

// class PendingPrintInvoiceAdapter extends TypeAdapter<PendingPrintInvoice> {
//   @override
//   final int typeId = 11;

//   @override
//   PendingPrintInvoice read(BinaryReader reader) {
//     final numOfFields = reader.readByte();
//     final fields = <int, dynamic>{
//       for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
//     };
//     return PendingPrintInvoice(
//       invoiceNo: fields[0] as String,
//       timestamp: fields[1] as DateTime,
//       printData: (fields[2] as Map).cast<String, dynamic>(),
//     );
//   }

//   @override
//   void write(BinaryWriter writer, PendingPrintInvoice obj) {
//     writer
//       ..writeByte(3)
//       ..writeByte(0)
//       ..write(obj.invoiceNo)
//       ..writeByte(1)
//       ..write(obj.timestamp)
//       ..writeByte(2)
//       ..write(obj.printData);
//   }

//   @override
//   int get hashCode => typeId.hashCode;

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is PendingPrintInvoiceAdapter &&
//           runtimeType == other.runtimeType &&
//           typeId == other.typeId;
// }
