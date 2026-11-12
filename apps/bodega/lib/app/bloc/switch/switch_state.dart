part of 'switch_bloc.dart';

/// What a toast tells on any page: a code that `switchNoticeText` words
/// (switch-support design §6).
@freezed
sealed class SwitchNotice with _$SwitchNotice {
  /// An add found [added] new games, and [known] already in the list.
  const factory SwitchNotice.added(int added, int known) = SwitchAddedNotice;

  /// The run of [title] ended with [code], which its kind of game does not
  /// end with normally.
  const factory SwitchNotice.exited(String title, int code) =
      SwitchExitedNotice;

  /// [count] keys files were copied where [emulator] reads them.
  const factory SwitchNotice.keysAdded(String emulator, int count) =
      SwitchKeysAddedNotice;

  /// [emulator] opened its own firmware installer: the user confirms there.
  const factory SwitchNotice.firmwareOpened(String emulator) =
      SwitchFirmwareOpenedNotice;
}

@freezed
abstract class SwitchState with _$SwitchState {
  const factory SwitchState({
    /// True until the first load ends.
    @Default(true) bool isLoading,

    /// While an add looks for games.
    @Default(false) bool isAdding,

    /// The emulator, its keys and its firmware, and how games open: null
    /// until a read gives them. A read that fails keeps the last one.
    SwitchStatus? status,
    @Default([]) List<SwitchGame> games,

    /// The games that run: each one's path, and the log of its run.
    @Default({}) Map<String, String> running,

    /// The latest notice; [noticeId] tells apart two equal ones.
    SwitchNotice? notice,
    @Default(0) int noticeId,
    AppError? error,
  }) = _SwitchState;
}
