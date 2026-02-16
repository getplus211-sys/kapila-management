// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 0;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      messageId: fields[0] as String,
      chatId: fields[1] as String,
      senderId: fields[2] as String,
      messageType: fields[3] as String,
      content: fields[4] as String?,
      mediaUrl: fields[5] as String?,
      replyToMessageId: fields[6] as String?,
      isForwarded: fields[7] as bool,
      forwardedFromUserId: fields[8] as String?,
      isEdited: fields[9] as bool,
      editedAt: fields[10] as DateTime?,
      isDeleted: fields[11] as bool,
      deletedAt: fields[12] as DateTime?,
      createdAt: fields[13] as DateTime,
      isDisappearing: fields[14] as bool,
      disappearAfterSeconds: fields[15] as int?,
      isDelivered: fields[16] as bool,
      isReadByAll: fields[17] as bool,
      expiresAt: fields[18] as DateTime?,
      isDeletedForMe: fields[19] as bool,
      reactions: (fields[20] as List?)?.cast<String>(),
      isPinned: fields[21] as bool,
      scheduledFor: fields[22] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.messageId)
      ..writeByte(1)
      ..write(obj.chatId)
      ..writeByte(2)
      ..write(obj.senderId)
      ..writeByte(3)
      ..write(obj.messageType)
      ..writeByte(4)
      ..write(obj.content)
      ..writeByte(5)
      ..write(obj.mediaUrl)
      ..writeByte(6)
      ..write(obj.replyToMessageId)
      ..writeByte(7)
      ..write(obj.isForwarded)
      ..writeByte(8)
      ..write(obj.forwardedFromUserId)
      ..writeByte(9)
      ..write(obj.isEdited)
      ..writeByte(10)
      ..write(obj.editedAt)
      ..writeByte(11)
      ..write(obj.isDeleted)
      ..writeByte(12)
      ..write(obj.deletedAt)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.isDisappearing)
      ..writeByte(15)
      ..write(obj.disappearAfterSeconds)
      ..writeByte(16)
      ..write(obj.isDelivered)
      ..writeByte(17)
      ..write(obj.isReadByAll)
      ..writeByte(18)
      ..write(obj.expiresAt)
      ..writeByte(19)
      ..write(obj.isDeletedForMe)
      ..writeByte(20)
      ..write(obj.reactions)
      ..writeByte(21)
      ..write(obj.isPinned)
      ..writeByte(22)
      ..write(obj.scheduledFor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
