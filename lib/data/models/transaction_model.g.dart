// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      purchaseDate: fields[1] as DateTime,
      saleDate: fields[2] as DateTime?,
      quantity: fields[3] as double,
      fmvPerShare: fields[4] as double,
      purchasePricePerShare: fields[5] as double,
      salePricePerShare: fields[6] as double?,
      incomeTaxRate: fields[7] as double,
      capitalGainsTaxRate: fields[8] as double,
      exchangeRateAtPurchase: fields[9] as double?,
      exchangeRateAtSale: fields[10] as double?,
      type: fields[11] as TransactionType,
      createdAt: fields[12] as DateTime,
      updatedAt: fields[13] as DateTime?,
      lookbackFmv: fields[14] as double?,
      offeringPeriod: fields[15] as String?,
      qualifiedDispositionDate: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.purchaseDate)
      ..writeByte(2)
      ..write(obj.saleDate)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.fmvPerShare)
      ..writeByte(5)
      ..write(obj.purchasePricePerShare)
      ..writeByte(6)
      ..write(obj.salePricePerShare)
      ..writeByte(7)
      ..write(obj.incomeTaxRate)
      ..writeByte(8)
      ..write(obj.capitalGainsTaxRate)
      ..writeByte(9)
      ..write(obj.exchangeRateAtPurchase)
      ..writeByte(10)
      ..write(obj.exchangeRateAtSale)
      ..writeByte(11)
      ..write(obj.type)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.lookbackFmv)
      ..writeByte(15)
      ..write(obj.offeringPeriod)
      ..writeByte(16)
      ..write(obj.qualifiedDispositionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TransactionTypeAdapter extends TypeAdapter<TransactionType> {
  @override
  final int typeId = 1;

  @override
  TransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionType.purchase;
      case 1:
        return TransactionType.sale;
      default:
        return TransactionType.purchase;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionType obj) {
    switch (obj) {
      case TransactionType.purchase:
        writer.writeByte(0);
        break;
      case TransactionType.sale:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
