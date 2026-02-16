// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatModelAdapter extends TypeAdapter<ChatModel> {
  @override
  final int typeId = 2;

  @override
  ChatModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatModel(
      chatId: fields[0] as String,
      chatType: fields[1] as String,
      user1Id: fields[2] as String?,
      user2Id: fields[3] as String?,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      lastMessageAt: fields[6] as DateTime?,
      autoDeleteDays: fields[7] as int?,
      lastMessageBy: fields[8] as String?,
      unreadCount: fields[9] as int,
      isMuted: fields[10] as bool,
      isArchived: fields[11] as bool,
      isPinned: fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ChatModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.chatId)
      ..writeByte(1)
      ..write(obj.chatType)
      ..writeByte(2)
      ..write(obj.user1Id)
      ..writeByte(3)
      ..write(obj.user2Id)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.lastMessageAt)
      ..writeByte(7)
      ..write(obj.autoDeleteDays)
      ..writeByte(8)
      ..write(obj.lastMessageBy)
      ..writeByte(9)
      ..write(obj.unreadCount)
      ..writeByte(10)
      ..write(obj.isMuted)
      ..writeByte(11)
      ..write(obj.isArchived)
      ..writeByte(12)
      ..write(obj.isPinned);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
