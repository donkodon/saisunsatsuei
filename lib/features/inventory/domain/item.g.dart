// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 0;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      id: fields[0] as String,
      name: fields[1] as String,
      brand: fields[2] as String,
      imageUrl: fields[3] as String,
      category: fields[4] as String,
      status: fields[5] as String,
      date: fields[6] as DateTime,
      length: fields[7] as double?,
      width: fields[8] as double?,
      size: fields[9] as String?,
      hasAlert: fields[10] as bool,
      barcode: fields[11] as String?,
      sku: fields[12] as String?,
      color: fields[13] as String?,
      productRank: fields[14] as String?,
      salePrice: fields[15] as int?,
      condition: fields[16] as String?,
      description: fields[17] as String?,
      material: fields[18] as String?,
      imageUrls: (fields[19] as List?)?.cast<String>(),
      imagesJson: (fields[20] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          // ignore: invalid_null_aware_operator
          ?.toList(),
      companyId: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.brand)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.length)
      ..writeByte(8)
      ..write(obj.width)
      ..writeByte(9)
      ..write(obj.size)
      ..writeByte(10)
      ..write(obj.hasAlert)
      ..writeByte(11)
      ..write(obj.barcode)
      ..writeByte(12)
      ..write(obj.sku)
      ..writeByte(13)
      ..write(obj.color)
      ..writeByte(14)
      ..write(obj.productRank)
      ..writeByte(15)
      ..write(obj.salePrice)
      ..writeByte(16)
      ..write(obj.condition)
      ..writeByte(17)
      ..write(obj.description)
      ..writeByte(18)
      ..write(obj.material)
      ..writeByte(19)
      ..write(obj.imageUrls)
      ..writeByte(20)
      ..write(obj.imagesJson)
      ..writeByte(21)
      ..write(obj.companyId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
