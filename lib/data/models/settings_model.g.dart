// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 2;

  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingsModel(
      biometricEnabled: fields[0] as bool,
      autoLockMinutes: fields[1] as int,
      defaultIncomeTaxRate: fields[2] as double,
      defaultCapitalGainsTaxRate: fields[3] as double,
      defaultStockSymbol: fields[4] as String,
      displayCurrency: fields[5] as String,
      showLivePrices: fields[6] as bool,
      lastBackup: fields[7] as DateTime?,
      defaultEsppDiscountRate: fields[8] as double,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.biometricEnabled)
      ..writeByte(1)
      ..write(obj.autoLockMinutes)
      ..writeByte(2)
      ..write(obj.defaultIncomeTaxRate)
      ..writeByte(3)
      ..write(obj.defaultCapitalGainsTaxRate)
      ..writeByte(4)
      ..write(obj.defaultStockSymbol)
      ..writeByte(5)
      ..write(obj.displayCurrency)
      ..writeByte(6)
      ..write(obj.showLivePrices)
      ..writeByte(7)
      ..write(obj.lastBackup)
      ..writeByte(8)
      ..write(obj.defaultEsppDiscountRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
