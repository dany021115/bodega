/// Why a name cannot be the Windows user of a bottle (U3, U4): the engine's
/// `UserNameProblem`, which `data/` maps here.
enum UserNameProblem {
  empty,

  /// Longer than 20 characters.
  tooLong,

  /// It holds one of `" / \ [ ] : ; | = , + * ? < >`, or a control character.
  badCharacter,

  /// Only dots or spaces.
  onlyDots,

  /// The bottle already has a profile folder by that name.
  taken,
}
